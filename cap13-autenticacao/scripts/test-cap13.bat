@echo off
rem Roteiro de testes do capitulo 13, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap13.log.
set "LOG=%~dp0test-cap13.log"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "OUT=%~dp0out"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass -File %~dp0lib\jwt.ps1"
set "JSON=Content-Type: application/json"
set "C=curl -s --max-time 30"
set "EV=http://127.0.0.1:9001"
set "CU=http://127.0.0.1:9002"
set "TK=http://127.0.0.1:9003"
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
timeout /t 7 /nobreak >nul

for /f "usebackq delims=" %%t in (`%PS% -Action login -Email admin@eventos.local -Password admin12345`) do set "ADMIN=%%t"
echo ---- 1. token do admin: %ADMIN:~0,25%... >> "%LOG%"
for /f "usebackq delims=" %%t in (`%PS% -Action decode -Token %ADMIN%`) do echo conteudo: %%t >> "%LOG%"

(
echo ---- 2. criar local sem token
%C% -i -X POST %EV%/venues -H "%JSON%" -d "{\"name\":\"Arena\",\"address\":\"Rua A, 1\",\"city\":\"BH\",\"state\":\"MG\",\"capacity\":500}"
echo.
echo ---- 3. cadastro de participante sem senha
%C% -X POST %CU%/customers -H "%JSON%" -d "{\"cpf\":\"529.982.247-25\",\"name\":\"Ana Souza\",\"email\":\"ana@exemplo.com\"}"
echo.
echo ---- 4. cadastros com senha
%C% -o nul -w "ana %%{http_code} " -X POST %CU%/customers -H "%JSON%" -d "{\"cpf\":\"529.982.247-25\",\"name\":\"Ana Souza\",\"email\":\"ana@exemplo.com\",\"password\":\"senha-da-ana\"}"
%C% -o nul -w "bruno %%{http_code}" -X POST %CU%/customers -H "%JSON%" -d "{\"cpf\":\"111.444.777-35\",\"name\":\"Bruno Lima\",\"email\":\"bruno@exemplo.com\",\"password\":\"senha-do-bruno\"}"
echo.
echo ---- 5. senha errada e e-mail inexistente
%C% -X POST %CU%/auth/token -H "%JSON%" -d "{\"email\":\"ana@exemplo.com\",\"password\":\"errada123\"}"
echo.
%C% -X POST %CU%/auth/token -H "%JSON%" -d "{\"email\":\"ninguem@exemplo.com\",\"password\":\"errada123\"}"
echo.
) >> "%LOG%" 2>&1

for /f "usebackq delims=" %%t in (`%PS% -Action login -Email ana@exemplo.com -Password senha-da-ana`) do set "ANA=%%t"
for /f "usebackq delims=" %%t in (`%PS% -Action login -Email bruno@exemplo.com -Password senha-do-bruno`) do set "BRUNO=%%t"
for /f "usebackq delims=" %%t in (`%PS% -Action decode -Token %ANA%`) do echo ---- 6. token da Ana: %%t >> "%LOG%"

(
echo ---- 7. Ana tenta criar um local
%C% -i -X POST %EV%/venues -H "Authorization: Bearer %ANA%" -H "%JSON%" -d "{\"name\":\"Arena\",\"address\":\"Rua A, 1\",\"city\":\"BH\",\"state\":\"MG\",\"capacity\":500}"
echo.
echo ---- 8. admin prepara o evento
%C% -o nul -w "local %%{http_code} " -X POST %EV%/venues -H "Authorization: Bearer %ADMIN%" -H "%JSON%" -d "{\"name\":\"Arena\",\"address\":\"Rua A, 1\",\"city\":\"BH\",\"state\":\"MG\",\"capacity\":500}"
%C% -o nul -w "evento %%{http_code} " -X POST %EV%/events -H "Authorization: Bearer %ADMIN%" -H "%JSON%" -d "{\"name\":\"Show de Estreia\",\"categoryId\":1,\"venueId\":1,\"startAt\":\"2099-03-10T20:00:00\"}"
%C% -o nul -w "lote %%{http_code} " -X POST %EV%/events/1/batches -H "Authorization: Bearer %ADMIN%" -H "%JSON%" -d "{\"name\":\"Primeiro lote\",\"price\":150,\"quantity\":100,\"salesStart\":\"2020-01-01T00:00:00\",\"salesEnd\":\"2099-03-01T00:00:00\"}"
%C% -o nul -w "publica %%{http_code} " -X POST %EV%/events/1/publish -H "Authorization: Bearer %ADMIN%"
%C% -o nul -w "equipe %%{http_code}" -X POST %CU%/users -H "Authorization: Bearer %ADMIN%" -H "%JSON%" -d "{\"email\":\"portaria@eventos.local\",\"password\":\"portaria123\",\"role\":\"staff\"}"
echo.
echo ---- 9. Ana compra informando o customerId do Bruno
%C% -X POST %TK%/reservations -H "Authorization: Bearer %ANA%" -H "%JSON%" -d "{\"customerId\":2,\"batchId\":1,\"quantity\":2}"
echo.
echo ---- 10. Bruno tenta ver a reserva da Ana, e a Ana ve a propria
%C% -w " %%{http_code}" %TK%/reservations/1 -H "Authorization: Bearer %BRUNO%"
echo.
%C% -o nul -w "ana %%{http_code}" %TK%/reservations/1 -H "Authorization: Bearer %ANA%"
echo.
echo ---- 11. Ana no proprio cadastro, no do Bruno e na busca por e-mail
%C% -o nul -w "proprio %%{http_code} " %CU%/customers/1 -H "Authorization: Bearer %ANA%"
%C% -o nul -w "bruno %%{http_code} " %CU%/customers/2 -H "Authorization: Bearer %ANA%"
%C% -o nul -w "busca %%{http_code}" "%CU%/customers?email=bruno@exemplo.com" -H "Authorization: Bearer %ANA%"
echo.
) >> "%LOG%" 2>&1

