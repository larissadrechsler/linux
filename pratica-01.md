Qual é a diferença entre a saída de um comando ls comum e o comando ls -la? Que tipo de arquivos a flag -a tornou visíveis?

Comando ls lista as pastas e arquivos visíveis do diretório de forma resumida
Comando ls -la lista os arquivos de forma detalhada e torna visivel todos os arquivos e diretórios, incluindo arquivos ocultos como .env e .git

O que o comando ln -s realizou? Por que a criação de links simbólicos para apontar para a versão ativa de uma aplicação (current-api) é uma prática padrão na indústria para atualizações e deploys atômicos (zero downtime)?

O comando ln-s cria um link simbolico, como se fosse um atalho do windows que direciona pra pasta real
É utilizado para projetos maiores para facilitar caso haja uma atualização de sistema, dessa forma é só ajustar o atalho e tudo que utilizava aquele caminho, se ajustará ao novo atalho

Anote no seu relatório a lista exata de comandos que você utilizou para cada uma das 3 etapas acima, acompanhada de uma breve explicação do seu raciocínio.

1. find . -name "*.tmp"
find . -name "*tmp" -exec rm -f {} +

2. cp config/env.template backend/.env
ls -la backend/.env

3. nano .gitignore
ctrl o para salvar
enter para confirmar o nome do documento
ctrl x para sair do editor nano

git status para validar se deletou o que foi adicionado no gitignore

Consulte a documentação oficial ou a man page do utilitário find (man find) e responda no arquivo pratica-01.md:

Como você estruturaria um comando find para listar apenas arquivos modificados nos últimos 7 dias dentro do diretório logs/?

Para listar apenas arquivos (excluindo diretórios) modificados nos últimos 7 dias (menos de 7 dias atrás) dentro do diretório logs/, o comando é:

find logs/ -type f -mtime -7

    
Qual a diferença técnica essencial entre os parâmetros -mtime -7 e -mtime +7?

-mtime -7 (Menos de 7 dias):
Filtra arquivos cuja última modificação ocorreu há menos de 7 dias (ou seja, de 0 a 6 dias atrás, até o momento atual).

-mtime +7 (Mais de 7 dias):
Filtra arquivos cuja última modificação ocorreu há mais de 7 dias (ou seja, há 8 dias ou mais).

Como adicionar a flag -size para filtrar apenas arquivos com mais de 10 megabytes?

Para combinar a busca por arquivos modificados nos últimos 7 dias com o filtro de tamanho maior que 10 megabytes, adiciona-se o parâmetro -size +10M:

find logs/ -type f -mtime -7 -size +10M

Analise a explicação e faça um teste prático no terminal executando file backend/api/server.js e stat backend/api/server.js.

file: Identifica o conteúdo real/tipo lógico de um arquivo (ex: script Node.js, texto ASCII, imagem PNG), independente da extensão que ele tenha no nome. Ele faz isso lendo os "magic numbers" (bytes iniciais do arquivo).

stat: Exibe metadados detalhados de sistema sobre o arquivo (ex: tamanho exato em bytes, permissões de acesso, inode, UID/GID, e datas exatas de acesso, modificação e alteração de status).

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

