# Prática 04 — Testes HTTP e acesso remoto SSH

Ambiente: Ubuntu (VirtualBox), projeto em `~/app-producao`.

---

## Atividade 1 — Execução e diagnóstico HTTP com shell scripting (Requisito 09)

### Comandos executados

```bash
cd ~/app-producao
python3 -m http.server 8080 --directory backend > logs/api.log 2>&1 &
ss -tuln | grep 8080
curl -I http://localhost:8080/api/server.js
echo 'export APP_API_URL="http://localhost:8080"' >> ~/.bashrc
echo "alias check-api='curl -s -I \$APP_API_URL | head -n 1'" >> ~/.bashrc
source ~/.bashrc
check-api
pkill -f "http.server 8080" 2>/dev/null || true
```

### Saídas obtidas

```text
vboxuser@Ubuntu-Pos:~/app-producao$ python3 -m http.server 8080 --directory backend > logs/api.log 2>&1 &
[1] 6494
vboxuser@Ubuntu-Pos:~/app-producao$ ss -tuln | grep 8080
tcp   LISTEN 0      5                                0.0.0.0:8080       0.0.0.0:*

vboxuser@Ubuntu-Pos:~/app-producao$ curl -I http://localhost:8080/api/server.js
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.14.4
Date: Fri, 20 Nov 2026 15:26:03 GMT
Content-type: text/javascript
Content-Length: 989
Last-Modified: Thu, 08 Oct 2026 22:51:17 GMT

vboxuser@Ubuntu-Pos:~/app-producao$ check-api
HTTP/1.0 200 OK

vboxuser@Ubuntu-Pos:~/app-producao$ pkill -f "http.server 8080" 2>/dev/null || true
[2]+  Terminated                 python3 -m http.server 8080 --directory backend > logs/api.log 2>&1
```

O `ss` mostra a porta 8080 no estado `LISTEN`, em `0.0.0.0` (todas as interfaces de rede), ou seja, a API estava no ar e aceitando conexões antes do teste com o `curl`.

### O que cada linha do script faz

| Linha | Função |
|---|---|
| `python3 -m http.server 8080 ... &` | Sobe a API em segundo plano na porta 8080, com os logs em `logs/api.log` (Prática 03). |
| `ss -tuln \| grep 8080` | Confirma que a porta 8080 está em escuta (`-t` TCP, `-u` UDP, `-l` listening, `-n` números). |
| `curl -I http://localhost:8080/api/server.js` | Faz uma requisição HEAD e mostra só os cabeçalhos de resposta. |
| `echo 'export APP_API_URL=...' >> ~/.bashrc` | Acrescenta ao final do `~/.bashrc` a variável de ambiente com a URL da API, tornando-a permanente. |
| `echo "alias check-api='...'" >> ~/.bashrc` | Acrescenta o atalho `check-api`. A barra em `\$APP_API_URL` impede que a variável seja expandida na hora de gravar, para que ela seja lida só quando o atalho for usado. |
| `source ~/.bashrc` | Recarrega o arquivo na sessão atual, para que a variável e o alias valham imediatamente. |
| `check-api` | Executa o alias: `curl -s -I $APP_API_URL \| head -n 1`, em que `-s` (silent) esconde a barra de progresso e `head -n 1` mostra só a primeira linha, a do status. |
| `pkill -f "http.server 8080"` | Encerra, por SIGTERM, o processo cuja linha de comando contém esse texto. O `2>/dev/null` descarta mensagens de erro e o `\|\| true` garante que o comando termine com sucesso mesmo quando não há processo para encerrar. |

### Análise crítica

**1. Significado das principais informações do cabeçalho do `curl -I` (status HTTP, tipo MIME e servidor)**

O `curl -I` (ou `--head`) faz uma requisição do tipo **HEAD**: pede ao servidor apenas os cabeçalhos da resposta, sem baixar o corpo do arquivo. Por isso é rápido e muito usado para diagnosticar APIs, redirecionamentos, cache e servidores web.

- **Código de status HTTP** (na saída: `HTTP/1.0 200 OK`): indica o resultado da requisição.
  - `1xx`: informativo.
  - `2xx`: sucesso (o `200 OK` da saída significa que o arquivo foi encontrado e entregue).
  - `3xx`: redirecionamento.
  - `4xx`: erro do cliente, como falta de autenticação (`401`), permissão negada (`403`) ou recurso inexistente (`404`).
  - `5xx`: erro do servidor (`500`, por exemplo).
