# Prática 01 — Estrutura de servidor web: navegação, links simbólicos e limpeza

Ambiente: Ubuntu (VirtualBox), projeto em `~/app-producao`.

---

## Atividade 1 — Navegação, inspeção e deploy atômico (Requisitos 01 e 03)

### Comandos executados

```bash
cd ~/app-producao
ls -la
ls -l backend/
ln -s backend/api current-api
ls -l current-api
```

**Saída do `ls -la`:**

```text
vboxuser@Ubuntu-Pos:~/app-producao$ ls -la
total 92
drwxrwxr-x  9 vboxuser vboxuser  4096 Nov 20 15:20 .
drwxr-x--- 17 vboxuser vboxuser  4096 Nov 20 14:49 ..
drwxrwxr-x  7 vboxuser vboxuser  4096 Nov 14 16:27 .git
-rw-rw-r--  1 vboxuser vboxuser    43 Nov 12 00:23 .gitignore
-rw-r--r--  1 vboxuser vboxuser  1172 Oct  8 22:53 README.md
drwxr-xr-x  3 vboxuser vboxuser  4096 Nov 14 15:34 backend
drwxr-xr-x  2 vboxuser vboxuser  4096 Oct  8 22:51 config
lrwxrwxrwx  1 vboxuser vboxuser    11 Nov  9 22:19 current-api -> backend/api
drwxr-xr-x  4 vboxuser vboxuser  4096 Oct  8 22:50 frontend
drwxr-xr-x  2 vboxuser vboxuser  4096 Nov 16 23:28 logs
drwxrwxr-x  2 vboxuser vboxuser  4096 Nov 16 23:28 pids
-rw-rw-r--  1 vboxuser vboxuser  3548 Nov 14 13:49 pratica-01.md
-rw-rw-r--  1 vboxuser vboxuser 12378 Nov 20 15:20 pratica-02.md
-rw-rw-r--  1 vboxuser vboxuser 13737 Nov 20 15:20 pratica-03.md
-rw-rw-r--  1 vboxuser vboxuser 10946 Nov 20 15:20 pratica-04.md
drwxrwxr-x  2 vboxuser vboxuser  4096 Oct  8 22:52 scripts
```

Aqui aparecem os itens ocultos: `.` e `..` (diretório atual e diretório pai), a pasta `.git` e o arquivo `.gitignore`.

**Saída do `ls -l backend/` e do link criado:**

```text
vboxuser@Ubuntu-Pos:~/app-producao$ ls -l backend/
total 4
drwxrwxr-x 2 vboxuser vboxuser 4096 Oct  8 22:51 api

vboxuser@Ubuntu-Pos:~/app-producao$ ln -s backend/api current-api
vboxuser@Ubuntu-Pos:~/app-producao$ ls -l current-api
lrwxrwxrwx 1 vboxuser vboxuser 11 Nov  9 22:19 current-api -> backend/api
```

O `l` no início das permissões (`lrwxrwxrwx`) indica que `current-api` é um link simbólico, e a seta mostra o destino: `backend/api`.

*Observação:* como o `current-api` já existia, ao repetir o `ln -s backend/api current-api` o `ln` tratou o link existente como uma pasta e criou um segundo link dentro de `backend/api` (`backend/api/api -> backend/api`), que ficou quebrado. Para evitar isso, o comando pode ser repetido com `ln -sfn`, que substitui o link existente em vez de criar outro dentro dele. O link extra foi removido com `rm backend/api/api` (que remove só o link, não a pasta real).

### Análise crítica

**1. Qual é a diferença entre a saída do `ls` comum e a do `ls -la`? Que tipo de arquivos a flag `-a` tornou visíveis?**

- O `ls` comum lista apenas os nomes dos arquivos e pastas visíveis do diretório, de forma resumida.
- O `ls -la` combina duas flags:
  - `-l` (formato longo): mostra uma linha por item, com permissões, número de links, dono, grupo, tamanho e data da última modificação.
  - `-a` (all): torna visíveis os arquivos e diretórios **ocultos**, aqueles cujo nome começa com ponto (`.`). Isso inclui `.git` (a pasta do repositório), outros arquivos de configuração como o `.gitignore` e as entradas especiais `.` (o diretório atual) e `..` (o diretório pai).

**2. O que o comando `ln -s` realizou? Por que links simbólicos para a versão ativa da aplicação (`current-api`) são prática padrão em deploys atômicos (zero downtime)?**

O comando `ln -s backend/api current-api` criou um **link simbólico** (*symbolic link*): um atalho chamado `current-api` que aponta para a pasta real `backend/api`, parecido com um atalho do Windows. Quem acessa `current-api` é levado ao conteúdo de `backend/api`, e o `ls -l` mostra isso com a seta `current-api -> backend/api`.

