#!/usr/bin/env bash
# Execution Harness com limites de tempo e saida controlada
TEMPO_MAXIMO="3s"
COMANDO="$*"

if [ -z "$COMANDO" ]; then
    echo "Uso: $0 <comando>"
    exit 1
fi

echo "[HARNESS] Executando sob limite de $TEMPO_MAXIMO: $COMANDO"
timeout "$TEMPO_MAXIMO" bash -c "$COMANDO"
CODIGO_RETORNO=$?

if [ $CODIGO_RETORNO -eq 0 ]; then
    echo "[HARNESS] Sucesso (Exit Code: 0)"
elif [ $CODIGO_RETORNO -eq 124 ]; then
    echo "[HARNESS] Alerta: Processo interrompido por timeout ($TEMPO_MAXIMO excedido)"
else
    echo "[HARNESS] Falha detectada (Exit Code: $CODIGO_RETORNO)"
fi
exit $CODIGO_RETORNO