for /f "usebackq delims=" %%t in (`%PS% -Action login -Email portaria@eventos.local -Password portaria123`) do set "STAFF=%%t"
for /f %%c in ('docker exec eventos-postgres psql -U eventos -d ticket_db -tAc "select code from ticket order by id limit 1"') do set "CODE1=%%c"

(
echo ---- 12. check-in pela Ana e pela portaria
%C% -o nul -w "ana %%{http_code} " -X POST %TK%/tickets/%CODE1%/check-in -H "Authorization: Bearer %ANA%"
%C% -o nul -w "portaria %%{http_code}" -X POST %TK%/tickets/%CODE1%/check-in -H "Authorization: Bearer %STAFF%"
echo.
echo ---- 13. relatorio pela portaria e pelo admin
%C% -o nul -w "portaria %%{http_code} " %TK%/reports/events/1/sales -H "Authorization: Bearer %STAFF%"
%C% %TK%/reports/events/1/sales -H "Authorization: Bearer %ADMIN%"
echo.
) >> "%LOG%" 2>&1

for /f "usebackq delims=" %%t in (`%PS% -Action forge -Kind expired`) do set "F1=%%t"
for /f "usebackq delims=" %%t in (`%PS% -Action forge -Kind none`) do set "F2=%%t"
for /f "usebackq delims=" %%t in (`%PS% -Action forge -Kind wrongkey`) do set "F3=%%t"
for /f "usebackq delims=" %%t in (`%PS% -Action forge -Kind tampered -Token %ANA%`) do set "F4=%%t"

(
echo ---- 14. tokens forjados no relatorio
%C% %TK%/reports/events/1/sales -H "Authorization: Bearer %F1%"
echo.
%C% %TK%/reports/events/1/sales -H "Authorization: Bearer %F2%"
echo.
%C% %TK%/reports/events/1/sales -H "Authorization: Bearer %F3%"
echo.
%C% %TK%/reports/events/1/sales -H "Authorization: Bearer %F4%"
echo.
echo ---- 15. consultas publicas continuam abertas
%C% -o nul -w "eventos %%{http_code} " %EV%/events
%C% -o nul -w "swagger %%{http_code}" %TK%/swagger/doc/json
echo.
echo ---- 15b. rascunho: evento 2 criado e nao publicado
%C% -o nul -w "evento2 %%{http_code}" -X POST %EV%/events -H "Authorization: Bearer %ADMIN%" -H "%JSON%" -d "{\"name\":\"Show Secreto\",\"categoryId\":1,\"venueId\":1,\"startAt\":\"2099-04-10T20:00:00\"}"
echo.
echo ---- 15c. rascunho por id: anonimo, Ana e admin
%C% -w " anonimo %%{http_code}" %EV%/events/2
echo.
%C% -o nul -w "ana %%{http_code} " %EV%/events/2 -H "Authorization: Bearer %ANA%"
%C% -o nul -w "admin %%{http_code}" %EV%/events/2 -H "Authorization: Bearer %ADMIN%"
echo.
echo ---- 15d. listagem de rascunhos: anonimo e admin
%C% -w " anonimo %%{http_code}" "%EV%/events?status=draft"
echo.
%C% -o nul -w "admin %%{http_code} " "%EV%/events?status=draft" -H "Authorization: Bearer %ADMIN%"
%C% -o nul -w "lista-publica %%{http_code}" %EV%/events
echo.
echo ---- 15e. token invalido em rota publica
%C% -o nul -w "token-ruim %%{http_code}" %EV%/events -H "Authorization: Bearer abc.def.ghi"
echo.
) >> "%LOG%" 2>&1
%C% -o "%OUT%\ticket-api.json" %TK%/swagger/doc/json
%C% -o "%OUT%\customer-api.json" %CU%/swagger/doc/json
%C% -o "%OUT%\event-api.json" %EV%/swagger/doc/json

taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
timeout /t 1 /nobreak >nul
echo ---- 16. console da customer-api >> "%LOG%"
type "%OUT%\customer-api.txt" >> "%LOG%" 2>&1
echo ---- 17. senhas no banco >> "%LOG%"
docker exec eventos-postgres psql -U eventos -d customer_db -c "select id, email, role, customer_id, left(password_hash, 29) as inicio_do_hash from app_user order by id" >> "%LOG%" 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