Esse padrão é adotado na indústria por dois motivos:

- **Atualização trocando só o atalho:** serviços, scripts e configurações apontam sempre para o mesmo caminho fixo (`current-api`). Quando sai uma nova versão, ela é publicada em uma pasta própria e basta apontar o link para ela. Tudo que usava `current-api` passa a usar a versão nova, sem editar nenhuma configuração.
- **Troca instantânea (zero downtime) e rollback fácil:** repontar o link é uma operação praticamente instantânea, então não existe um momento em que a aplicação fica "meio copiada". Se a versão nova der problema, o rollback é apontar o link de volta para a pasta anterior, que continua intacta.

---

## Atividade 2 — Desafio prático: limpeza de resíduos e governança (Requisitos 01 e 02)

### 2.1 Localizar e remover com segurança os arquivos `.tmp`

```bash
find . -name "*.tmp" -type f
find . -name "*.tmp" -type f -exec rm -f {} +
find . -name "*.tmp" -type f
```

Os arquivos removidos eram os três `.tmp` do pacote base: `temp_build.tmp`, `backend/temp_debug.tmp` e `logs/cache_antigo.tmp`. Ao executar o `find` novamente, ele não retornou nada, o que confirma que a limpeza foi concluída e que não restou nenhum `.tmp` no projeto.

**Raciocínio:**

1. **Primeiro listei, sem apagar.** O `find . -name "*.tmp" -type f` procura a partir da pasta atual (`.`), de forma recursiva, por arquivos (`-type f`) cujo nome termina em `.tmp`. Conferir a lista antes evita apagar algo por engano.
2. **Depois removi.** Repeti o mesmo `find` e acrescentei `-exec rm -f {} +`, que executa o `rm -f` sobre todos os arquivos encontrados (`{}` é substituído pelos nomes, e o `+` agrupa vários arquivos em uma única chamada do `rm`, o que é mais eficiente).
3. **Por fim, rodei o `find` de novo** para confirmar que não restou nenhum `.tmp`.

Usar o padrão `"*.tmp"` (com o ponto) é importante: um `"*tmp"` sem o ponto também casaria arquivos como `xtmp` ou `data_tmp`, que não são temporários.

### 2.2 Copiar o modelo de ambiente para a configuração ativa

```bash
cp config/env.template backend/.env
ls -la backend/.env
```

**Raciocínio:** o `cp` copia o modelo oficial `config/env.template` para `backend/.env`, que é o arquivo de configuração que a aplicação realmente lê. O modelo permanece intacto, como referência. O `ls -la backend/.env` confirma que o arquivo foi criado (o `-a` não é necessário para um arquivo informado diretamente, mas o `-l` mostra permissões, dono e tamanho). Como esse arquivo vai guardar credenciais, ele recebeu depois a permissão `600` (Prática 02).

### 2.3 Criar o `.gitignore`

```bash
nano .gitignore
```

Conteúdo final do arquivo:

```text
node_modules/
backend/.env
logs/*.log
*.tmp
pids/
```

As linhas `*.tmp`, `logs/*.log` e `backend/.env` atendem ao enunciado. As outras duas são extras: `node_modules/` ignora as dependências do Node.js (que não devem ser versionadas) e `pids/` ignora os arquivos de PID gerados em tempo de execução.

**Atalhos usados no `nano`:** **Ctrl+O** para salvar, **Enter** para confirmar o nome do arquivo e **Ctrl+X** para sair do editor.

**Validação:**

```bash
git status
```

**Raciocínio:** cada linha do `.gitignore` cobre um requisito do enunciado: `*.tmp` (arquivos temporários), `logs/*.log` (logs de execução, que mudam o tempo todo e podem conter dados sensíveis) e `backend/.env` (credenciais, que **nunca** devem ir para o repositório). O `git status` valida o resultado: os arquivos ignorados deixam de aparecer na lista de arquivos não rastreados (*untracked*), e o próprio `.gitignore` aparece como novo arquivo a ser versionado.

---

## Atividade 3 — Pesquisa autônoma: filtros de tempo e tamanho no `find` (Requisito 03)

**1. Como estruturar um `find` para listar apenas arquivos modificados nos últimos 7 dias dentro de `logs/`?**

```bash
find logs/ -type f -mtime -7
```

- `logs/` é o diretório onde a busca começa.
- `-type f` restringe a arquivos, excluindo diretórios.
- `-mtime -7` filtra pela data de modificação (*modification time*), mantendo os modificados há menos de 7 dias.

**2. Qual é a diferença técnica essencial entre `-mtime -7` e `-mtime +7`?**

