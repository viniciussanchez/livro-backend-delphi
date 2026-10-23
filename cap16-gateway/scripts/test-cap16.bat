@echo off
rem Roteiro de testes do capitulo 16, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap16.log.
set "LOG=%~dp0test-cap16.log"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "OUT=%~dp0out"
set "DEMO=powershell -NoProfile -ExecutionPolicy Bypass -File %~dp0lib\gateway-demo.ps1"
set "C=curl -s --max-time 30"
set "GWEXE=%CAP%\api-gateway\Win64\Debug\ApiGateway.exe"
set "TESTS=%CAP%\tests\Win64\Debug\EventosTests.exe"
echo ==== testes %date% %time% > "%LOG%"
if not exist "%OUT%" mkdir "%OUT%"
call "%~dp0lib\ensure-docker.bat" "%LOG%"
taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
taskkill /im ApiGateway.exe /f >nul 2>&1
docker rm -f eventos-postgres >nul 2>&1
pushd "%CAP%"
docker compose up -d --wait >> "%LOG%" 2>&1
popd
start "event-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\event-api\Win64\Debug\EventApi.exe" "%OUT%\event-api.txt""
start "customer-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\customer-api\Win64\Debug\CustomerApi.exe" "%OUT%\customer-api.txt""
start "ticket-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\ticket-api\Win64\Debug\TicketApi.exe" "%OUT%\ticket-api.txt""
start "api-gateway" /min cmd /c ""%~dp0lib\run-capture.bat" "%GWEXE%" "%OUT%\api-gateway.txt""
timeout /t 7 /nobreak >nul

echo ---- 1. /health de cada servico, direto >> "%LOG%"
%C% -w " [%%{http_code}]" http://127.0.0.1:9001/health >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -w " [%%{http_code}]" http://127.0.0.1:9002/health >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -w " [%%{http_code}]" http://127.0.0.1:9003/health >> "%LOG%" 2>&1
echo. >> "%LOG%"

echo ---- 2. roteiro pelo gateway >> "%LOG%"
%DEMO% -Part main >> "%LOG%" 2>&1

echo ---- 3. testes automatizados do capitulo 15, direto nos servicos >> "%LOG%"
"%TESTS%" --exclude:integracao > "%OUT%\unidade.txt" 2>&1
echo unidade, codigo de saida: %ERRORLEVEL% >> "%LOG%"
"%TESTS%" --include:integracao > "%OUT%\integracao.txt" 2>&1
echo integracao, codigo de saida: %ERRORLEVEL% >> "%LOG%"
findstr /c:"Tests Found" /c:"Tests Passed" /c:"Tests Failed" /c:"Tests Errored" "%OUT%\unidade.txt" "%OUT%\integracao.txt" >> "%LOG%"

echo ---- 4. ticket-api fora do ar >> "%LOG%"
taskkill /im TicketApi.exe /f >nul 2>&1
timeout /t 1 /nobreak >nul
%DEMO% -Part degraded >> "%LOG%" 2>&1

echo ---- 5. servico que aceita a conexao e nunca responde >> "%LOG%"
start "silencioso" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0lib\silent-server.ps1" -Port 9099 -Seconds 40
set "PORT=9010"
set "TICKET_API_URL=http://127.0.0.1:9099"
set "UPSTREAM_TIMEOUT_MS=3000"
start "gateway-2" /min cmd /c ""%~dp0lib\run-capture.bat" "%GWEXE%" "%OUT%\api-gateway-2.txt""
set "PORT="
set "TICKET_API_URL="
set "UPSTREAM_TIMEOUT_MS="
timeout /t 4 /nobreak >nul
%DEMO% -Part timeout -Gw http://127.0.0.1:9010 >> "%LOG%" 2>&1

echo ---- 6. gateway em producao sem CORS_ORIGINS >> "%LOG%"
set "APP_ENV=production"
set "PORT=9011"
"%GWEXE%" > "%OUT%\gateway-prod.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
set "APP_ENV="
set "PORT="
type "%OUT%\gateway-prod.txt" >> "%LOG%"

taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im ApiGateway.exe /f >nul 2>&1
timeout /t 1 /nobreak >nul
echo ---- 7. console do gateway >> "%LOG%"
type "%OUT%\api-gateway.txt" >> "%LOG%" 2>&1
echo ---- 8. console do gateway 2 >> "%LOG%"
type "%OUT%\api-gateway-2.txt" >> "%LOG%" 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
