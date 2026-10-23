@echo off
rem Roteiro de testes do capitulo 15, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap15.log.
set "LOG=%~dp0test-cap15.log"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "OUT=%~dp0out"
set "TESTS=%CAP%\tests\Win64\Debug\EventosTests.exe"
echo ==== testes %date% %time% > "%LOG%"
if not exist "%OUT%" mkdir "%OUT%"
taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1

echo ---- 1. testes rapidos, sem banco e sem rede >> "%LOG%"
echo inicio %time% >> "%LOG%"
"%TESTS%" --exclude:integracao --xml:"%OUT%\unidade.xml" > "%OUT%\unidade.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
echo fim %time% >> "%LOG%"
type "%OUT%\unidade.txt" >> "%LOG%"

echo ---- 2. testes de integracao, com tudo no ar >> "%LOG%"
call "%~dp0lib\ensure-docker.bat" "%LOG%"
docker rm -f eventos-postgres >nul 2>&1
pushd "%CAP%"
docker compose up -d --wait >> "%LOG%" 2>&1
popd
start "event-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\event-api\Win64\Debug\EventApi.exe" "%OUT%\event-api.txt""
start "customer-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\customer-api\Win64\Debug\CustomerApi.exe" "%OUT%\customer-api.txt""
start "ticket-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CAP%\ticket-api\Win64\Debug\TicketApi.exe" "%OUT%\ticket-api.txt""
timeout /t 7 /nobreak >nul
echo inicio %time% >> "%LOG%"
"%TESTS%" --include:integracao --xml:"%OUT%\integracao.xml" > "%OUT%\integracao.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
echo fim %time% >> "%LOG%"
type "%OUT%\integracao.txt" >> "%LOG%"

echo ---- 3. de novo, para provar que os testes podem ser repetidos >> "%LOG%"
"%TESTS%" --include:integracao > "%OUT%\integracao-2.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"

taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
