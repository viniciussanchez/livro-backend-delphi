# Imagem da api-gateway (capítulo 18).
# O executável é compilado antes, no Delphi, para Linux64 em Release:
#   msbuild ApiGateway.dproj /p:Config=Release /p:Platform=Linux64
FROM ubuntu:22.04

# O gateway não acessa banco: não precisa do libpq5.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libcurl4 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Um usuário sem privilégios: se alguém explorar uma falha no serviço,
# não ganha o root do contêiner.
RUN useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin eventos

WORKDIR /app
COPY --chmod=755 Linux64/Release/ApiGateway /app/ApiGateway

USER eventos
ENV APP_ENV=production \
    PORT=9000
EXPOSE 9000

HEALTHCHECK --interval=10s --timeout=6s --start-period=15s --retries=3 \
  CMD ["/app/ApiGateway", "--healthcheck"]

ENTRYPOINT ["/app/ApiGateway"]
