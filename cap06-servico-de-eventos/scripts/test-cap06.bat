@echo off
rem Roteiro de testes do capitulo 6, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap06.log.
set "LOG=%~dp0test-cap06.log"
set "URL=http://localhost:9001"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "EXE=%CAP%\event-api\Win64\Debug\EventApi.exe"
set "JSON=Content-Type: application/json"
echo ==== testes %date% %time% > "%LOG%"
taskkill /im EventApi.exe /f >nul 2>&1
pushd "%CAP%"
docker compose up -d --wait >> "%LOG%" 2>&1
popd
start "event-api" /min "%EXE%"
timeout /t 4 /nobreak >nul
(
echo ---- 1. GET /categories
curl -s %URL%/categories
echo.
echo ---- 2a. POST categoria duplicada
curl -s -i -X POST %URL%/categories -H "%JSON%" -d "{\"name\":\"show\"}"
echo.
echo ---- 2b. POST categoria nova
curl -s -i -X POST %URL%/categories -H "%JSON%" -d "{\"name\":\"Stand-up\"}"
echo.
echo ---- 3a. POST local UF invalida
curl -s -i -X POST %URL%/venues -H "%JSON%" -d "{\"name\":\"Teatro\",\"address\":\"Rua A, 1\",\"city\":\"Belo Horizonte\",\"state\":\"Minas\",\"capacity\":500}"
echo.
echo ---- 3b. POST local valido
curl -s -i -X POST %URL%/venues -H "%JSON%" -d "{\"name\":\"Pal\u00e1cio das Artes\",\"address\":\"Av. Afonso Pena, 1537\",\"city\":\"Belo Horizonte\",\"state\":\"mg\",\"capacity\":500}"
echo.
echo ---- 4. GET /venues?city=belo horizonte
curl -s "%URL%/venues?city=belo%%20horizonte"
echo.
echo ---- 5a. POST evento categoria inexistente
curl -s -i -X POST %URL%/events -H "%JSON%" -d "{\"name\":\"Delphi Conference\",\"categoryId\":99,\"venueId\":1,\"startAt\":\"2099-12-10T19:00:00\"}"
echo.
echo ---- 5b. POST evento no passado
curl -s -i -X POST %URL%/events -H "%JSON%" -d "{\"name\":\"Delphi Conference\",\"categoryId\":2,\"venueId\":1,\"startAt\":\"2025-12-10T19:00:00\"}"
echo.
echo ---- 5c. POST evento valido
curl -s -i -X POST %URL%/events -H "%JSON%" -d "{\"name\":\"Delphi Conference\",\"description\":\"Um dia inteiro de Delphi\",\"categoryId\":2,\"venueId\":1,\"startAt\":\"2099-12-10T19:00:00\"}"
echo.
echo ---- 6. GET /events padrao publicados
curl -s %URL%/events
echo.
echo ---- 7. GET /events?status=draft
curl -s "%URL%/events?status=draft"
echo.
echo ---- 8. publicar sem lotes
curl -s -i -X POST %URL%/events/1/publish
echo.
echo ---- 9a. lote terminando depois do evento
curl -s -i -X POST %URL%/events/1/batches -H "%JSON%" -d "{\"name\":\"1o lote\",\"price\":150.5,\"quantity\":400,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-12-20T00:00:00\"}"
echo.
echo ---- 9b. lote valido 400
curl -s -i -X POST %URL%/events/1/batches -H "%JSON%" -d "{\"name\":\"1o lote\",\"price\":150.5,\"quantity\":400,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-11-15T23:59:59\"}"
echo.
echo ---- 9c. lote estourando capacidade
curl -s -i -X POST %URL%/events/1/batches -H "%JSON%" -d "{\"name\":\"2o lote\",\"price\":200,\"quantity\":200,\"salesStart\":\"2099-11-16T00:00:00\",\"salesEnd\":\"2099-12-09T23:59:59\"}"
echo.
echo ---- 9d. lote valido 100
curl -s -i -X POST %URL%/events/1/batches -H "%JSON%" -d "{\"name\":\"2o lote\",\"price\":200,\"quantity\":100,\"salesStart\":\"2099-11-16T00:00:00\",\"salesEnd\":\"2099-12-09T23:59:59\"}"
echo.
echo ---- 10a. publicar
curl -s -i -X POST %URL%/events/1/publish
echo.
echo ---- 10b. publicar de novo
curl -s -i -X POST %URL%/events/1/publish
echo.
echo ---- 11. GET /events/1 detalhe
curl -s %URL%/events/1
echo.
echo ---- 12. GET filtros combinados
curl -s "%URL%/events?city=belo%%20horizonte&category=2&from=2099-12-01&to=2099-12-10"
echo.
echo ---- 13. GET from 2027
curl -s "%URL%/events?from=2100-01-01"
echo.
echo ---- 14. GET status invalido
curl -s -i "%URL%/events?status=xyz"
echo.
echo ---- 15a. GET /events/99
curl -s -i %URL%/events/99
echo.
echo ---- 15b. GET /events/99/batches
curl -s -i %URL%/events/99/batches
echo.
echo ---- 15c. GET /events/1/batches
curl -s %URL%/events/1/batches
echo.
echo ---- 16. migracoes
docker exec eventos-postgres psql -U eventos -d event_db -c "select version, description from schema_migration order by version"
) >> "%LOG%" 2>&1
taskkill /im EventApi.exe /f >nul 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
