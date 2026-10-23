@echo off
rem Roteiro de testes do capitulo 14, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap14.log.
set "LOG=%~dp0test-cap14.log"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "OUT=%~dp0out"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass -File %~dp0lib\jwt.ps1"
set "C=curl -s --max-time 30"
set "EVEXE=%CAP%\event-api\Win64\Debug\EventApi.exe"
set "CUEXE=%CAP%\customer-api\Win64\Debug\CustomerApi.exe"
set "TKEXE=%CAP%\ticket-api\Win64\Debug\TicketApi.exe"
set "STRONG=uma-chave-de-producao-com-mais-de-32-caracteres"
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

echo ---- 1. event-api sem configuracao nenhuma: valores padrao >> "%LOG%"
start "event-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%EVEXE%" "%OUT%\event-api.txt""

echo ---- 2. customer-api com .env e uma variavel de ambiente por cima >> "%LOG%"
> "%CAP%\customer-api\Win64\Debug\.env" echo # arquivo de teste do capitulo 14
>> "%CAP%\customer-api\Win64\Debug\.env" echo ADMIN_EMAIL=chefe@eventos.local
>> "%CAP%\customer-api\Win64\Debug\.env" echo ADMIN_PASSWORD="senha do chefe 123"
>> "%CAP%\customer-api\Win64\Debug\.env" echo PORT=9202
set "PORT=9302"
start "customer-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%CUEXE%" "%OUT%\customer-api.txt""
set "PORT="
set "CUSTOMER_API_URL=http://127.0.0.1:9302"
start "ticket-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%TKEXE%" "%OUT%\ticket-api.txt""
set "CUSTOMER_API_URL="
timeout /t 7 /nobreak >nul
%C% -o nul -w "porta 9202: %%{http_code} " http://127.0.0.1:9202/swagger/doc/json >> "%LOG%" 2>&1
%C% -o nul -w "porta 9302: %%{http_code}" http://127.0.0.1:9302/swagger/doc/json >> "%LOG%" 2>&1
echo. >> "%LOG%"
for /f "usebackq delims=" %%t in (`%PS% -Action login -Url http://127.0.0.1:9302 -Email chefe@eventos.local -Password "senha do chefe 123"`) do set "CHEFE=%%t"
for /f "usebackq delims=" %%t in (`%PS% -Action login -Url http://127.0.0.1:9302 -Email admin@eventos.local -Password admin12345`) do set "ADMIN=%%t"
echo login do chefe: %CHEFE:~0,20%... login do admin padrao: %ADMIN% >> "%LOG%"
%C% -o nul -w "relatorio na ticket-api com o token do chefe: %%{http_code}" "http://127.0.0.1:9003/reports/revenue?from=2026-10-01&to=2026-10-31" -H "Authorization: Bearer %CHEFE%" >> "%LOG%" 2>&1
echo. >> "%LOG%"
taskkill /im TicketApi.exe /f >nul 2>&1
timeout /t 1 /nobreak >nul

echo ---- 3. producao sem nada configurado >> "%LOG%"
set "APP_ENV=production"
"%TKEXE%" > "%OUT%\prod-1.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
type "%OUT%\prod-1.txt" >> "%LOG%"

echo ---- 4. producao com chave curta >> "%LOG%"
set "DB_PASSWORD=eventos"
set "JWT_SECRET=curta"
"%TKEXE%" > "%OUT%\prod-2.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
type "%OUT%\prod-2.txt" >> "%LOG%"

echo ---- 5. producao com a chave de desenvolvimento >> "%LOG%"
set "JWT_SECRET=chave-de-desenvolvimento-troque-em-producao"
"%TKEXE%" > "%OUT%\prod-3.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
type "%OUT%\prod-3.txt" >> "%LOG%"

echo ---- 6. ambiente desconhecido >> "%LOG%"
set "APP_ENV=homologacao"
"%TKEXE%" > "%OUT%\prod-4.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
type "%OUT%\prod-4.txt" >> "%LOG%"

echo ---- 7. producao configurada corretamente >> "%LOG%"
set "APP_ENV=production"
set "JWT_SECRET=%STRONG%"
set "CUSTOMER_API_URL=http://127.0.0.1:9302"
start "ticket-api" /min cmd /c ""%~dp0lib\run-capture.bat" "%TKEXE%" "%OUT%\ticket-api-prod.txt""
set "APP_ENV="
set "JWT_SECRET="
set "DB_PASSWORD="
set "CUSTOMER_API_URL="
timeout /t 5 /nobreak >nul
echo ---- 8. token emitido com a chave de desenvolvimento na ticket-api de producao >> "%LOG%"
%C% "http://127.0.0.1:9003/reports/revenue?from=2026-10-01&to=2026-10-31" -H "Authorization: Bearer %CHEFE%" >> "%LOG%" 2>&1
echo. >> "%LOG%"

taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
timeout /t 1 /nobreak >nul
echo ---- 9. consoles >> "%LOG%"
type "%OUT%\event-api.txt" >> "%LOG%" 2>&1
type "%OUT%\customer-api.txt" >> "%LOG%" 2>&1
type "%OUT%\ticket-api-prod.txt" >> "%LOG%" 2>&1
> "%CAP%\customer-api\Win64\Debug\.env" echo # vazio
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
