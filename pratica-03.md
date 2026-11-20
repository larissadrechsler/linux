# Prática 03 — Ciclo de vida de processos, monitoramento e graceful shutdown

Ambiente: Ubuntu (VirtualBox), projeto em `~/app-producao`.

---

## Atividade 1 — Execução em background e encerramento gracioso (Requisito 07)

### Comandos executados

```bash
cd ~/app-producao
mkdir -p pids
python3 -m http.server 8080 --directory backend > logs/api.log 2>&1 &
echo $! > pids/api.pid
cat pids/api.pid
ps aux | grep "http.server 8080" | grep -v grep
kill -15 $(cat pids/api.pid)
```

**Saída obtida:**

```text
vboxuser@Ubuntu-Pos:~/app-producao$ mkdir -p pids
vboxuser@Ubuntu-Pos:~/app-producao$ python3 -m http.server 8080 --directory backend > logs/api.log 2>&1 &
[1] 5734
vboxuser@Ubuntu-Pos:~/app-producao$ echo $! > pids/api.pid
vboxuser@Ubuntu-Pos:~/app-producao$ cat pids/api.pid
5734
vboxuser@Ubuntu-Pos:~/app-producao$ ps aux | grep "http.server 8080" | grep -v grep
vboxuser    5734  0.3  0.8  38008 22492 pts/0    S    15:08   0:00 python3 -m http.server 8080 --directory backend
vboxuser@Ubuntu-Pos:~/app-producao$ kill -15 $(cat pids/api.pid)
[1]+  Terminated                 python3 -m http.server 8080 --directory backend > logs/api.log 2>&1
```

O PID `5734` mostrado pelo shell (`[1] 5734`) é o mesmo gravado em `pids/api.pid` e o mesmo que aparece no `ps aux`. Nessa linha, o processo ocupava cerca de 22 MB de RAM (coluna RSS, `22492` KB) e estava no estado `S` (dormindo, aguardando conexões). Depois do `kill -15`, o shell exibiu `Terminated`, confirmando o encerramento.

### Análise crítica

**1. O que os operadores `&` e `> logs/api.log 2>&1` realizaram na linha de execução da aplicação?**

A linha roda a API em segundo plano e envia toda a sua saída para um arquivo de texto.

- `&` instrui o shell a executar o comando em segundo plano (background). O terminal fica livre logo após o comando ser disparado, em vez de ficar preso à aplicação.
- `> logs/api.log` redireciona a saída padrão (stdout, descritor 1) para o arquivo `logs/api.log`, em vez de mostrá-la na tela.
- `2>&1` junta a saída de erro com a saída normal:
  - `2` é a saída de erro (stderr), onde a aplicação escreve exceções, falhas e mensagens de erro;
  - `&1` indica "o mesmo destino do descritor 1" (a saída normal).

  Com isso, erros e logs comuns ficam no mesmo arquivo, `logs/api.log`. A ordem importa: `2>&1` precisa vir depois do `> logs/api.log`.

**2. O que a variável especial `$!` capturou para ser salva dentro de `pids/api.pid`?**

A variável `$!` guarda o PID (identificador do processo) do último comando executado em segundo plano, ou seja, o do `python3 -m http.server`. Salvar esse número em `pids/api.pid` permite encerrar exatamente esse processo depois, com `kill $(cat pids/api.pid)`, sem precisar procurar com `ps | grep`.

**3. Qual é a diferença técnica essencial entre SIGTERM (`kill -15`) e SIGKILL (`kill -9`)? Por que é uma péssima prática começar o encerramento de serviços web com `kill -9`?**

- **SIGTERM (15)** é um pedido educado de encerramento. O sinal chega ao processo, que pode capturá-lo, tratá-lo ou ignorá-lo. Isso permite que a aplicação execute uma rotina de limpeza (graceful shutdown): terminar as requisições em andamento, fechar conexões e liberar recursos.
- **SIGKILL (9)** é uma ordem direta ao kernel do sistema operacional. Ele não pode ser capturado, tratado nem ignorado: o processo é removido imediatamente, sem chance de salvar estado, fechar conexões ou liberar recursos.

