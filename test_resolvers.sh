#!/bin/bash

#
# Check if required commands are installed.
#
required_commands=( "parallel" "dig" "wget" "sort" "ping" "awk" )

for cmd in "${required_commands[@]}"; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: Required command '$cmd' is not found or not executable." >&2
    exit 1
  fi
done


hosts_list="dnsblock_hosts_$(date '+%Y%m%d').txt"
result="dnsblock_result_$(date '+%Y%m%d').csv"

echo "### Downloading hosts lists."
wget --quiet -O "list_url.txt" "https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-hosts.txt"
wget --quiet -O "list_cert.txt" "https://hole.cert.pl/domains/v2/domains.txt"

#
# Clean up and select 500 FIRST from each, adding the source label.
#
echo "### Cleaning and selecting 1000 first from CERT then URLHaus."

sed -i '/^[[:blank:]]*#/d; s/#.*//; s/^0.0.0.0 //; s/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d' list_cert.txt
head -n 1000 list_cert.txt | awk '{print $0 ";CERT.pl"}' > dnsblock_test_list_concat.txt

sed -i '/^[[:blank:]]*#/d; s/#.*//; s/^0.0.0.0 //; s/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d' list_url.txt
head -n 1000 list_url.txt | awk '{print $0 ";URLHaus"}' >> dnsblock_test_list_concat.txt

awk -F';' '!seen[$1]++' dnsblock_test_list_concat.txt > "$hosts_list"

totalhosts=$(wc -l < "$hosts_list")
echo "### Hosts to test: $totalhosts"

#
# Define IP address of the nameservers.
#
ns_sp_array=(
  "Cloudflare (Unfiltered)"
  "Cloudflare (Security Only)"
  "Cleanbrowsing"
  "AdGuard"
  "Quad9 (Malware/Ad Blocking)"
)

ns_ip_array=(
  "1.1.1.1"
  "1.1.1.2"
  "185.228.168.168"
  "94.140.14.15"
  "9.9.9.9"
)

header="Domain name;Source"
for i in "${!ns_sp_array[@]}"; do
  header="$header;${ns_sp_array[$i]} - ${ns_ip_array[$i]}"
done
echo "$header" > "$result"

echo "### Checking average ping to nameservers."
ping_results="PING (ms);-"
for ns_ip in "${ns_ip_array[@]}"; do
  avg_ping=$(ping -c 5 -W 1 -q "$ns_ip" | grep '^rtt' | cut -d ' ' -f 4 | cut -d '/' -f 2)
  ping_results="$ping_results;${avg_ping:--}"
done
echo "$ping_results" >> "$result"

#
# Define a function that does the lookup and filter blackholes.
#
dig_and_filter() {
  local ns_ip=$1
  local domain_to_test=$2
  ip=$(dig @"$ns_ip" +noadflag +noedns +short "$domain_to_test" | grep '^[.0-9]*$' | tail -n1)
  
  if [[ "$ip" == "127.0.0.1" || "$ip" == "0.0.0.0" || "$ip" == "94.140.14.33" || "$ip" == "94.140.14.35" || "$ip" == "94.140.14.15" ]]; then
    echo ""
  else
    echo "$ip"
  fi
}
export -f dig_and_filter

echo "### Testing safe hosts."
safe_hosts=( nexxwave.be nasa.gov google.com cloudflare.com microsoft.com )
for domain in "${safe_hosts[@]}"; do
  echo "Testing $domain (safe domain)..."
  results_line="$domain (safe domain);-"
  for ns_ip in "${ns_ip_array[@]}"; do
    ip=$(dig_and_filter "$ns_ip" "$domain")
    results_line="$results_line;$ip"
  done
  echo "$results_line" >> "$result"
done

#
# Start the parallel test.
#
echo -e "\n### Start parallel test at $(date)"
echo -e "\n" >> "$result"
echo "$header" >> "$result"


while IFS=';' read -r domain source
do
  if [ -z "$domain" ]; then continue; fi
  echo -n "Testing $domain ($source) ..."
  ip0=$(dig_and_filter "${ns_ip_array[0]}" "$domain")

  if [[ -n "$ip0" ]]; then
    echo " OK"
    safe_domain=$(printf %q "$domain")
    # Restaurado para 8 jobs conforme a original
    testing_ips=$(printf "%s\n" "${ns_ip_array[@]:1}" | grep . | parallel -j 8 --keep-order "dig_and_filter {} $safe_domain")
    testing_ips_csv=$(echo "$testing_ips" | paste -sd ';' -)
    
    echo "$domain;$source;$ip0;$testing_ips_csv" >> "$result"
  else
    echo " Skipping"
  fi
done < "$hosts_list"

echo "### End test at $(date)"
echo "### Result file created at: $result"
