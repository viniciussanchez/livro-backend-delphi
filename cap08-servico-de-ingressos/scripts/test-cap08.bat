@echo off
rem Roteiro de testes do capitulo 8, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap08.log.
set "LOG=%~dp0test-cap08.log"
set "CODES=%TEMP%\livro-cap08-codes.txt"
set "URL=http://localhost:9003"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "EXE=%CAP%\ticket-api\Win64\Debug\TicketApi.exe"
set "JSON=Content-Type: application/json"
set "C=curl -s --max-time 30"
set "PSQL=docker exec eventos-postgres psql -U eventos -d ticket_db -tAc"
echo ==== testes %date% %time% > "%LOG%"
taskkill /im TicketApi.exe /f >nul 2>&1
docker rm -f eventos-postgres >nul 2>&1
pushd "%CAP%"
docker compose up -d --wait >> "%LOG%" 2>&1
popd
rem espera o PostgreSQL aceitar TCP (o servidor temporario do init so escuta no socket)
for /l %%n in (1,1,30) do docker exec eventos-postgres pg_isready -q -h 127.0.0.1 -U eventos && goto :pgok || timeout /t 1 /nobreak >nul
:pgok
start "ticket-api" /min "%EXE%"
timeout /t 4 /nobreak >nul
(
echo ---- 1. PUT lote 10 a venda, 10 ingressos
%C% -i -X PUT %URL%/batches/10 -H "%JSON%" -d "{\"eventId\":1,\"price\":150,\"quantity\":10,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-12-01T00:00:00\"}"
echo.
echo ---- 2. PUT lote 20 vendas ainda fechadas
%C% -X PUT %URL%/batches/20 -H "%JSON%" -d "{\"eventId\":1,\"price\":200,\"quantity\":100,\"salesStart\":\"2098-11-01T00:00:00\",\"salesEnd\":\"2098-11-30T00:00:00\"}"
echo.
echo ---- 3. PUT lote 30 com 3 ingressos
%C% -X PUT %URL%/batches/30 -H "%JSON%" -d "{\"eventId\":2,\"price\":49.9,\"quantity\":3,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-12-01T00:00:00\"}"
echo.
echo ---- 4. GET lote 10
%C% %URL%/batches/10
echo.
echo ---- 5a. reserva com quantidade 0
%C% -i -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":10,\"quantity\":0}"
echo.
echo ---- 5b. reserva com quantidade 7
%C% -i -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":10,\"quantity\":7}"
echo.
echo ---- 6. reserva em lote com vendas fechadas
%C% -i -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":20,\"quantity\":1}"
echo.
echo ---- 7. reserva em lote inexistente
%C% -i -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":1,\"batchId\":99,\"quantity\":1}"
echo.
echo ---- 8. reserva de 2 no lote 30
%C% -i -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":7,\"batchId\":30,\"quantity\":2}"
echo.
echo ---- 9. mais 2 no lote 30 que so tem 1
%C% -i -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":8,\"batchId\":30,\"quantity\":2}"
echo.
echo ---- 10. GET reserva 1
%C% %URL%/reservations/1
echo.
) >> "%LOG%" 2>&1

echo ---- 11. 40 compras simultaneas de 1 ingresso no lote 10 >> "%LOG%"
set "T=%TEMP%\livro-cap08"
if exist "%T%" rd /s /q "%T%"
mkdir "%T%"
for /l %%i in (1,1,40) do start "" /b %C% -o "%T%\body_%%i.txt" -w "%%{http_code}" -X POST %URL%/reservations -H "%JSON%" -d "{\"customerId\":%%i,\"batchId\":10,\"quantity\":1}" > "%T%\code_%%i.txt"
timeout /t 15 /nobreak >nul
copy /b "%T%\code_*.txt" "%CODES%" >nul
echo. >> "%CODES%"
echo codigos HTTP das 40 respostas: >> "%LOG%"
type "%CODES%" >> "%LOG%"
echo. >> "%LOG%"
echo exemplo de resposta recusada: >> "%LOG%"
for %%f in ("%T%\body_*.txt") do findstr /c:"message" "%%f" >nul && type "%%f" >> "%LOG%" && goto :fim_exemplo
:fim_exemplo
echo. >> "%LOG%"
(
echo ---- 12. GET lote 10 depois da corrida
%C% %URL%/batches/10
echo.
echo ---- 13. banco: vendidos no lote 10 e ingressos emitidos
%PSQL% "select sold from batch_inventory where id = 10"
%PSQL% "select count(*) from ticket t join reservation r on r.id = t.reservation_id where r.batch_id = 10"
) >> "%LOG%" 2>&1

for /f %%c in ('%PSQL% "select code from ticket where reservation_id = 1 order by id limit 1"') do set "CODE1=%%c"
for /f %%c in ('%PSQL% "select code from ticket where reservation_id = 1 order by id desc limit 1"') do set "CODE2=%%c"
for /f %%c in ('%PSQL% "select min(id) from reservation where batch_id = 10"') do set "RES10=%%c"
for /f %%c in ('%PSQL% "select code from ticket where reservation_id = %RES10%"') do set "CODE10=%%c"
echo codigos: %CODE1% %CODE2% reserva do lote 10: %RES10% codigo: %CODE10% >> "%LOG%"

(
echo ---- 14a. check-in
%C% -i -X POST %URL%/tickets/%CODE1%/check-in
echo.
echo ---- 14b. check-in de novo
%C% -i -X POST %URL%/tickets/%CODE1%/check-in
echo.
echo ---- 14c. GET ingresso
%C% %URL%/tickets/%CODE1%
echo.
echo ---- 14d. GET segundo ingresso
%C% %URL%/tickets/%CODE2%
echo.
echo ---- 15. cancelar reserva 1 com ingresso usado
%C% -i -X POST %URL%/reservations/1/cancel
echo.
echo ---- 16a. cancelar reserva do lote 10
%C% -i -X POST %URL%/reservations/%RES10%/cancel
echo.
echo ---- 16b. cancelar de novo
%C% -i -X POST %URL%/reservations/%RES10%/cancel
echo.
echo ---- 16c. GET lote 10 depois do cancelamento
%C% %URL%/batches/10
echo.
echo ---- 16d. check-in de ingresso cancelado
%C% -i -X POST %URL%/tickets/%CODE10%/check-in
echo.
echo ---- 17. reduzir lote 10 abaixo do vendido
%C% -i -X PUT %URL%/batches/10 -H "%JSON%" -d "{\"eventId\":1,\"price\":150,\"quantity\":5,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-12-01T00:00:00\"}"
echo.
echo ---- 18. check-in de codigo inexistente
%C% -i -X POST %URL%/tickets/ZZZZZZZZZZ/check-in
echo.
echo ---- 19. dois check-ins simultaneos do mesmo ingresso
) >> "%LOG%" 2>&1
start "" /b %C% -o nul -w "%%{http_code} " -X POST %URL%/tickets/%CODE2%/check-in > "%T%\checkin_1.txt"
start "" /b %C% -o nul -w "%%{http_code} " -X POST %URL%/tickets/%CODE2%/check-in > "%T%\checkin_2.txt"
timeout /t 4 /nobreak >nul
type "%T%\checkin_1.txt" "%T%\checkin_2.txt" >> "%LOG%" 2>nul
echo. >> "%LOG%"
taskkill /im TicketApi.exe /f >nul 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