Iniciar com `kill -9` num servidor web é má prática porque pode causar requisições cortadas no meio (o usuário recebe erro), escritas incompletas e corrupção de dados, conexões com banco de dados abandonadas, arquivos temporários e locks que sobram (vazamento de recursos). A prática recomendada é enviar SIGTERM primeiro, aguardar um tempo razoável e usar SIGKILL só como último recurso, se o processo não responder.

---

## Atividade 2 — Diagnóstico de hardware e portas de rede (Requisito 08)

### 2.1 Auditoria de memória RAM

**Comando:**

```bash
free -h
```

`-h` (human-readable) converte os valores de bytes para MiB ou GiB.

**Saída:**

```text
vboxuser@Ubuntu-Pos:~/app-producao$ free -h
               total        used        free      shared  buff/cache   available
Mem:           2.6Gi       1.4Gi       144Mi        50Mi       1.1Gi       1.1Gi
```

**Comando complementar** (formato em lista, útil para scripts):

```bash
cat /proc/meminfo | head -n 5
```

```text
MemTotal:        2691784 kB
MemFree:          132232 kB
MemAvailable:     827904 kB
Buffers:            5948 kB
Cached:           849216 kB
```

*Observação:* os dois comandos acima foram executados em momentos diferentes, e a memória livre varia a cada instante. Por isso o `MemAvailable` (cerca de 0,8 GiB) e a coluna `available` do `free -h` (1,1 GiB) não coincidem exatamente.

**Resumo das saídas:**

| Informação pedida | Valor | Coluna |
|---|---|---|
| Memória total | 2,6 GiB | `total` |
| Usada por processos ativos | 1,4 GiB | `used` |
| Usada como buffers/cache do SO | 1,1 GiB | `buff/cache` |

**Como interpretar os valores de RAM no Linux:**

- **total:** toda a memória RAM física da máquina.
- **used:** memória consumida diretamente por programas e serviços em execução.
- **free:** memória totalmente ociosa, sem nenhum uso. Costuma ser baixa no Linux (aqui, 144 MiB), e isso **não é um problema**.
- **buff/cache:** memória que o kernel usa para guardar dados de disco já lidos e acelerar acessos futuros. Ela é liberada automaticamente quando algum programa precisa dela.
- **available:** estimativa de quanto de memória pode ser entregue a novos programas sem usar swap. Ela soma o `free` e a parte do cache que pode ser devolvida. **É a coluna mais útil para avaliar se a máquina tem folga**: aqui, cerca de 1,1 GiB.

Por isso, olhar só a coluna `free` engana: o Linux usa de propósito a RAM sobrando como cache. O que importa para a prontidão operacional é o `available`.

### 2.2 Auditoria de armazenamento

**Comando:**

```bash
df -h /
```

- `df` (disk free) exibe o uso dos sistemas de arquivos.
- `-h` mostra os tamanhos em unidades legíveis (GB, MB).
- `/` filtra a saída para mostrar apenas a partição raiz.

**Saída:**

```text
vboxuser@Ubuntu-Pos:~/app-producao$ df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda2        24G  7.0G   16G  32% /
```

**Resumo:** a partição raiz está com **32% de uso** (7,0 GB usados de 24 GB, com 16 GB livres), o que dá folga para a aplicação.

**Comando complementar** (tamanho dos itens do projeto):

```bash
du -sh *
```

```text
16K	backend
12K	config
0	current-api
20K	frontend
20K	logs
8.0K	pids
4.0K	pratica-01.md
8.0K	pratica-02.md
12K	pratica-03.md
4.0K	README.md
12K	scripts
```

- `du` (disk usage) estima o espaço ocupado pelos arquivos.
- `-s` (summarize) mostra só o total de cada item, sem detalhar os subarquivos.
- `-h` converte para unidades legíveis (K, M, G).
- `*` aplica o comando a todos os itens visíveis da pasta.

