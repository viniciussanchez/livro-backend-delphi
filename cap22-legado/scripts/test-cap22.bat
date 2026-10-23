@echo off
rem Roteiro de testes do capitulo 22, como foi usado na escrita do livro.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap22.log.
set "LOG=%~dp0test-cap22.log"
rem A libpq.dll (capitulo 5) precisa estar no PATH; PGSQL_BIN aponta a pasta dela.
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "OUT=%~dp0out"
set "SQL=%CAP%\legacy\sql"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
set "DEMO=%PS% -File %~dp0lib\legacy-demo.ps1"
set "PGPASSWORD=eventos"
set "PSQL=psql -h 127.0.0.1 -U eventos -v ON_ERROR_STOP=1 -q"
set "SYNCEXE=%CAP%\legacy-sync\Win64\Debug\LegacySync.exe"
echo ==== testes %date% %time% > "%LOG%"
if not exist "%OUT%" mkdir "%OUT%"
del /q "%OUT%\*.txt" >nul 2>&1
call "%~dp0lib\ensure-docker.bat" "%LOG%"
taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
taskkill /im ApiGateway.exe /f >nul 2>&1
taskkill /im LegacySync.exe /f >nul 2>&1
docker rm -f eventos-postgres cap22-postgres >nul 2>&1
docker run -d --name cap22-postgres -e POSTGRES_USER=eventos -e POSTGRES_PASSWORD=eventos -e POSTGRES_DB=eventos -e TZ=America/Sao_Paulo -p 127.0.0.1:5432:5432 postgres:17 -c timezone=America/Sao_Paulo >> "%LOG%" 2>&1
set /a N=0
:waitpg
set /a N+=1
timeout /t 1 /nobreak >nul
pg_isready -h 127.0.0.1 -U eventos >nul 2>&1
if errorlevel 1 if %N% lss 60 goto waitpg
timeout /t 2 /nobreak >nul
%PSQL% -d eventos -c "create database event_db" -c "create database customer_db" -c "create database ticket_db" -c "create database bilheteria" >> "%LOG%" 2>&1

echo ---- 1. o sistema antigo >> "%LOG%"
%PSQL% -d bilheteria -f "%SQL%\01-bilheteria.sql" >> "%LOG%" 2>&1
%PSQL% -d bilheteria -f "%SQL%\02-dados-de-exemplo.sql" >> "%LOG%" 2>&1
%PSQL% -d bilheteria -c "select count(*) as clientes, count(*) filter (where CPF like '%%.%%') as cpf_com_mascara, count(*) filter (where EMAIL is null) as sem_email, count(*) filter (where DT_NASC = '31/02/1985') as data_impossivel from CLIENTE" >> "%LOG%" 2>&1
%PSQL% -d bilheteria -c "select COD_CLI, NOME, CPF, FONE, EMAIL, DT_NASC from CLIENTE where COD_CLI between 1 and 6 order by 1" >> "%LOG%" 2>&1

echo ---- 1b. limpeza da fila com e sem skip locked >> "%LOG%"
docker exec -i cap22-postgres bash -s < "%~dp0lib\deadlock-demo.sh" >> "%LOG%" 2>&1

echo ---- 2. testes de unidade da traducao >> "%LOG%"
"%CAP%\tests\Win64\Debug\EventosTests.exe" --exclude:integracao > "%OUT%\unidade.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
findstr /c:"Tests Found" /c:"Tests Passed" /c:"Tests Failed" /c:"Tests Errored" "%OUT%\unidade.txt" >> "%LOG%"
findstr /c:"TLegacyTranslatorTests" "%OUT%\unidade.txt" >> "%LOG%"

