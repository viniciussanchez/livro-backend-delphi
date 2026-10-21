# Imagem da ticket-api (capítulo 18).
# O executável é compilado antes, no Delphi, para Linux64 em Release:
#   msbuild TicketApi.dproj /p:Config=Release /p:Platform=Linux64
FROM ubuntu:22.04

# libpq5: cliente do PostgreSQL, carregado pelo FireDAC.
# libcurl4: base do THTTPClient no Linux (o --healthcheck e as chamadas entre serviços).
RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq5 libcurl4 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Um usuário sem privilégios: se alguém explorar uma falha no serviço,
# não ganha o root do contêiner.
RUN useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin eventos

WORKDIR /app
COPY --chmod=755 Linux64/Release/TicketApi /app/TicketApi

USER eventos
ENV APP_ENV=production \
    PORT=9003
EXPOSE 9003

HEALTHCHECK --interval=10s --timeout=6s --start-period=15s --retries=3 \
  CMD ["/app/TicketApi", "--healthcheck"]

ENTRYPOINT ["/app/TicketApi"]