### 2.3 Auditoria de portas ocupadas

**Comandos:**

```bash
python3 -m http.server 8080 --directory backend > logs/api.log 2>&1 &
ss -tulpn | grep :8080
lsof -i :8080
kill 5436
```

**Saídas:**

```text
vboxuser@Ubuntu-Pos:~/app-producao$ python3 -m http.server 8080 --directory backend > logs/api.log 2>&1 &
[1] 5436
vboxuser@Ubuntu-Pos:~/app-producao$ ss -tulpn | grep :8080
tcp   LISTEN 0      5      0.0.0.0:8080     0.0.0.0:*    users:(("python3",pid=5436,fd=3))
vboxuser@Ubuntu-Pos:~/app-producao$ lsof -i :8080
COMMAND  PID     USER FD   TYPE DEVICE SIZE/OFF NODE NAME
python3 5436 vboxuser 3u  IPv4  34041      0t0  TCP *:http-alt (LISTEN)
vboxuser@Ubuntu-Pos:~/app-producao$ kill 5436
[1]+  Terminated                 python3 -m http.server 8080 --directory backend > logs/api.log 2>&1
```

**Parâmetros do `ss`:** `-t` (TCP), `-u` (UDP), `-l` (apenas portas em escuta/listening), `-p` (mostra o nome e o PID do processo) e `-n` (exibe o número da porta, 8080, em vez do nome do serviço).

**Resumo e prova:** tanto o `ss` quanto o `lsof` mostram que a porta 8080 está em escuta (`LISTEN`) pelo processo **`python3`, PID `5436`**, do usuário `vboxuser`. No `ss`, o endereço `0.0.0.0:8080` indica que a porta aceita conexões em todas as interfaces de rede. O `lsof` mostra `*:http-alt` porque `http-alt` é o nome registrado da porta 8080. O PID 5436 é o mesmo que o shell informou ao iniciar o processo em background (`[1] 5436`).

**Encerramento gracioso:** `kill 5436` sem argumentos envia SIGTERM (o mesmo que `kill -15`), diferente do `kill -9` (SIGKILL). A mensagem `Terminated` do shell confirmou que o processo foi encerrado, o que libera a porta 8080.

---

## Atividade 3 — Pesquisa autônoma: métricas de memória no top/htop (Requisito 08)

**1. Qual é a diferença conceitual entre VIRT, RES e SHR?**

- **VIRT (Virtual Image / memória virtual):** total de memória virtual que o processo enxerga. Inclui código, bibliotecas mapeadas, páginas que estão em swap e espaços apenas reservados, que ainda não ocupam RAM de verdade.
- **RES (Resident Size / memória residente):** quantidade de memória física (RAM) que o processo ocupa de fato naquele instante, sem contar o que foi para o swap.
- **SHR (Shared Memory / memória compartilhada):** parcela da memória do processo que pode ser compartilhada com outros processos, como bibliotecas dinâmicas (`.so`) e memória de comunicação entre processos (IPC).

**2. Ao monitorar um processo web (Node.js ou Python), qual métrica reflete com maior precisão a memória física realmente ocupada?**

A **RES**.

- Runtimes como Python e Node.js (motor V8) costumam reservar grandes blocos de espaço virtual para o heap e o garbage collector, então o **VIRT** parece muito maior do que a RAM realmente consumida.
- O **SHR** contabiliza apenas o trecho compartilhável, como bibliotecas do sistema.
- O **RES** mostra quanta RAM física está alocada naquele momento para manter o servidor ativo.

*Nota complementar:* se vários processos idênticos (por exemplo, workers) estiverem rodando, parte do RES de cada um inclui o mesmo SHR. A memória privada exclusiva de cada processo é aproximadamente `RES - SHR` (conhecida como USS, *Unique Set Size*). Para contar o compartilhado de forma proporcional entre os processos, existe também a métrica PSS.

---