- **Tipo de conteúdo MIME** (`Content-type: text/javascript`): informa o formato dos dados do corpo da resposta, para que o cliente saiba como tratá-los. Exemplos: `text/html; charset=UTF-8` (página web), `application/json` (resposta de API REST), `application/octet-stream` (arquivo binário para download), `image/png` ou `image/webp` (imagens). Aqui, o servidor reconheceu o `server.js` como JavaScript.
- **Servidor** (`Server: SimpleHTTP/0.6 Python/3.14.4`): identifica o software que processou e entregou a resposta. Pode ser um servidor web ou proxy reverso (`nginx/1.24.0 (Ubuntu)`, `Apache/2.4.58`), uma CDN ou plataforma de borda (`cloudflare`, `AmazonS3`, `Vercel`) ou um runtime de aplicação (`uvicorn`, `gunicorn`, `Kestrel`). No teste, é o servidor embutido do Python.

Outros cabeçalhos da saída batem com o que vimos na Prática 01: o `Content-Length: 989` é o mesmo tamanho em bytes mostrado pelo `stat`, e o `Last-Modified` corresponde à data de modificação do arquivo (08/10/2026, 22:51:17).

**2. Para que serve o `~/.bashrc` e por que é preciso `source ~/.bashrc`?**

O `~/.bashrc` é um script de configuração pessoal que o Bash executa automaticamente sempre que se abre uma nova janela ou aba de terminal interativo. Ele serve para personalizar o ambiente da conta do usuário: variáveis de ambiente (`export`), funções, aparência do prompt (`PS1`) e atalhos de comandos (`alias`).

O Bash lê o arquivo **uma única vez**, no momento em que a sessão do terminal começa, e guarda essas configurações na memória daquele processo. Alterar o arquivo no disco não muda o que já foi carregado no terminal aberto. O comando `source ~/.bashrc` (ou o atalho `. ~/.bashrc`) manda o terminal atual ler e executar cada linha do arquivo dentro do próprio processo, atualizando na hora a tabela de aliases e variáveis, sem precisar fechar e reabrir a janela.

---

## Atividade 2 — Desafio prático: governança criptográfica SSH (Requisito 10)

### 2.1 Geração das chaves Ed25519

```bash
# 1. Garantir que o diretório ~/.ssh exista e tenha a permissão estrita 700
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# 2. Gerar o par de chaves Ed25519 sem passphrase
ssh-keygen -t ed25519 -C "deploy@app-producao.local" -f ~/.ssh/id_ed25519_app -N ""
```

```text
vboxuser@Ubuntu-Pos:~/app-producao$ ssh-keygen -t ed25519 -C "deploy@app-producao.local" -f ~/.ssh/id_ed25519_app -N ""
Generating public/private ed25519 key pair.
Your identification has been saved in /home/vboxuser/.ssh/id_ed25519_app
Your public key has been saved in /home/vboxuser/.ssh/id_ed25519_app.pub
The key fingerprint is:
SHA256:Fhj9j6BKQ5l4ZYTDZ337G/SqUAxuDWifOG3Bp9OiJbQ deploy@app-producao.local
The key's randomart image is:
+--[ED25519 256]--+
|   . ooo         |
|    + ==o .      |
|   . O= *o..     |
|  . =o *.%o .    |
|   o  E.S.== .   |
|    o .O +. + .  |
|   . o. .    +   |
|    .    .  o    |
|          ..     |
+----[SHA256]-----+
```

| Opção | Função |
|---|---|
| `-t ed25519` | Escolhe o algoritmo de assinatura de curva elíptica Ed25519 (EdDSA sobre a Curve25519): moderno, rápido e com chaves muito menores que as de RSA para um nível de segurança equivalente. |
| `-C "deploy@app-producao.local"` | Adiciona um comentário identificador ao final da chave pública, facilitando a auditoria no servidor. |
| `-f ~/.ssh/id_ed25519_app` | Define o caminho e o nome do arquivo: `id_ed25519_app` (chave privada) e `id_ed25519_app.pub` (chave pública). |
| `-N ""` | Define a passphrase vazia, necessária para execuções não interativas em pipelines de CI/CD. Como a chave fica sem senha, a **permissão do arquivo passa a ser a única proteção** dela. |

### 2.2 Hardening das permissões

```bash
# Restringe o diretório ~/.ssh apenas ao proprietário (drwx------)
chmod 700 ~/.ssh

# Restringe a chave privada apenas ao proprietário (-rw-------)
chmod 600 ~/.ssh/id_ed25519_app

# Chave pública legível por todos (-rw-r--r--)
chmod 644 ~/.ssh/id_ed25519_app.pub

# Audita as permissões aplicadas
ls -ld ~/.ssh && ls -l ~/.ssh/id_ed25519_app
```

```text
vboxuser@Ubuntu-Pos:~/app-producao$ ls -ld ~/.ssh && ls -l ~/.ssh/id_ed25519_app
drwx------ 2 vboxuser vboxuser 4096 Nov 20 15:28 /home/vboxuser/.ssh
-rw------- 1 vboxuser vboxuser 419 Nov 20 15:28 /home/vboxuser/.ssh/id_ed25519_app
```