O `find` mede a idade do arquivo em períodos completos de 24 horas, desprezando a fração. O sinal antes do número indica a comparação:

- **`-mtime -7` (menos de 7 dias):** arquivos modificados há menos de 7 períodos de 24 horas, ou seja, de 0 a 6 dias atrás. São os arquivos **recentes**.
- **`-mtime +7` (mais de 7 dias):** arquivos modificados há mais de 7 períodos completos, ou seja, 8 dias ou mais. São os arquivos **antigos**, úteis, por exemplo, para localizar logs que podem ser apagados.
- **`-mtime 7` (sem sinal):** arquivos com idade exatamente igual a 7 períodos (entre 7 e 8 dias atrás).

**3. Como adicionar a flag `-size` para filtrar apenas arquivos com mais de 10 megabytes?**

```bash
find logs/ -type f -mtime -7 -size +10M
```

O `-size +10M` mantém apenas arquivos maiores que 10 MiB (o sinal `+` significa "maior que"; `M` é a unidade de megabytes). Outras unidades possíveis são `c` (bytes), `k` (kilobytes) e `G` (gigabytes). Os testes do `find` são combinados com **E** lógico: o arquivo precisa ser comum, recente **e** grande.

---

## Atividade 4 — Experimentação com Inteligência Artificial

**Prompt enviado:**

> "No Linux Ubuntu, qual a diferença entre os comandos file e stat? Como o comando file consegue determinar se um arquivo é um script executável, um texto ASCII ou uma imagem JPEG mesmo que ele não possua extensão no nome?"

### Resumo dos principais pontos aprendidos

- **`file`** identifica o **tipo lógico do conteúdo** do arquivo (script Node.js, texto ASCII, imagem PNG ou JPEG etc.), independentemente da extensão no nome. Ele faz isso lendo os **magic numbers**, os bytes iniciais característicos de cada formato (por exemplo, um JPEG começa com os bytes `FF D8 FF`). Quando o arquivo é texto puro e não tem assinatura, o `file` recorre a outras pistas, como a linha inicial `#!` (*shebang*) de um script e a análise dos caracteres e padrões do texto.
- **`stat`** mostra os **metadados do sistema de arquivos**: tamanho exato em bytes, permissões, *inode*, dono (UID) e grupo (GID) e três datas: acesso (*Access*), modificação do conteúdo (*Modify*) e mudança de metadados (*Change*, por exemplo após um `chmod`).

Em resumo: o `file` responde "**o que é** este arquivo?", e o `stat` responde "**quais são os dados do sistema** sobre ele?".

### Teste prático

```bash
file backend/api/server.js
stat backend/api/server.js
```

```text
vboxuser@Ubuntu-Pos:~/app-producao$ file backend/api/server.js
backend/api/server.js: JavaScript source, ASCII text
vboxuser@Ubuntu-Pos:~/app-producao$ stat backend/api/server.js
  File: backend/api/server.js
  size: 989       	Blocks: 8          IO Block: 4096   regular file
Device: 8,2	Inode: 285277      Links: 1
Access: (0644/-rw-r--r--)  Uid: ( 1000/vboxuser)   Gid: ( 1000/vboxuser)
Access: 2026-11-14 13:42:32.963634211 +0000
Modify: 2026-10-08 22:51:17.000000000 +0000
Change: 2026-11-09 22:18:40.020453376 +0000
 Birth: 2026-11-09 22:18:40.020432987 +0000
```

**Interpretação:**

- O `file` identificou o arquivo como **código-fonte JavaScript em texto ASCII**.
- O `stat` mostra um arquivo regular de **989 bytes**, com permissão **0644** (`-rw-r--r--`: dono lê e escreve, os demais só leem), pertencente ao usuário e grupo `vboxuser` (UID e GID 1000).
- As datas diferem: o **Modify** (conteúdo alterado pela última vez, em 08/10/2026) é anterior ao **Change** e ao **Birth** (09/11/2026, quando o arquivo foi criado nesta máquina), o que é normal para um arquivo extraído de um pacote que preserva a data original de modificação.

---

## Conclusão

- `ls -la` revela os arquivos ocultos e os detalhes de cada item; `ln -s` cria o atalho `current-api`, base de deploys com troca instantânea e rollback simples.
- O `find` com `-name`, `-type`, `-exec`, `-mtime` e `-size` permite localizar e limpar arquivos com precisão, e vale sempre listar antes de apagar.
- O `.gitignore` mantém fora do repositório os temporários, os logs e o `.env` com credenciais.
- `file` e `stat` se complementam: o primeiro identifica o conteúdo pelo magic number, e o segundo expõe os metadados do arquivo.
