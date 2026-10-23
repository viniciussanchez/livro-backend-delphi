@echo off
rem Roteiro de testes do capitulo 5, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap05.log.
set "LOG=%~dp0test-cap05.log"
set "SRV=%~dp0server-cap05.log"
set "URL=http://localhost:9001"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "EXE=%CAP%\event-api\Win64\Debug\EventApi.exe"
set "JSON=Content-Type: application/json"
echo ==== testes %date% %time% > "%LOG%"
echo. > "%SRV%"
taskkill /im EventApi.exe /f >nul 2>&1
pushd "%CAP%"
docker compose up -d --wait >> "%LOG%" 2>&1
popd
start "event-api" /min cmd /c ""%EXE%" >> "%SRV%" 2>&1"
timeout /t 4 /nobreak >nul
(
echo ---- 1. GET /events vazio
curl -s -i %URL%/events
echo.
echo ---- 2. POST evento 1
curl -s -i -X POST %URL%/events -H "%JSON%" -d "{\"name\":\"Delphi Conference\",\"city\":\"Belo Horizonte\",\"eventDate\":\"2026-11-20\",\"capacity\":300}"
echo.
echo ---- 3. POST evento 2 com acento
curl -s -i -X POST %URL%/events -H "%JSON%" -d "{\"name\":\"Festival de Ver\u00e3o\",\"city\":\"S\u00e3o Paulo\",\"eventDate\":\"2026-12-05\",\"capacity\":5000}"
echo.
echo ---- 4. POST invalido
curl -s -i -X POST %URL%/events -H "%JSON%" -d "{\"name\":\"\",\"city\":\"X\",\"eventDate\":\"2026-12-05\",\"capacity\":5}"
echo.
echo ---- 5. GET filtro cidade
curl -s -i "%URL%/events?city=s%%C3%%A3o%%20paulo"
echo.
echo ---- 6. GET /events/1
curl -s -i %URL%/events/1
echo.
echo ---- 7. GET /events/999
curl -s -i %URL%/events/999
echo.
) >> "%LOG%" 2>&1
echo ---- 8. reiniciando a API >> "%LOG%"
taskkill /im EventApi.exe /f >nul 2>&1
timeout /t 2 /nobreak >nul
start "event-api" /min cmd /c ""%EXE%" >> "%SRV%" 2>&1"
timeout /t 4 /nobreak >nul
(
echo ---- 9. GET /events depois do restart
curl -s -i %URL%/events
echo.
echo ---- 10. 30 POSTs em paralelo
for /l %%i in (1,1,30) do start "" /b curl -s -o nul -X POST %URL%/events -H "%JSON%" -d "{\"name\":\"Evento %%i\",\"city\":\"Carga\",\"eventDate\":\"2026-12-31\",\"capacity\":10}"
timeout /t 5 /nobreak >nul
echo ---- 11. total de eventos em Carga
docker exec eventos-postgres psql -U eventos -d event_db -tAc "select count(*) from event where city = 'Carga'"
echo ---- 12. conexoes da event-api no PostgreSQL
docker exec eventos-postgres psql -U eventos -d event_db -tAc "select count(*) from pg_stat_activity where application_name = 'event-api'"
echo ---- 13. DELETE /events/1
curl -s -i -X DELETE %URL%/events/1
echo.
echo ---- 14. DELETE /events/1 de novo
curl -s -i -X DELETE %URL%/events/1
echo.
echo ---- 15. schema_migration
docker exec eventos-postgres psql -U eventos -d event_db -c "select version, description from schema_migration"
) >> "%LOG%" 2>&1
taskkill /im EventApi.exe /f >nul 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
