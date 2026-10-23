@echo off
rem Roteiro de testes do capitulo 12, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap12.log.
set "LOG=%~dp0test-cap12.log"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "OUT=%~dp0out"
set "JSON=Content-Type: application/json"
set "C=curl -s --max-time 30"
set "EV=http://localhost:9001"
set "CU=http://localhost:9002"
set "TK=http://localhost:9003"
echo ==== testes %date% %time% > "%LOG%"
call "%~dp0lib\ensure-docker.bat" "%LOG%"
taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
docker rm -f eventos-postgres >nul 2>&1
if not exist "%OUT%" mkdir "%OUT%"
pushd "%CAP%"
docker compose up -d --wait >> "%LOG%" 2>&1
popd
start "event-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\event-api\Win64\Debug\EventApi.exe" "%OUT%\event-api.txt""
start "customer-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\customer-api\Win64\Debug\CustomerApi.exe" "%OUT%\customer-api.txt""
start "ticket-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\ticket-api\Win64\Debug\TicketApi.exe" "%OUT%\ticket-api.txt""
timeout /t 5 /nobreak >nul
(
echo ---- 1. preparando event-api e customer-api
%C% -o nul -w "venue %%{http_code} " -X POST %EV%/venues -H "%JSON%" -d "{\"name\":\"Arena Central\",\"address\":\"Av. Principal, 100\",\"city\":\"Belo Horizonte\",\"state\":\"MG\",\"capacity\":1000}"
%C% -o nul -w "evento1 %%{http_code} " -X POST %EV%/events -H "%JSON%" -d "{\"name\":\"Show de Estreia\",\"categoryId\":1,\"venueId\":1,\"startAt\":\"2099-03-10T20:00:00\"}"
%C% -o nul -w "lote1 %%{http_code} " -X POST %EV%/events/1/batches -H "%JSON%" -d "{\"name\":\"Primeiro lote\",\"price\":150,\"quantity\":10,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-03-01T00:00:00\"}"
%C% -o nul -w "publica %%{http_code} " -X POST %EV%/events/1/publish
%C% -o nul -w "evento2 %%{http_code} " -X POST %EV%/events -H "%JSON%" -d "{\"name\":\"Show em Rascunho\",\"categoryId\":1,\"venueId\":1,\"startAt\":\"2099-04-10T20:00:00\"}"
%C% -o nul -w "lote2 %%{http_code} " -X POST %EV%/events/2/batches -H "%JSON%" -d "{\"name\":\"Lote unico\",\"price\":90,\"quantity\":10,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-04-01T00:00:00\"}"
%C% -o nul -w "lote3 %%{http_code} " -X POST %EV%/events/1/batches -H "%JSON%" -d "{\"name\":\"Segundo lote\",\"price\":200,\"quantity\":20,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-03-01T00:00:00\"}"
%C% -o nul -w "cliente %%{http_code}" -X POST %CU%/customers -H "%JSON%" -d "{\"cpf\":\"529.982.247-25\",\"name\":\"Ana Souza\",\"email\":\"ana@exemplo.com\"}"
echo.
echo ---- 2. event-api: GET /batches/1
%C% %EV%/batches/1
echo.
echo ---- 3. ticket-api ainda nao conhece o lote 1
%C% -w " %%{http_code}" %TK%/batches/1
echo.
echo ---- 4. reserva no lote 1 sem PUT manual
%C% -i -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":1,\"quantity\":2}"
echo.
echo ---- 5. estoque local depois da reserva
%C% %TK%/batches/1
echo.
echo ---- 6. participante inexistente
%C% -i -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":999,\"batchId\":1,\"quantity\":1}"
echo.
echo ---- 7. evento em rascunho
%C% -i -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":2,\"quantity\":1}"
echo.
echo ---- 8. lote inexistente na event-api
%C% -i -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":99,\"quantity\":1}"
echo.
echo ---- 9. relatorio de vendas com o nome do evento
%C% %TK%/reports/events/1/sales
echo.
) >> "%LOG%" 2>&1

echo ---- 10. 20 compras simultaneas, 8 ingressos restantes no lote 1 >> "%LOG%"
set "T=%TEMP%\livro-cap12"
if exist "%T%" rd /s /q "%T%"
mkdir "%T%"
for /l %%i in (1,1,20) do start "" /b %C% -o "%T%\body_%%i.txt" -w "%%{http_code} " -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":1,\"quantity\":1}" > "%T%\code_%%i.txt"
timeout /t 15 /nobreak >nul
copy /b "%T%\code_*.txt" "%T%\all.txt" >nul
type "%T%\all.txt" >> "%LOG%"
echo. >> "%LOG%"
%C% %TK%/batches/1 >> "%LOG%" 2>&1
echo. >> "%LOG%"

echo ---- 11. event-api fora do ar >> "%LOG%"
taskkill /im EventApi.exe /f >nul 2>&1
timeout /t 1 /nobreak >nul
(
echo ---- 11a. lote 3, que a ticket-api nunca viu
%C% -i -w "tempo %%{time_total}s" -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":3,\"quantity\":1}"
echo.
echo ---- 11b. lote 1 esgotado, mas conhecido: modo degradado chega ao estoque
%C% -w " tempo %%{time_total}s" -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":1,\"quantity\":1}"
echo.
echo ---- 11c. relatorio sem o nome do evento
%C% %TK%/reports/events/1/sales
echo.
) >> "%LOG%" 2>&1

echo ---- 12. cancelando uma reserva para liberar 1 ingresso e testar o modo degradado >> "%LOG%"
%C% -o nul -w "cancel %%{http_code}" -X POST %TK%/reservations/1/cancel >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -w " tempo %%{time_total}s" -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":1,\"quantity\":1}" >> "%LOG%" 2>&1
echo. >> "%LOG%"

echo ---- 13. customer-api fora do ar >> "%LOG%"
taskkill /im CustomerApi.exe /f >nul 2>&1
timeout /t 1 /nobreak >nul
%C% -w " %%{http_code} tempo %%{time_total}s" -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":1,\"quantity\":1}" >> "%LOG%" 2>&1
echo. >> "%LOG%"

echo ---- 14. event-api inalcancavel: endereco que nao responde, para medir o tempo limite >> "%LOG%"
taskkill /im TicketApi.exe /f >nul 2>&1
start "customer-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\customer-api\Win64\Debug\CustomerApi.exe" "%OUT%\customer-api-2.txt""
set "EVENT_API_URL=http://10.255.255.1:9001"
start "ticket-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\ticket-api\Win64\Debug\TicketApi.exe" "%OUT%\ticket-api-2.txt""
set "EVENT_API_URL="
timeout /t 5 /nobreak >nul
%C% -w " %%{http_code} tempo %%{time_total}s" -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":3,\"quantity\":1}" >> "%LOG%" 2>&1
echo. >> "%LOG%"

taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
timeout /t 1 /nobreak >nul
echo ---- 15. console da ticket-api >> "%LOG%"
type "%OUT%\ticket-api.txt" >> "%LOG%" 2>&1
type "%OUT%\ticket-api-2.txt" >> "%LOG%" 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
