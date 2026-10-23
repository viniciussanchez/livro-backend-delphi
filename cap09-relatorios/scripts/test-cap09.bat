@echo off
rem Roteiro de testes do capitulo 9, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap09.log.
set "LOG=%~dp0test-cap09.log"
set "URL=http://localhost:9003"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "EXE=%CAP%\ticket-api\Win64\Debug\TicketApi.exe"
set "JSON=Content-Type: application/json"
set "C=curl -s --max-time 60"
set "PSQL=docker exec eventos-postgres psql -U eventos -d ticket_db -tAc"
set "PSQLF=docker exec -i eventos-postgres psql -U eventos -d ticket_db"
echo ==== testes %date% %time% > "%LOG%"
call "%~dp0lib\ensure-docker.bat" "%LOG%"
taskkill /im TicketApi.exe /f >nul 2>&1
docker rm -f eventos-postgres >nul 2>&1
pushd "%CAP%"
docker compose up -d --wait >> "%LOG%" 2>&1
popd
start "ticket-api" /min "%EXE%"
timeout /t 4 /nobreak >nul
(
echo ---- 0. migracoes aplicadas
%PSQL% "select version, description from schema_migration order by version"
echo ---- 1. lotes
%C% -o nul -w "%%{http_code} " -X PUT %URL%/batches/10 -H "%JSON%" -d "{\"eventId\":1,\"price\":150,\"quantity\":100,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-12-01T00:00:00\"}"
%C% -o nul -w "%%{http_code} " -X PUT %URL%/batches/11 -H "%JSON%" -d "{\"eventId\":1,\"price\":220,\"quantity\":50,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-12-01T00:00:00\"}"
%C% -o nul -w "%%{http_code} " -X PUT %URL%/batches/30 -H "%JSON%" -d "{\"eventId\":2,\"price\":80,\"quantity\":20,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-12-01T00:00:00\"}"
echo.
echo ---- 2. reservas
%C% -o nul -w "%%{http_code} " -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":10,\"quantity\":2}"
%C% -o nul -w "%%{http_code} " -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":2,\"batchId\":10,\"quantity\":3}"
%C% -o nul -w "%%{http_code} " -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":3,\"batchId\":11,\"quantity\":1}"
%C% -o nul -w "%%{http_code} " -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":4,\"batchId\":11,\"quantity\":4}"
%C% -o nul -w "%%{http_code} " -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":5,\"batchId\":30,\"quantity\":2}"
echo.
echo ---- 3. cancelar reserva 2
%C% -o nul -w "%%{http_code} " -X POST %URL%/reservations/2/cancel
echo.
) >> "%LOG%" 2>&1

for /f %%c in ('%PSQL% "select code from ticket where reservation_id = 1 order by id limit 1"') do set "CODE1=%%c"
for /f %%c in ('%PSQL% "select code from ticket where reservation_id = 1 order by id desc limit 1"') do set "CODE2=%%c"
for /f %%c in ('%PSQL% "select code from ticket where reservation_id = 3 order by id limit 1"') do set "CODE3=%%c"

(
echo ---- 4. tres check-ins
%C% -o nul -w "%%{http_code} " -X POST %URL%/tickets/%CODE1%/check-in
%C% -o nul -w "%%{http_code} " -X POST %URL%/tickets/%CODE2%/check-in
%C% -o nul -w "%%{http_code} " -X POST %URL%/tickets/%CODE3%/check-in
echo.
echo ---- 5. vendas do evento 1
%C% %URL%/reports/events/1/sales
echo.
echo ---- 6. vendas do evento 2
%C% %URL%/reports/events/2/sales
echo.
echo ---- 7. comparecimento do evento 1
%C% %URL%/reports/events/1/attendance
echo.
echo ---- 8. vendas de evento sem lotes
%C% -i %URL%/reports/events/99/sales
echo.
echo ---- 9. comparecimento de evento sem lotes
%C% -i %URL%/reports/events/99/attendance
echo.
echo ---- 10. faturamento de outubro por dia
%C% "%URL%/reports/revenue?from=2020-01-01&to=2099-12-31&groupBy=month"
echo.
echo ---- 11. faturamento de 2026 por mes so do evento 1
%C% "%URL%/reports/revenue?from=2020-01-01&to=2099-12-31&groupBy=month&eventId=1"
echo.
echo ---- 12. groupBy invalido
%C% -i "%URL%/reports/revenue?from=2026-10-01&to=2026-10-31&groupBy=week"
echo.
echo ---- 13. sem a data final
%C% -i "%URL%/reports/revenue?from=2026-10-01"
echo.
echo ---- 14. data inicial depois da final
%C% -i "%URL%/reports/revenue?from=2026-10-31&to=2026-10-01"
echo.
echo ---- 15. por dia em periodo longo demais
%C% -i "%URL%/reports/revenue?from=2025-01-01&to=2026-10-31&groupBy=day"
echo.
echo ---- 16. eventId invalido
%C% -i "%URL%/reports/revenue?from=2026-10-01&to=2026-10-31&eventId=abc"
echo.
echo ---- 17. evento com id invalido
%C% -i %URL%/reports/events/abc/sales
echo.
) >> "%LOG%" 2>&1

echo ---- 18. massa de dados >> "%LOG%"
%PSQLF% < "%~dp0sql\cap09-volume.sql" >> "%LOG%" 2>&1

echo ---- 19. tempos dos endpoints com volume >> "%LOG%"
%C% -o nul -w "faturamento 2025 por mes: %%{http_code} %%{time_total}s" "%URL%/reports/revenue?from=2025-01-01&to=2025-12-31&groupBy=month" >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -o nul -w "faturamento marco 2025 por dia: %%{http_code} %%{time_total}s" "%URL%/reports/revenue?from=2025-03-01&to=2025-03-31&groupBy=day" >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -o nul -w "vendas do evento 3: %%{http_code} %%{time_total}s" %URL%/reports/events/3/sales >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% "%URL%/reports/revenue?from=2025-01-01&to=2025-12-31&groupBy=month&eventId=3" >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% %URL%/reports/events/3/sales >> "%LOG%" 2>&1
echo. >> "%LOG%"

echo ---- 20. planos de execucao >> "%LOG%"
%PSQLF% < "%~dp0sql\cap09-explain.sql" >> "%LOG%" 2>&1

taskkill /im TicketApi.exe /f >nul 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
