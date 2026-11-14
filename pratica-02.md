O que significa a máscara octal 600 em termos de permissões de leitura, escrita e execução para o dono, grupo e outros?

Dono (User), Grupo (Group) e Outros (Others). 

Cada dígito é a soma dos valores binários das permissões: Leitura (4), Escrita (2) e Execução (1)

Primeiro dígito (6 = 4 + 2) — Dono: Possui permissão de Leitura e Escrita (rw-), mas não de execução.

Segundo dígito (0) — Grupo: Possui nenhuma permissão (---).

Terceiro dígito (0) — Outros: Possui nenhuma permissão (---).

Por que o arquivo backend/.env exige estritamente essa restrição (600) em um servidor real?

Pois possui dados muito sensíveis como senhas, chaves secretas e chaves de serviços externos.Se fosse permitido a leitura por outros usuários, qualquer processo poderia ler o arquivo e extrair as senhas do banco de dados.

Por que conceder permissão chmod 777 em diretórios de aplicação web é considerado uma falha crítica de segurança pela comunidade de infraestrutura?

Pois concede leitura, escrita e execução sem limiter para qualquer pessoa ou processo, podendo expor dados, corrompendo, alterando ou até deletando arquivos vitais da apliação.

Descreva resumidamente os passos e atalhos de teclado que você utilizou dentro do editor de terminal para editar, salvar e sair do arquivo.

nano backend/.env para abrir o editor no terminal
alterei a porta para 8080, navegando via setas do teclado
adicionei a linha MAX_REQUEST_LIMIT=100 com ctrl shift v
Salvei as alterações com ctrl o, enter para confirmar e ctrl x para sair do modo de edição
validei as alterações do arquivo com cat backend/.env



Registro no pratica-02.md: Anote a linha de comando completa que você desenvolveu para responder a cada item acima e explique detalhadamente a função de cada bloco da sua linha (ex: o que o grep filtrou, o que o awk extraiu, como o sort e uniq -c agruparam os dados).

Identificação de Ataque de Força Bruta: Qual endereço IP realizou o maior número de tentativas de login com erro (código HTTP 401) no endpoint /api/v1/login, e quantas tentativas foram registradas?

grep "/api/v1/login" logs/access.log | grep " 401 " | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 1

grep "api/v1/login" filta apenas ao endpoint de login
grep "401" pega só as responstas com erro 401
awk '{print $1} pega a primeira coluna do log, que é o endereço de IP
sort ordena os IPs
uniq  -c conta quantas vezes cada ip aparece
sort -nr ordena numericamente em ordem crescente
head -n 1 pega o top 1

Identificação de Falhas Críticas: Quantas requisições no total receberam código HTTP 500 (Internal Server Error) no arquivo de log?

grep -c " 500 " logs/access.log

Varre o arquivo de log procurando ocorrências exatas do padrão de status HTTP 500 cercado por espaços e retorna diretamente o número total de linhas correspondentes.

Geração de Relatório: Exporte a lista consolidada e ordenada de IPs suspeitos que geraram erros (4xx ou 5xx) para o arquivo logs/relatorio-incidentes.txt.

vboxuser@Ubuntu-Pos:~/app-producao$ awk '$9 ~ /^[45]/ $1}' logs/access.log
awk: line 1: extra '}'
vboxuser@Ubuntu-Pos:~/app-producao$ awk '$9 ~ /^[45]/ {print  $1}' logs/access.log
192.168.1.20
192.168.1.30
192.168.1.50
192.168.1.60
vboxuser@Ubuntu-Pos:~/app-producao$ awk '$9 ~ /^[45]/ {print  $1}' logs/access.log | sort -u > logs/relatorio-incidentes.txt
vboxuser@Ubuntu-Pos:~/app-producao$ cat logs/relatorio-incidentes.txt
192.168.1.20
192.168.1.30
192.168.1.50
192.168.1.60

awk '$9 ~ /^[45]/ {print $1}' logs/access.log 
analisa o campo 9 e verifica qualquer codigo que comece com 4 ou 5, quando a condicao for verdadeira, imprime a coluna $1 que é o IP

sort -u - ordena os IPs e -u remove duplicatas

> logs/relatorio-incidentes.txt - relatorio
cat logs/relatorio-incidentes.txt visualizar o relatorio

Como você utilizaria o comando sed com a flag -i para alterar diretamente a linha PORT=8080 para PORT=3000 no arquivo backend/.env sem precisar abrir um editor interativo?

sed -i 's/PORT=8080/PORT=3000/g' backend/.env

sed: Acrônimo para Stream Editor, padrão para filtrar e transformar texto.

-i (In-place): Informa ao sed para salvar as alterações diretamente no arquivo original (backend/.env)

's/PORT=8080/PORT=3000/g': A expressão de substituição (s de substitute):

Procura pelo padrão PORT=8080.
Substitui por PORT=3000.

A flag g (global) garante que, caso o padrão apareça mais de uma vez na mesma linha, todas as instâncias sejam alteradas.

Por que o uso de sed em pipelines de automação (CI/CD) é preferível à edição manual em editores visuais?

Enquanto ferramentas como nano ou vim foram feitas para humanos editarem textos olhando para uma tela, o ambiente de automação (CI/CD) roda sozinho em servidores remotos.

Funciona sem intervenção humana: O CI/CD roda em segundo plano (sem tela ou interface gráfica). Tentar abrir um editor visual quebraria o processo porque não há ninguém lá para digitar. O sed é executado direto por código em uma linha.
Com o sed, você pode injetar variáveis que mudam a cada deploy (como uma porta de rede ou token gerados na hora). Fazer isso manualmente exigiria reescrever o arquivo a cada entrega.


No Linux Ubuntu, por que a permissão chmod 777 em diretórios de upload de um servidor web representa uma vulnerabilidade crítica de execução remota de código? Qual é a configuração correta de usuário, grupo e permissões octais para mitigar esse risco em aplicações web?

Pois concede leitura, escrita e execuçao irrestritas

O diretório e seu conteúdo devem pertencer exclusivamente ao usuário e grupo do servidor web:
sudo chown -R www-data:www-data /caminho/para/uploads

Diretórios (755): Permite que o dono (www-data) leia, escreva e acesse (rwx), enquanto o grupo e outros podem apenas listar e ler (r-x).

sudo find /caminho/para/uploads -type d -exec chmod 755 {} \;

Arquivos (644): Permite leitura e escrita apenas para o dono, e apenas leitura para os demais. Nenhum arquivo enviado pode ter permissão de execução (x).

sudo find /caminho/para/uploads -type f -exec chmod 644 {} \;

Critério de sucesso: Os diretórios devem exibir drwxr-xr-x (755) e os arquivos -rw-r--r-- (644), sem a letra x nas permissões de grupo ou outros.


