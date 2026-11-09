# Prática: Infraestrutura e Operação de Servidor Web Linux

Repositório da prática contínua e incremental da disciplina **Linux para Desenvolvedores Web**.

## 📁 Estrutura de Entrega das Práticas

Cada etapa da prática possui seu arquivo de respostas e reflexões dedicado:

- [pratica-01.md](pratica-01.md) — **Etapa 1:** Navegação, Sistema de Arquivos, Links e Limpeza
- [pratica-02.md](pratica-02.md) — **Etapa 2:** Permissões, Edição no Terminal e Pipeline Forense de Logs
- [pratica-03.md](pratica-03.md) — **Etapa 3:** Processos em Background, Gestão de PIDs e Diagnóstico de Recursos
- [pratica-04.md](pratica-04.md) — **Etapa 4:** Conectividade de Rede, Aliases/Shell e Chaves SSH
- [pratica-05.md](pratica-05.md) — *(Opcional)* **Desafio 1:** Scripts Bash, Cron e Systemd
- [pratica-06.md](pratica-06.md) — *(Opcional)* **Desafio 2:** Firewall UFW e Harness de Execução para IA

---

## 🚀 Como Executar o Servidor Web

Com o ambiente pronto e variáveis configuradas:
```bash
# Iniciar a API em segundo plano na porta configurada:
python3 -m http.server 8080 --directory backend
# Ou com Node.js:
node backend/api/server.js
```
