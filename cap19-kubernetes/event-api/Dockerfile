# Imagem da event-api (capítulo 18).
# O executável é compilado antes, no Delphi, para Linux64 em Release:
#   msbuild EventApi.dproj /p:Config=Release /p:Platform=Linux64
FROM ubuntu:22.04

# libpq5: cliente do PostgreSQL, carregado pelo FireDAC.
# libcurl4: base do THTTPClient no Linux (o --healthcheck e as chamadas entre serviços).
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libpq5 libcurl4 ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*

# Um usuário sem privilégios: se alguém explorar uma falha no serviço,
# não ganha o root do contêiner.
RUN useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin eventos

WORKDIR /app
COPY --chmod=755 Linux64/Release/EventApi /app/EventApi

USER eventos
# A plataforma trabalha no horário local do evento (capítulo 6).
# Sem isto, o contêiner roda em UTC e Now fica 3 horas adiantado.
ENV TZ=America/Sao_Paulo \
    APP_ENV=production \
    PORT=9001
EXPOSE 9001

HEALTHCHECK --interval=10s --timeout=6s --start-period=15s --retries=3 \
  CMD ["/app/EventApi", "--healthcheck"]

ENTRYPOINT ["/app/EventApi"]
