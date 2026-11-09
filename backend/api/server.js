const http = require('http');

const port = process.env.PORT || 8080;
const host = '0.0.0.0';

const server = http.createServer((req, res) => {
  if (req.url === '/api/status' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'online',
      service: 'app-producao',
      port: port,
      timestamp: new Date().toISOString()
    }));
  } else if (req.url === '/api/produtos') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify([
      { id: 1, nome: 'Servidor VPS', preco: 150 },
      { id: 2, nome: 'Certificado SSL Wildcard', preco: 90 },
      { id: 3, nome: 'Backup Automatizado S3', preco: 45 }
    ]));
  } else {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Endpoint nao encontrado' }));
  }
});

server.listen(port, host, () => {
  console.log(`[app-producao] Servidor ouvindo na porta ${port}`);
});
