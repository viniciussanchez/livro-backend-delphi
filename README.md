# Back-end Delphi: Microsserviços com Horse, Docker e Kubernetes

Código-fonte do livro *Back-end Delphi: Microsserviços com Horse, Docker e Kubernetes*, de Vinicius Sanchez.

```bash
git clone https://github.com/viniciussanchez/livro-backend-delphi.git
```

Cada pasta corresponde a um capítulo e guarda o projeto
**exatamente como ele fica ao final daquele capítulo**. Assim você pode começar
de qualquer ponto do livro, ou comparar o seu código com o do capítulo.

## Pré-requisitos

- Delphi 13 Florence
- [Boss](https://github.com/HashLoad/boss) (gerenciador de dependências)
- Docker Desktop (a partir do capítulo 2, para o PostgreSQL; do 19 ao 21, com o Kubernetes ativado)
- Delphi Enterprise ou Architect para compilar para Linux (capítulo 17 em diante)

## Como usar uma pasta de capítulo

```bash
cd cap03-primeiros-passos
boss install
```

Depois abra o `.dproj` no Delphi e rode o projeto.

A partir do capítulo 5, cada pasta tem vários serviços (`event-api`, `customer-api`, `ticket-api`)
e uma pasta `shared` com as units comuns. Rode `boss install` dentro da pasta de cada serviço.

A partir do capítulo 11, os projetos já trazem no *search path* as pastas
`modules\gbswagger\Source\Core` e `modules\gbswagger\Source\Horse`, que o Boss não
acrescenta sozinho.

A partir do capítulo 14, cada serviço tem um `.env.example`. Copie para `.env` e ajuste;
o `.env` nunca vai para o Git.

Para os capítulos com banco de dados:

```bash
docker compose up -d --wait
```

O FireDAC precisa da `libpq.dll` (64 bits) no `PATH` ou na pasta do executável.
Veja o capítulo 5 para saber como obtê-la.

A partir do capítulo 17, os projetos também compilam para Linux64 (Release).
No Linux, os serviços precisam dos pacotes `libpq5` e `libcurl4`.

No capítulo 18, compile os quatro serviços para Linux64 em Release, crie o `.env`
a partir do `.env.example` (na raiz de `cap18-docker`) e rode:

```bash
docker compose up -d --build --wait
```

Só o gateway fica exposto, em http://localhost:9000. Para abrir as portas internas
durante o desenvolvimento, acrescente `-f docker-compose.dev.yml`.

Nos capítulos 19 a 21, com o Kubernetes do Docker Desktop ativado, gere as imagens
com a etiqueta indicada em `k8s/kustomization.yaml`, crie o `k8s/.env` a partir do
`k8s/.env.example` e rode:

```bash
kubectl apply -k k8s
```

No capítulo 22, o banco do sistema antigo é criado pelos scripts de `legacy/sql`,
nesta ordem: `01-bilheteria.sql`, `02-dados-de-exemplo.sql` e `03-sincronizacao.sql`
(este último é a única mudança no sistema antigo). O serviço `legacy-sync` sobe na
porta 9004.

## Roteiros de teste

Do capítulo 3 em diante, cada pasta traz `scripts\test-capNN.bat`: o mesmo roteiro usado
para conferir as seções "Testando" do livro. Ele sobe o que for preciso, roda os comandos
e grava as respostas em `scripts\test-capNN.log`, para você comparar com o texto.
Rode no Prompt de Comando (cmd), a partir da pasta do capítulo, depois de compilar os projetos.

## Trocando de capítulo

Cada pasta tem o seu `docker-compose.yml`. Antes de subir o banco de outro capítulo,
pare o do capítulo anterior, na pasta dele:

```bash
docker compose down
```

Sem isso, o Docker recusa o novo contêiner porque o nome `eventos-postgres` (ou a porta 5432)
já está em uso.

## Capítulos

| Pasta | Capítulo |
|---|---|
| `cap02-ambiente` | 2. Preparando o ambiente (PostgreSQL com Docker) |
| `cap03-primeiros-passos` | 3. Primeiros passos com o Horse |
| `cap04-arquitetura` | 4. Arquitetura da plataforma (`event-api` em camadas) |
| `cap05-acesso-a-dados` | 5. Acesso a dados com FireDAC (PostgreSQL, pool, migrations) |
| `cap06-servico-de-eventos` | 6. Serviço de eventos (`event-api` completa) |
| `cap07-servico-de-participantes` | 7. Serviço de participantes (`customer-api`) |
| `cap08-servico-de-ingressos` | 8. Serviço de ingressos (`ticket-api`) |
| `cap09-relatorios` | 9. Relatórios de vendas e ocupação (`ticket-api` + índices) |
| `cap10-validacao-e-erros` | 10. Validação e tratamento de erros (Problem Details nos três serviços) |
| `cap11-documentacao` | 11. Documentação com Swagger (GBSwagger nos três serviços) |
| `cap12-comunicacao` | 12. Comunicação entre serviços (RESTRequest4Delphi, 503 e modo degradado) |
| `cap13-autenticacao` | 13. Autenticação e autorização com JWT (login, papéis, token de serviço) |
| `cap14-configuracao` | 14. Configuração e segredos (variáveis de ambiente, `.env`, validação em produção) |
| `cap15-testes` | 15. Testes automatizados com DUnitX (pasta `tests`) |
| `cap16-gateway` | 16. API Gateway (`api-gateway` na porta 9000, `/health` em todos os serviços) |
| `cap17-linux` | 17. Rodando no Linux (plataforma Linux64, sinais, correções de página de código e de aleatoriedade) |
| `cap18-docker` | 18. Docker (um `Dockerfile` por serviço e `docker-compose.yml` com a plataforma inteira) |
| `cap19-kubernetes` | 19. Conceitos de Kubernetes (`event-api` e PostgreSQL num cluster local; pasta `k8s`) |
| `cap20-plataforma-k8s` | 20. A plataforma inteira no Kubernetes (`kubectl apply -k k8s`; StatefulSet, initContainers, LoadBalancer) |
| `cap21-observabilidade` | 21. Observabilidade (logs JSON com `Platform.Log`, `X-Request-Id` em todos os serviços, `/metrics` e Prometheus no cluster) |
| `cap22-legado` | 22. Migrando um sistema legado aos poucos (banco antigo em `legacy/sql`, serviço `legacy-sync`, importação idempotente na `customer-api`) |

## Dependências utilizadas

- [Horse](https://github.com/HashLoad/horse)
- [Jhonson](https://github.com/HashLoad/jhonson)
- [GBSwagger](https://github.com/gabrielbaltazar/gbswagger) (a partir do capítulo 11)
- [RESTRequest4Delphi](https://github.com/viniciussanchez/RESTRequest4Delphi) (`ticket-api` a partir do capítulo 12, testes e `legacy-sync`)
- [DUnitX](https://github.com/VSoftTechnologies/DUnitX) (capítulo 15; já vem com o Delphi)

## Licença

O código deste repositório é distribuído sob a licença MIT (arquivo `LICENSE`).
O texto do livro não faz parte do repositório e tem todos os direitos reservados.