### 2.3 Autorização de acesso

```bash
# Anexa a chave pública ao final do authorized_keys (cria o arquivo se não existir)
cat ~/.ssh/id_ed25519_app.pub >> ~/.ssh/authorized_keys

# Restringe leitura e escrita apenas ao proprietário (-rw-------)
chmod 600 ~/.ssh/authorized_keys

# Verifica a permissão e o conteúdo
ls -l ~/.ssh/authorized_keys && tail -n 1 ~/.ssh/authorized_keys
```

```text
vboxuser@Ubuntu-Pos:~/app-producao$ ls -l ~/.ssh/authorized_keys && tail -n 1 ~/.ssh/authorized_keys
-rw------- 1 vboxuser vboxuser 107 Nov 20 15:30 /home/vboxuser/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK+0iIGPPL6mrFho8QM4/HsNYRiOzOGiL+8rT+0KFj9y deploy@app-producao.local
```

O `>>` acrescenta a chave ao final do arquivo, **sem apagar** chaves que já estivessem cadastradas (um único `>` sobrescreveria o arquivo). A linha final tem o formato esperado: `ssh-ed25519 AAAAC3... deploy@app-producao.local`.

### 2.4 Auditoria da estrutura

```bash
ls -la ~/.ssh
```

```text
vboxuser@Ubuntu-Pos:~/app-producao$ ls -la ~/.ssh
total 20
drwx------  2 vboxuser vboxuser 4096 Nov 20 15:28 .
drwxr-x--- 17 vboxuser vboxuser 4096 Nov 20 14:49 ..
-rw-------  1 vboxuser vboxuser  107 Nov 20 15:30 authorized_keys
-rw-------  1 vboxuser vboxuser  419 Nov 20 15:28 id_ed25519_app
-rw-r--r--  1 vboxuser vboxuser  107 Nov 20 15:28 id_ed25519_app.pub
```

A estrutura final está como esperado: a pasta em `drwx------`, a chave privada e o `authorized_keys` em `-rw-------` e a chave pública em `-rw-r--r--`. O `authorized_keys` tem 107 bytes, o mesmo tamanho da chave pública, o que confirma que contém só a chave cadastrada.

### 2.5 Fundamentação de cada permissão octal

| Item | Octal | Permissões | Fundamentação |
|---|---|---|---|
| Pasta `~/.ssh` | `700` | `drwx------` | Dono: leitura (4) + escrita (2) + acesso/travessia (1) = 7; grupo e outros: 0. Em um diretório, o `x` permite entrar e acessar o conteúdo. Bloqueia qualquer listagem ou modificação por outros usuários do sistema. |
| Chave privada `id_ed25519_app` | `600` | `-rw-------` | Leitura (4) + escrita (2) só para o dono. A chave privada é a identidade do usuário e está sem passphrase, então ninguém mais pode ler. O **cliente** `ssh` recusa usar uma chave privada com permissões abertas demais (Atividade 4). |
| Chave pública `id_ed25519_app.pub` | `644` | `-rw-r--r--` | A chave pública **não é segredo**: pode ser lida por outros (leitura = 4) e é feita para ser distribuída. Só o dono pode alterá-la (escrita = 2). |
| `authorized_keys` | `600` | `-rw-------` | Lista quem pode entrar na conta. Se outro usuário pudesse escrever nele, poderia injetar a própria chave e ganhar acesso. Atende à diretiva `StrictModes yes` do servidor `sshd`, que verifica as permissões desse arquivo, da pasta `~/.ssh` e do diretório pessoal antes de aceitar a autenticação por chave. |

---

## Atividade 3 — Pesquisa autônoma: hardening do daemon OpenSSH

As diretivas ficam no arquivo `/etc/ssh/sshd_config`, que configura o servidor SSH (`sshd`).

**1. Quais são e o que fazem as 3 diretivas fundamentais?**

- **`PubkeyAuthentication yes` (habilita a autenticação por chaves):** permite que o servidor aceite conexões baseadas em pares de chaves assimétricas: a chave privada fica no cliente e a chave pública, registrada em `~/.ssh/authorized_keys` no servidor. É o pré-requisito para substituir senhas por uma validação criptográfica forte.
- **`PasswordAuthentication no` (desativa o login por senha):** bloqueia qualquer tentativa de autenticação por senha digitada. Na prática, neutraliza ataques automatizados de força bruta e de dicionário, porque o servidor recusa a conexão se o cliente não tiver a chave privada autorizada.
- **`PermitRootLogin no` (bloqueia o acesso direto como superusuário):** impede conectar diretamente como `root` via SSH, mesmo com senha ou chave válida. Obriga o administrador a entrar com um usuário comum e só depois elevar privilégios com `sudo`, o que garante rastreabilidade nos logs de auditoria e reduz a superfície de ataque na conta mais crítica do sistema.