echo ---- 3. servicos no ar >> "%LOG%"
start "event-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\event-api\Win64\Debug\EventApi.exe" "%OUT%\event-api.txt""
start "customer-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\customer-api\Win64\Debug\CustomerApi.exe" "%OUT%\customer-api.txt""
start "ticket-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\ticket-api\Win64\Debug\TicketApi.exe" "%OUT%\ticket-api.txt""
start "api-gateway" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\api-gateway\Win64\Debug\ApiGateway.exe" "%OUT%\api-gateway.txt""
timeout /t 8 /nobreak >nul
echo -- legacy-sync antes do script da fila >> "%LOG%"
"%SYNCEXE%" > "%OUT%\legacy-sync-sem-fila.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
findstr /c:"SYNC_FILA" "%OUT%\legacy-sync-sem-fila.txt" >> "%LOG%"
%PSQL% -d bilheteria -f "%SQL%\03-sincronizacao.sql" >> "%LOG%" 2>&1
start "legacy-sync" /min cmd /c ""%~dp0lib\run-capture.bat" "%SYNCEXE%" "%OUT%\legacy-sync.txt""
timeout /t 4 /nobreak >nul
curl -s -w " [%%{http_code}]" http://127.0.0.1:9004/health >> "%LOG%" 2>&1
echo. >> "%LOG%"

echo ---- 4. carga inicial >> "%LOG%"
%DEMO% -Part fullload >> "%LOG%" 2>&1

echo ---- 5. conferencia >> "%LOG%"
%DEMO% -Part reconcile >> "%LOG%" 2>&1

echo ---- 6. o balcao continua trabalhando >> "%LOG%"
%DEMO% -Part counter >> "%LOG%" 2>&1

echo ---- 7. corrigindo uma pendencia >> "%LOG%"
%DEMO% -Part fix >> "%LOG%" 2>&1

echo ---- 8. customer-api fora do ar >> "%LOG%"
taskkill /im CustomerApi.exe /f >nul 2>&1
%DEMO% -Part outage-insert >> "%LOG%" 2>&1
start "customer-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\customer-api\Win64\Debug\CustomerApi.exe" "%OUT%\customer-api-2.txt""
%DEMO% -Part outage-check >> "%LOG%" 2>&1

echo ---- 9. duas copias e a carga completa de novo >> "%LOG%"
set "PORT=9014"
start "legacy-sync-2" /min cmd /c ""%~dp0lib\run-capture.bat" "%SYNCEXE%" "%OUT%\legacy-sync-2.txt""
set "PORT="
timeout /t 4 /nobreak >nul
%DEMO% -Part again >> "%LOG%" 2>&1
echo -- itens por copia >> "%LOG%"
%PS% -Command "foreach ($p in 9004, 9014) { $m = (Invoke-WebRequest -UseBasicParsing http://127.0.0.1:$p/metrics).Content -split [char]10 | Where-Object { $_ -like 'legacy_sync_items_total*' }; 'porta ' + $p; $m }" >> "%LOG%" 2>&1

echo ---- 10. uma compra para um cliente do sistema antigo >> "%LOG%"
%DEMO% -Part purchase >> "%LOG%" 2>&1

echo ---- 11. metricas do legacy-sync >> "%LOG%"
%DEMO% -Part metrics >> "%LOG%" 2>&1

echo ---- 12. logs >> "%LOG%"
echo -- legacy-sync, avisos e rejeicoes (amostra) >> "%LOG%"
findstr /c:"WARN" "%OUT%\legacy-sync.txt" > "%OUT%\sync-warn.txt"
%PS% -Command "Get-Content '%OUT%\sync-warn.txt' | Select-Object -First 6" >> "%LOG%" 2>&1
%PS% -Command "'linhas WARN no legacy-sync: ' + (Get-Content '%OUT%\sync-warn.txt').Count" >> "%LOG%" 2>&1
echo -- customer-api, uma requisicao vinda da fila >> "%LOG%"
%PS% -Command "Get-Content '%OUT%\customer-api.txt' | Where-Object { $_ -like '*requestId=sync-*' } | Select-Object -First 2" >> "%LOG%" 2>&1

echo ---- 13. encerrando >> "%LOG%"
taskkill /im LegacySync.exe >nul 2>&1
timeout /t 3 /nobreak >nul
taskkill /im LegacySync.exe /f >nul 2>&1
taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
taskkill /im ApiGateway.exe /f >nul 2>&1
docker rm -f cap22-postgres >> "%LOG%" 2>&1
echo ==== fim %time% >> "%LOG%"
