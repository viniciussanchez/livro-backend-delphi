@echo off
rem Roteiro de testes do capitulo 10, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap10.log.
set "LOG=%~dp0test-cap10.log"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "OUT=%TEMP%\livro-cap10"
set "JSON=Content-Type: application/json"
set "C=curl -s -i --max-time 30"
set "EV=http://localhost:9001"
set "CU=http://localhost:9002"
set "TK=http://localhost:9003"
echo ==== testes %date% %time% > "%LOG%"
call "%~dp0lib\ensure-docker.bat" "%LOG%"
taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
docker rm -f eventos-postgres >nul 2>&1
if exist "%OUT%" rd /s /q "%OUT%"
mkdir "%OUT%"
pushd "%CAP%"
docker compose up -d --wait >> "%LOG%" 2>&1
popd
start "event-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\event-api\Win64\Debug\EventApi.exe" "%OUT%\event-api.txt""
start "customer-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\customer-api\Win64\Debug\CustomerApi.exe" "%OUT%\customer-api.txt""
start "ticket-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\ticket-api\Win64\Debug\TicketApi.exe" "%OUT%\ticket-api.txt""
timeout /t 5 /nobreak >nul
(
echo ---- 1. customer: corpo vazio, varios campos invalidos
%C% -X POST %CU%/customers -H "%JSON%" -d "{}"
echo.
echo ---- 2. customer: varios problemas ao mesmo tempo
%C% -X POST %CU%/customers -H "%JSON%" -d "{\"cpf\":\"111.111.111-11\",\"name\":\"Ana\",\"email\":\"ana-sem-arroba\",\"phone\":\"123\",\"birthDate\":\"2099-01-01\"}"
echo.
echo ---- 3. customer: JSON malformado
%C% -X POST %CU%/customers -H "%JSON%" -d "{\"name\": "
echo.
echo ---- 4. customer: sem Content-Type JSON
%C% -X POST %CU%/customers -H "Content-Type: text/plain" -d "nome=Ana"
echo.
echo ---- 5. customer: cadastro valido e duplicado
%C% -o nul -w "%%{http_code}" -X POST %CU%/customers -H "%JSON%" -d "{\"cpf\":\"529.982.247-25\",\"name\":\"Ana Souza\",\"email\":\"ana@exemplo.com\"}"
echo.
%C% -X POST %CU%/customers -H "%JSON%" -d "{\"cpf\":\"529.982.247-25\",\"name\":\"Ana Souza\",\"email\":\"ana@exemplo.com\"}"
echo.
echo ---- 6. customer: inexistente e id invalido
%C% %CU%/customers/999
echo.
%C% %CU%/customers/abc
echo.
echo ---- 7. event: filtros invalidos
%C% "%EV%/events?category=x&from=2026-13-01&status=foo"
echo.
echo ---- 8. event: local vazio
%C% -X POST %EV%/venues -H "%JSON%" -d "{\"state\":\"mg\"}"
echo.
echo ---- 9. event: evento com categoria e local inexistentes
%C% -X POST %EV%/events -H "%JSON%" -d "{\"name\":\"Show\",\"startAt\":\"amanha\",\"categoryId\":999,\"venueId\":999}"
echo.
echo ---- 10. ticket: lote vazio
%C% -X PUT %TK%/batches/10 -H "%JSON%" -d "{}"
echo.
echo ---- 11. ticket: lotes para os testes
%C% -o nul -w "%%{http_code} " -X PUT %TK%/batches/10 -H "%JSON%" -d "{\"eventId\":1,\"price\":100,\"quantity\":2,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-12-01T00:00:00\"}"
%C% -o nul -w "%%{http_code} " -X PUT %TK%/batches/11 -H "%JSON%" -d "{\"eventId\":1,\"price\":100,\"quantity\":5,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-12-01T00:00:00\"}"
%C% -o nul -w "%%{http_code} " -X PUT %TK%/batches/20 -H "%JSON%" -d "{\"eventId\":1,\"price\":100,\"quantity\":5,\"salesStart\":\"2098-01-01T00:00:00\",\"salesEnd\":\"2098-02-01T00:00:00\"}"
%C% -o nul -w "%%{http_code} " -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":10,\"quantity\":2}"
%C% -o nul -w "%%{http_code} " -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":2,\"batchId\":11,\"quantity\":3}"
echo.
echo ---- 12. ticket: esgotado
%C% -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":3,\"batchId\":10,\"quantity\":1}"
echo.
echo ---- 13. ticket: estoque insuficiente
%C% -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":3,\"batchId\":11,\"quantity\":3}"
echo.
echo ---- 14. ticket: vendas fechadas
%C% -X POST %TK%/reservations -H "%JSON%" -d "{\"customerId\":3,\"batchId\":20,\"quantity\":1}"
echo.
echo ---- 15. ticket: reserva invalida
%C% -X POST %TK%/reservations -H "%JSON%" -d "{\"quantity\":9}"
echo.
echo ---- 16. ticket: relatorio sem periodo
%C% %TK%/reports/revenue
echo.
) >> "%LOG%" 2>&1

for /f %%c in ('docker exec eventos-postgres psql -U eventos -d ticket_db -tAc "select code from ticket order by id limit 1"') do set "CODE1=%%c"
(
echo ---- 17. ticket: check-in repetido
%C% -o nul -w "%%{http_code}" -X POST %TK%/tickets/%CODE1%/check-in
echo.
%C% -X POST %TK%/tickets/%CODE1%/check-in
echo.
echo ---- 18. rota inexistente
%C% %TK%/nada
echo.
echo ---- 19. verbo nao registrado
%C% -X DELETE %TK%/batches/10
echo.
echo ---- 20. banco fora do ar
docker stop eventos-postgres
%C% %CU%/customers/1
echo.
) >> "%LOG%" 2>&1
timeout /t 1 /nobreak >nul
echo ---- 21. console da customer-api >> "%LOG%"
taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
timeout /t 1 /nobreak >nul
type "%OUT%\customer-api.txt" >> "%LOG%" 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
