# Prática 02 — Permissões, edição de configurações e auditoria de logs

Ambiente: Ubuntu (VirtualBox), projeto em `~/app-producao`.

---

## Atividade 1 — Hardening de permissões e análise crítica (Requisito 04)

### Comandos executados

```bash
cd ~/app-producao
chmod 755 config logs backend frontend
chmod 644 backend/api/server.js config/env.template
chmod 600 backend/.env
ls -ld backend
ls -l backend/.env
```

```text
vboxuser@Ubuntu-Pos:~/app-producao$ ls -ld backend
drwxr-xr-x 3 vboxuser vboxuser 4096 Nov 14 15:34 backend

vboxuser@Ubuntu-Pos:~/app-producao$ ls -l backend/.env
-rw------- 1 vboxuser vboxuser 160 Nov 14 15:34 backend/.env
```

A pasta `backend` ficou `drwxr-xr-x` (755) e o `.env` ficou `-rw-------` (600), como esperado.

### Análise crítica

**1. O que significa a máscara octal 600 em termos de leitura, escrita e execução para dono, grupo e outros?**

As três posições da máscara representam, nesta ordem: Dono (User), Grupo (Group) e Outros (Others). Cada dígito é a soma dos valores das permissões: Leitura (r) = 4, Escrita (w) = 2 e Execução (x) = 1.

| Dígito | Quem | Cálculo | Permissões |
|---|---|---|---|
| 6 | Dono | 4 + 2 | `rw-` (lê e escreve, não executa) |
| 0 | Grupo | 0 | `---` (nenhuma permissão) |
| 0 | Outros | 0 | `---` (nenhuma permissão) |

Em resumo, `600` equivale a `-rw-------`: só o dono acessa o arquivo.

**2. Por que o `backend/.env` exige estritamente essa restrição (600) em um servidor real?**

Porque o `.env` guarda dados muito sensíveis: senhas de banco de dados, chaves secretas e credenciais de serviços externos. Se outros usuários do sistema tivessem permissão de leitura, qualquer usuário ou processo comprometido na máquina poderia ler o arquivo e extrair essas credenciais. Com `600`, apenas o dono (o usuário que executa a aplicação) consegue lê-lo.

**3. Por que `chmod 777` em diretórios de aplicação web é considerado uma falha crítica de segurança?**

Porque concede leitura, escrita e execução sem limite a qualquer usuário ou processo do sistema. Com isso, é possível expor dados, alterar ou corromper arquivos e até apagar arquivos vitais da aplicação. Em um servidor web, o risco é maior ainda: se um invasor ou um serviço comprometido conseguir gravar nesse diretório, ele pode inserir código malicioso que depois pode ser executado (detalhado na Atividade 5).

---

## Atividade 2 — Edição de configurações no terminal (Requisito 05)

### Passos e atalhos utilizados no editor `nano`

1. Abri o arquivo com `nano backend/.env`.
2. Naveguei com as **setas do teclado** até a linha da porta e alterei para `PORT=8080`.
3. Adicionei a linha `MAX_REQUEST_LIMIT=100` (colada com **Ctrl+Shift+V**, o atalho de colar no terminal).
4. Salvei com **Ctrl+O**, confirmei o nome do arquivo com **Enter** e saí do nano com **Ctrl+X**.
5. Validei a alteração com:

```bash
cat backend/.env
```

```text
vboxuser@Ubuntu-Pos:~/app-producao$ cat backend/.env
PORT=8080
NODE_ENV=production
DATABASE_URL=postgres://usuario:senha@localhost:5432/appdb
LOG_LEVEL=info
CORS_ORIGIN=http://localhost:5173
MAX_REQUEST_LIMIT=100
```

O arquivo mostra `PORT=8080` e a nova linha `MAX_REQUEST_LIMIT=100`, confirmando a edição.

---

## Atividade 3 — Mineração forense de logs (Requisito 06)

O arquivo `logs/access.log` registra os acessos ao servidor web. Em cada linha, o primeiro campo (`$1`) é o endereço IP do cliente, o campo `$8` é o código de status HTTP e o `$9` é o tamanho da resposta em bytes. Exemplo de linha:

```text
192.168.1.15 - - [10/Out/2026:14:00:05] "POST /api/v1/login HTTP/1.1" 401 64
```

### 3.1 Identificação de ataque de força bruta

**Pergunta:** qual IP teve mais tentativas de login com erro 401 no endpoint `/api/v1/login`, e quantas?

```bash
grep "/api/v1/login" logs/access.log | grep " 401 " | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 1
```

