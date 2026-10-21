#!/bin/sh
# Envia SIGTERM a um serviço e mede quanto tempo ele leva para sair.
# Uso: stop-one.sh <executável>
pid=$(pgrep -o -x "$1") || { echo "$1 não estava rodando"; exit 1; }
start=$(date +%s%N)
kill -TERM "$pid"
# Um processo que já saiu, mas ainda não foi recolhido pelo pai, aparece
# como "zumbi" (estado Z): para nós, ele já terminou.
while [ -e "/proc/$pid" ] && ! grep -q '^State:.*Z' "/proc/$pid/status" 2>/dev/null; do
  sleep 0.05
done
end=$(date +%s%N)
echo "$1 saiu em $(( (end - start) / 1000000 )) ms"
