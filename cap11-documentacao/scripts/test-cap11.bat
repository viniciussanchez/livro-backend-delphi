@echo off
rem Roteiro de testes do capitulo 11, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap11.log.
set "LOG=%~dp0test-cap11.log"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "OUT=%~dp0out"
set "C=curl -s --max-time 30"
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
echo ---- 1. documentos JSON >> "%LOG%"
%C% -o "%OUT%\event-api.json" -w "event-api json: %%{http_code} %%{content_type} %%{size_download} bytes" http://localhost:9001/swagger/doc/json >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -o "%OUT%\customer-api.json" -w "customer-api json: %%{http_code} %%{content_type} %%{size_download} bytes" http://localhost:9002/swagger/doc/json >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -o "%OUT%\ticket-api.json" -w "ticket-api json: %%{http_code} %%{content_type} %%{size_download} bytes" http://localhost:9003/swagger/doc/json >> "%LOG%" 2>&1
echo. >> "%LOG%"
echo ---- 2. paginas HTML >> "%LOG%"
%C% -o "%OUT%\event-api.html" -w "event-api html: %%{http_code} %%{content_type}" http://localhost:9001/swagger/doc/html >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -o "%OUT%\ticket-api.html" -w "ticket-api html: %%{http_code} %%{content_type}" http://localhost:9003/swagger/doc/html >> "%LOG%" 2>&1
echo. >> "%LOG%"
echo ---- 3. a API continua respondendo >> "%LOG%"
%C% -w " %%{http_code}" http://localhost:9001/categories >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -w " %%{http_code}" http://localhost:9002/customers/999 >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -w " %%{http_code}" "http://localhost:9003/reports/revenue" >> "%LOG%" 2>&1
echo. >> "%LOG%"
taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