```text
vboxuser@Ubuntu-Pos:~/app-producao$ grep "/api/v1/login" logs/access.log | grep " 401 " | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 1
     10 192.168.1.15
```

**Resposta:** o IP **`192.168.1.15`** registrou **10 tentativas** com erro 401 no endpoint `/api/v1/login`.

**Função de cada bloco:**

| Bloco | O que faz |
|---|---|
| `grep "/api/v1/login" logs/access.log` | Filtra apenas as linhas que acessam o endpoint de login. |
| `grep " 401 "` | Dessas, mantém só as que têm o status 401 (não autorizado). Os espaços ao redor evitam casar o número em outros lugares da linha. |
| `awk '{print $1}'` | Extrai somente a primeira coluna de cada linha, que é o endereço IP. |
| `sort` | Ordena os IPs, deixando os iguais lado a lado (requisito para o `uniq` funcionar). |
| `uniq -c` | Agrupa os IPs repetidos e coloca na frente a contagem de quantas vezes cada um apareceu. |
| `sort -nr` | Ordena numericamente (`-n`) em ordem **decrescente** (`-r`), deixando o IP com mais tentativas no topo. |
| `head -n 1` | Mostra apenas a primeira linha, ou seja, o IP campeão de tentativas. |

### 3.2 Identificação de falhas críticas

**Pergunta:** quantas requisições receberam o código HTTP 500?

```bash
grep -c " 500 " logs/access.log
```

```text
vboxuser@Ubuntu-Pos:~/app-producao$ grep -c " 500 " logs/access.log
4
```

**Resposta:** **4 requisições** receberam erro 500.

**Função:** o `grep` procura no arquivo o padrão " 500 " (status 500 cercado por espaços) e a opção `-c` (count) faz com que, em vez de mostrar as linhas, ele retorne diretamente o total de linhas que casaram.

### 3.3 Geração do relatório

**Pergunta:** exportar a lista consolidada e ordenada dos IPs que geraram erros 4xx ou 5xx para `logs/relatorio-incidentes.txt`.

```bash
awk '$8 ~ /^[45]/ {print $1}' logs/access.log | sort -u > logs/relatorio-incidentes.txt
cat logs/relatorio-incidentes.txt
```

**Saída:**

```text
10.0.0.45
10.0.0.99
172.16.0.8
192.168.1.15
```

O relatório lista 4 IPs suspeitos, em ordem, sem repetição. O `192.168.1.15`, que teve 10 tentativas de login com erro 401 (item 3.1), agora aparece na lista.


**Função de cada bloco:**

| Bloco | O que faz |
|---|---|
| `awk '$8 ~ /^[45]/ {print $1}'` | Analisa o campo 8 (status HTTP). A condição `$8 ~ /^[45]/` usa uma expressão regular: `^` marca o início do valor e `[45]` aceita 4 ou 5, ou seja, qualquer status 4xx ou 5xx. Quando a condição é verdadeira, o `awk` imprime `$1`, o IP. |
| `sort -u` | Ordena os IPs e, com `-u` (unique), remove as duplicatas, deixando uma lista consolidada. |
| `> logs/relatorio-incidentes.txt` | Redireciona o resultado para o arquivo de relatório, em vez de mostrar na tela. |
| `cat logs/relatorio-incidentes.txt` | Exibe o relatório gerado para conferência. |

**Observação:** na primeira tentativa, escrevi `awk '$9 ~ /^[45]/ $1}'` (faltou o `{print` antes do `$1`) e o `awk` respondeu `extra '}'`. O erro era de sintaxe: a ação do `awk` precisa ficar inteira entre chaves, `{print $1}`.

**Segunda observação (validação):** depois de gerar o relatório, percebi que o IP `192.168.1.15`, o que mais errou no login (item 3.1), não aparecia nele. Ao inspecionar as linhas do log com `grep "192.168.1.15" logs/access.log | head -n 3`, vi que o status HTTP está na **coluna 8** e que a coluna 9 é o tamanho da resposta em bytes. Eu havia filtrado a coluna errada (`$9`) e, por isso, o relatório estava incompleto. Corrigi para `$8` e gerei o relatório de novo. Isso mostra a importância de conferir o formato real do log antes de escolher o campo no `awk`.

Os itens 3.1 e 3.2 não foram afetados: o `grep " 401 "` e o `grep -c " 500 "` procuram o status cercado por espaços e, como o tamanho da resposta é o último campo da linha (sem espaço depois), não há confusão entre os dois.

---

## Atividade 4 — Pesquisa autônoma: edição em lote com `sed` (Requisito 06)

**1. Como usar o `sed` com a flag `-i` para trocar `PORT=8080` por `PORT=3000` no `backend/.env` sem abrir um editor?**

