@echo off
rem Roteiro de testes do capitulo 17, como foi usado na escrita do livro.
rem Antes, compile os servicos para Linux64 (Release) e os testes para Win64 e Linux64.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap17.log.
set "LOG=%~dp0test-cap17.log"
rem Caminho absoluto, sem "..": o Docker precisa dele assim nos volumes.
for %%i in ("%~dp0..") do set "CAP=%%~fi"
set "OUT=%~dp0out"
set "DEMO=powershell -NoProfile -ExecutionPolicy Bypass -File %~dp0lib\gateway-demo.ps1"
set "TESTS=%CAP%\tests\Win64\Debug\EventosTests.exe"
set "NET=cap17-linux_default"
set "BIN=-v "%CAP%\event-api\Linux64\Release:/opt/eventos/event-api:ro" -v "%CAP%\customer-api\Linux64\Release:/opt/eventos/customer-api:ro" -v "%CAP%\ticket-api\Linux64\Release:/opt/eventos/ticket-api:ro" -v "%CAP%\api-gateway\Linux64\Release:/opt/eventos/api-gateway:ro" -v "%CAP%\linux:/opt/eventos/scripts:ro""
echo ==== testes %date% %time% > "%LOG%"
if not exist "%OUT%" mkdir "%OUT%"
call "%~dp0lib\ensure-docker.bat" "%LOG%"
taskkill /im EventApi.exe /f >nul 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
taskkill /im TicketApi.exe /f >nul 2>&1
taskkill /im ApiGateway.exe /f >nul 2>&1
docker rm -f eventos-postgres eventos-linux >nul 2>&1
pushd "%CAP%"
docker compose up -d --wait >> "%LOG%" 2>&1
popd

echo ---- 1. os executaveis gerados >> "%LOG%"
docker run --rm %BIN% ubuntu:22.04 sh -c "ls -l /opt/eventos/*/; head -c 4 /opt/eventos/event-api/EventApi | od -c | head -1; echo; ldd /opt/eventos/event-api/EventApi" >> "%LOG%" 2>&1

echo ---- 2. event-api em um Ubuntu limpo, sem o libpq >> "%LOG%"
docker run --rm --network %NET% -e DB_HOST=postgres %BIN% ubuntu:22.04 /opt/eventos/event-api/EventApi >> "%LOG%" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"

echo ---- 3. imagem do servidor de laboratorio >> "%LOG%"
docker build -t eventos-servidor-linux -f "%CAP%\linux\Dockerfile.servidor" "%CAP%\linux" >> "%OUT%\docker-build.txt" 2>&1
echo docker build: %ERRORLEVEL% >> "%LOG%"
docker image ls eventos-servidor-linux >> "%LOG%" 2>&1

echo ---- 4. os quatro servicos no Linux >> "%LOG%"
docker run -d --init --name eventos-linux --network %NET% -p 9000-9003:9000-9003 -e DB_HOST=postgres %BIN% eventos-servidor-linux sleep infinity >> "%LOG%" 2>&1
docker exec eventos-linux sh /opt/eventos/scripts/start-all.sh >> "%LOG%" 2>&1
timeout /t 8 /nobreak >nul
docker exec eventos-linux ps -o pid,rss,etime,cmd -C EventApi,CustomerApi,TicketApi,ApiGateway >> "%LOG%" 2>&1
docker exec eventos-linux uname -a >> "%LOG%" 2>&1
curl -s -w " [%%{http_code}]" http://127.0.0.1:9000/health >> "%LOG%" 2>&1
echo. >> "%LOG%"

echo ---- 5. roteiro do capitulo 16, agora contra o Linux >> "%LOG%"
%DEMO% -Part main >> "%LOG%" 2>&1

echo ---- 5b. o que ficou gravado no banco >> "%LOG%"
docker exec eventos-postgres psql -U eventos -d event_db -c "select name, octet_length(name) as bytes from venue" >> "%OUT%\venue.txt" 2>&1
docker exec eventos-postgres psql -U eventos -d customer_db -c "select name, octet_length(name) as bytes from customer" >> "%OUT%\venue.txt" 2>&1
echo ---- 6. testes de integracao do capitulo 15 contra o Linux >> "%LOG%"
"%TESTS%" --include:integracao > "%OUT%\integracao.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
findstr /c:"Tests Found" /c:"Tests Passed" /c:"Tests Failed" /c:"Tests Errored" "%OUT%\integracao.txt" >> "%LOG%"

echo ---- 6b. testes de unidade compilados para Linux >> "%LOG%"
docker run --rm -v "%CAP%\tests\Linux64\Release:/app:ro" eventos-servidor-linux /app/EventosTests --exclude:integracao > "%OUT%\unidade-linux.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
findstr /c:"Tests Found" /c:"Tests Passed" /c:"Tests Failed" /c:"Tests Errored" "%OUT%\unidade-linux.txt" >> "%LOG%"
echo ---- 7. SIGTERM em cada servico >> "%LOG%"
docker exec eventos-linux sh /opt/eventos/scripts/stop-one.sh ApiGateway >> "%LOG%" 2>&1
docker exec eventos-linux sh /opt/eventos/scripts/stop-one.sh TicketApi >> "%LOG%" 2>&1
docker exec eventos-linux sh /opt/eventos/scripts/stop-one.sh CustomerApi >> "%LOG%" 2>&1
docker exec eventos-linux sh /opt/eventos/scripts/stop-one.sh EventApi >> "%LOG%" 2>&1

echo ---- 8. logs >> "%LOG%"
docker exec eventos-linux sh -c "for f in /var/log/eventos/*.log; do echo == $f; grep -v ' GET    /categories ' $f; done" >> "%LOG%" 2>&1

docker rm -f eventos-linux >> "%LOG%" 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