## Atividade 4 — Experimentação com Inteligência Artificial

**Prompt enviado:**

> "No Linux Ubuntu, por que processos que são encerrados abruptamente com kill -9 podem deixar portas TCP presas em estado TIME_WAIT ou conexões de banco de dados órfãs? Como uma aplicação Node.js ou Python deve tratar o sinal SIGTERM para realizar um encerramento gracioso (Graceful Shutdown)?"

### Resumo dos principais pontos aprendidos

**1. Consequências do encerramento abrupto (`kill -9`)**

- **Portas em TIME_WAIT:** como o processo é removido da memória sem fechar formalmente suas conexões, o kernel assume o fechamento dos canais abertos. As conexões ficam em `TIME_WAIT`, um período de espera de segurança (60 segundos no Linux) cujo objetivo é evitar que pacotes atrasados da rede interfiram numa nova conexão com a mesma combinação de endereços e portas. Enquanto isso, reiniciar o serviço rapidamente pode falhar com o erro de "porta/endereço em uso" (*Address already in use*), principalmente se o servidor não usar a opção `SO_REUSEADDR`.
- **Conexões órfãs no banco de dados:** as aplicações mantêm conexões abertas com o banco para agilizar consultas. Se o processo morre de forma brusca, ele não envia o comando de desconexão nem finaliza operações pendentes. O servidor de banco pode demorar a perceber que o cliente sumiu e manter a sessão aberta, ocupando memória e segurando recursos, até que o tempo limite de inatividade expire.

**2. Como fazer o graceful shutdown com SIGTERM**

O SIGTERM (enviado pelo `kill` padrão) avisa a aplicação de que ela deve encerrar, permitindo que o próprio código conduza um desligamento controlado. A aplicação Node.js ou Python deve capturar o sinal e executar quatro etapas, nesta ordem:

1. **Bloquear novas requisições:** o servidor HTTP deixa de aceitar novas conexões.
2. **Concluir tarefas em andamento:** aguarda a finalização das requisições que já estavam sendo processadas.
3. **Encerrar recursos externos:** fecha explicitamente as conexões com banco de dados, filas de mensagens e arquivos abertos.
4. **Finalizar o processo:** só depois de liberar tudo, encerra com código de saída limpo (`0`).

Assim, a porta de rede é liberada de forma ordenada e o banco de dados não acumula sessões inativas.

**Exemplo em Node.js:**

```js
const server = app.listen(8080);

process.on('SIGTERM', () => {
  server.close(async () => {   // 1 e 2: para de aceitar e espera as requisições atuais
    await db.end();            // 3: fecha o banco
    process.exit(0);           // 4: saída limpa
  });
});
```

**Exemplo em Python:**

```python
import signal, sys

def encerrar(signum, frame):
    servidor.shutdown()        # 1 e 2: para de aceitar e termina o ciclo atual
    servidor.server_close()    # libera a porta
    conexao_bd.close()         # 3: fecha o banco
    sys.exit(0)                # 4: saída limpa

signal.signal(signal.SIGTERM, encerrar)
```

*Observação aprendida:* se a aplicação não tiver um handler para SIGTERM (como o `python3 -m http.server` usado na Atividade 2), o Python encerra no comportamento padrão do sinal, sem executar nenhuma rotina de limpeza. Ou seja, o `kill` sozinho só é "gracioso" quando o código da aplicação foi escrito para isso.

---

## Conclusão

- `&`, `>` e `2>&1` permitem rodar a API em segundo plano e registrar tudo em log; `$!` guarda o PID para controlar o processo depois.
- SIGTERM permite o encerramento ordenado; SIGKILL deve ser o último recurso.
- Para a prontidão operacional: na RAM, olhar a coluna `available` (e não a `free`); no disco, o `Use%` da raiz (32%); nas portas, `ss -tulpn` ou `lsof -i` para identificar nome e PID de quem escuta.
- Em `top`/`htop`, a coluna **RES** é a que melhor representa a RAM física de um processo.