```bash
sed -i 's/PORT=8080/PORT=3000/g' backend/.env
```

- **`sed`:** abreviação de *Stream Editor*, utilitário padrão para filtrar e transformar texto.
- **`-i` (in-place):** grava a alteração diretamente no arquivo original, em vez de apenas imprimir o resultado na tela.
- **`'s/PORT=8080/PORT=3000/g'`:** a expressão de substituição (`s` de *substitute*), no formato `s/padrão/substituto/flags`. Procura `PORT=8080` e troca por `PORT=3000`.
- **`g` (global):** troca todas as ocorrências do padrão na mesma linha, não só a primeira.

*Boa prática:* usar `-i.bak` (`sed -i.bak ...`) cria uma cópia de segurança do arquivo original antes da alteração.

**2. Por que usar `sed` em pipelines de automação (CI/CD) é preferível à edição manual em editores visuais?**

O `nano` e o `vim` foram feitos para humanos editarem texto olhando para uma tela. Já o ambiente de CI/CD roda sozinho em servidores remotos, sem ninguém na frente.

- **Funciona sem intervenção humana:** o CI/CD roda em segundo plano, sem tela nem interface. Tentar abrir um editor interativo travaria o processo, porque não há ninguém para digitar. O `sed` roda direto, em uma linha.
- **Permite injetar valores variáveis:** a cada deploy, valores como porta de rede ou token podem mudar e ser gerados na hora. Com o `sed`, o pipeline faz a troca automaticamente. Fazer isso na mão exigiria reescrever o arquivo a cada entrega.
- **É repetível e auditável:** o comando fica registrado no script do pipeline, então a mesma alteração é feita sempre do mesmo jeito.

---

## Atividade 5 — Experimentação com Inteligência Artificial

**Prompt enviado:**

> "No Linux Ubuntu, por que a permissão chmod 777 em diretórios de upload de um servidor web representa uma vulnerabilidade crítica de execução remota de código? Qual é a configuração correta de usuário, grupo e permissões octais para mitigar esse risco em aplicações web?"

### Síntese das conclusões

**Por que `chmod 777` no diretório de uploads é crítico (execução remota de código)**

O `777` concede leitura, escrita e execução irrestritas a todos. Num diretório de uploads isso abre uma cadeia de ataque:

1. O invasor envia um arquivo malicioso (por exemplo, um script que funciona como *webshell*) pelo formulário de upload.
2. Com permissão total, o arquivo é gravado no diretório e pode ficar com permissão de execução.
3. O invasor acessa a URL do arquivo e o servidor o executa, rodando comandos do invasor na máquina. Isso é a **execução remota de código (RCE)**.

Além disso, qualquer outro usuário ou processo do sistema também pode gravar ou apagar arquivos ali.

**Configuração correta de usuário, grupo e permissões**

O diretório e seu conteúdo devem pertencer exclusivamente ao usuário e grupo do servidor web:

```bash
sudo chown -R www-data:www-data /caminho/para/uploads
```

- **Diretórios (755):** o dono (`www-data`) lê, escreve e acessa (`rwx`); o grupo e os outros só listam e leem (`r-x`).

  ```bash
  sudo find /caminho/para/uploads -type d -exec chmod 755 {} \;
  ```

- **Arquivos (644):** leitura e escrita só para o dono; os demais apenas leitura. Nenhum arquivo enviado pode ter permissão de execução (`x`).

  ```bash
  sudo find /caminho/para/uploads -type f -exec chmod 644 {} \;
  ```

**Critério de sucesso:** os diretórios devem exibir `drwxr-xr-x` (755) e os arquivos `-rw-r--r--` (644), sem a letra `x` nas permissões de arquivos.

**Medidas complementares:** as permissões sozinhas não bastam. Também é recomendado validar o tipo e a extensão dos arquivos enviados, guardar os uploads fora da pasta que o servidor executa e configurar o servidor para nunca executar scripts dentro do diretório de uploads.

---

## Conclusão

- `chmod 600` no `.env` e `755`/`644` nos demais itens aplicam o princípio do **privilégio mínimo**: cada usuário recebe só o acesso de que precisa.
- Os pipelines com `grep`, `awk`, `sort` e `uniq` permitem transformar um log bruto em respostas objetivas (IP atacante, quantidade de erros 500, relatório de IPs suspeitos).
- O `sed -i` permite alterar configurações sem editor interativo, o que é essencial em automação (CI/CD).
- Permissão `777` em uploads, somada à possibilidade de execução, é um caminho direto para execução remota de código.

