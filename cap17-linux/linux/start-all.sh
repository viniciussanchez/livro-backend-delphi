#!/bin/sh
# Sobe os quatro serviços em segundo plano, cada um com o seu log.
# Os executáveis ficam em /opt/eventos/<serviço>/.
mkdir -p /var/log/eventos
for item in event-api:EventApi customer-api:CustomerApi ticket-api:TicketApi api-gateway:ApiGateway; do
  dir=${item%%:*}
  exe=${item##*:}
  cd "/opt/eventos/$dir" || exit 1
  nohup "./$exe" > "/var/log/eventos/$dir.log" 2>&1 &
  echo "$dir iniciado (pid $!)"
done
