# DNSBlock Test Script

Este script é uma adaptação do trabalho original de Kris Lowet: https://gist.github.com/KrisLowet/675ba34e682c6d2afbc53fc317b41e85

A estrutura principal foi mantida, porém foram realizadas modificações para a experimentação acadêmica reprodutível

As principais modificações implementadas em relação à versão original foram:

* Atualização dos resolvedores avaliados, incluindo somente os resolvedores: Cloudflare (1.1.1.2), CleanBrowsing, AdGuard e Quad9.

* Ampliação do conjunto de IPs de bloqueio (sinkhole), com inclusão dos IPs do AdGuard (94.140.14.33, 94.140.14.35 e 94.140.14.15) para evitar que redirecionamentos de bloqueio fossem interpretados como resolução válida.

* Limitação controlada da amostra, restringindo a coleta a até 1.000 domínios por fonte (CERT.pl e URLHaus), reduzindo custo computacional e permitindo posterior balanceamento.

* Processamento independente das fontes antes da unificação, garantindo maior consistência na limpeza dos dados.
 
* Remoção de duplicatas com preservação da ordem original, utilizando awk '!seen[$1]++', assegurando reprodutibilidade.

* Identificação da origem dos domínios testados, adicionando rótulo de fonte (CERT.pl ou URLHaus) em cada entrada.

* Saída estruturada em CSV com delimitador ;, compatível com planilhas no padrão regional brasileiro.