*Cuidados ao aplicar:* cadastre e teste a chave pública **antes** de desligar a senha, para não ficar sem acesso ao servidor. Depois de editar o arquivo, valide a sintaxe com `sudo sshd -t` e recarregue o serviço (`sudo systemctl restart ssh`). Em algumas instalações do Ubuntu, arquivos em `/etc/ssh/sshd_config.d/` podem sobrescrever as configurações; vale conferir.

**2. Por que manter login e senha abertos na porta 22 torna o servidor vulnerável a força bruta e dicionário?**

- **A porta 22 é muito visada:** bots varrem continuamente toda a faixa de endereços IPv4 públicos da internet atrás de portas 22 abertas. Assim que um servidor responde, seu IP entra em listas de ataque automático em questão de minutos.
- **Os nomes de usuário são conhecidos:** sistemas Linux têm contas padrão previsíveis (`root`, `ubuntu`, `admin`, `deploy`), o que elimina metade do trabalho do invasor, já que só falta descobrir a senha. Sem bloqueio automático (como o `fail2ban`) ou sem desativar as senhas, o `sshd` aceita milhares de tentativas sequenciais vindas de redes distribuídas (botnets).
- **As senhas humanas são previsíveis:** seguem padrões comuns ou são reaproveitadas de vazamentos antigos. Os scripts testam milhões de combinações de palavras comuns e variações numéricas (dicionário) e de sequências de caracteres (força bruta) de forma ininterrupta, até acertar uma credencial fraca.

Com chaves criptográficas, esse ataque deixa de ser viável: uma chave Ed25519 não pode ser "adivinhada" por tentativa e erro como uma senha.

---

## Atividade 4 — Experimentação com Inteligência Artificial

**Prompt enviado:**

> "No Linux, por que o cliente OpenSSH se recusa terminantemente a utilizar uma chave privada caso ela esteja com permissão 644 ou 777, exibindo o erro 'Permissions are too open'? Explique a fundamentação técnica de segurança defensiva por trás dessa decisão de projeto."

### Resumo da resposta e relação com o princípio do menor privilégio

Quando a chave privada está com permissão `644` ou `777`, o cliente `ssh` se recusa a usá-la e exibe um aviso como:

```text
WARNING: UNPROTECTED PRIVATE KEY FILE!
Permissions 0644 for '/home/usuario/.ssh/id_ed25519_app' are too open.
It is required that your private key files are NOT accessible by others.
This private key will be ignored.
```

**Fundamentação técnica:**

- A chave privada é a **identidade de autenticação** de um único usuário. Quem a possui consegue se passar por ele em qualquer servidor que confie na chave pública correspondente.
- Com `644`, **qualquer usuário local** pode ler (e copiar) a chave. Com `777`, qualquer um pode também **alterá-la ou substituí-la**. Se a chave não tem passphrase, como a que geramos para o CI/CD, basta ler o arquivo para usá-la.
- Por isso o OpenSSH adota a postura *fail closed* (falhar de forma segura): em vez de usar uma credencial em estado inseguro e apenas avisar, ele **recusa** o uso e obriga a corrigir o problema. Isso protege o usuário de um descuido de configuração.

**Relação com o princípio do menor privilégio (PoLP, *Principle of Least Privilege*):** o princípio determina que cada usuário ou processo tenha acesso apenas aos recursos indispensáveis para sua função. Como só o dono precisa ler a chave privada, nenhum outro usuário ou serviço (exceto o administrador, `root`) precisa de qualquer permissão sobre ela. Ao exigir a permissão mínima que funciona (`600`, ou `400` para somente leitura), o OpenSSH reduz a superfície de ataque local e impede que o comprometimento de **outra conta no mesmo servidor** vaze as credenciais SSH (movimentação lateral).

É a mesma lógica aplicada ao longo das práticas: `600` no `.env` (Prática 02), `700` na pasta `~/.ssh` e `600` na chave privada e no `authorized_keys`.

---

## Conclusão

- O `curl -I` permite diagnosticar rapidamente uma API (status, tipo de conteúdo e servidor), e variáveis e aliases no `~/.bashrc` automatizam esse teste; o `source` recarrega o arquivo na sessão atual.
- A autenticação por chave Ed25519 elimina a dependência de senhas, mas exige permissões rigorosas: `700` na pasta, `600` na chave privada e no `authorized_keys`, e `644` na chave pública.
- As diretivas `PubkeyAuthentication yes`, `PasswordAuthentication no` e `PermitRootLogin no` protegem o servidor contra ataques de força bruta e contra o acesso direto como `root`.
- A recusa do OpenSSH a chaves com permissões abertas é uma aplicação direta do princípio do menor privilégio.

