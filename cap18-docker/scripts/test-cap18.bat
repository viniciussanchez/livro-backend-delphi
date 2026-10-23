@echo off
rem Roteiro de testes do capitulo 18, como foi usado na escrita do livro.
rem Antes, compile os servicos para Linux64 (Release) e os testes para Win64 e Linux64.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap18.log.
set "LOG=%~dp0test-cap18.log"
for %%i in ("%~dp0..") do set "CAP=%%~fi"
set "OUT=%~dp0out"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
set "TESTS=%CAP%\tests\Win64\Debug\EventosTests.exe"
set "C=curl -s --max-time 10"
echo ==== testes %date% %time% > "%LOG%"
if not exist "%OUT%" mkdir "%OUT%"
call "%~dp0lib\ensure-docker.bat" "%LOG%"
docker rm -f eventos-postgres eventos-linux >nul 2>&1
pushd "%CAP%"
docker compose down -v >nul 2>&1

echo ---- 1. .env com segredos gerados na hora >> "%LOG%"
%PS% -File "%~dp0lib\new-env.ps1" -Path "%CAP%\.env"
for /f "usebackq tokens=1,* delims==" %%a in ("%CAP%\.env") do if "%%a"=="ADMIN_PASSWORD" set "ADMIN_PASSWORD=%%b"
%PS% -Command "Get-Content '%CAP%\.env' | ForEach-Object { ($_ -split '=')[0] + '=' + ('*' * 8) }" >> "%LOG%"

echo ---- 2. docker compose build >> "%LOG%"
echo inicio %time% >> "%LOG%"
docker compose build > "%OUT%\build.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% fim %time% >> "%LOG%"
docker image ls "eventos/*" >> "%LOG%" 2>&1
docker image ls ubuntu:22.04 >> "%LOG%" 2>&1
docker history eventos/event-api:cap18 >> "%LOG%" 2>&1

echo ---- 3. docker compose up >> "%LOG%"
echo inicio %time% >> "%LOG%"
docker compose up -d --wait >> "%LOG%" 2>&1
echo codigo de saida: %ERRORLEVEL% fim %time% >> "%LOG%"
docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}" >> "%LOG%" 2>&1

echo ---- 4. so o gateway esta exposto >> "%LOG%"
%C% -w " [%%{http_code}]" http://127.0.0.1:9000/health >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -o nul -w "porta 9001: %%{http_code}" http://127.0.0.1:9001/health >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -o nul -w "porta 5432: %%{http_code} (curl codigo %%{exitcode})" http://127.0.0.1:5432 >> "%LOG%" 2>&1
echo. >> "%LOG%"

echo ---- 5. usuario e arquivos dentro do conteiner >> "%LOG%"
docker compose exec -T event-api /app/EventApi --healthcheck >> "%LOG%" 2>&1
echo healthcheck manual: %ERRORLEVEL% >> "%LOG%"
docker inspect --format "{{.Config.User}} {{json .State.Health.Status}} {{len .State.Health.Log}} verificacoes" eventos-event-api-1 >> "%LOG%" 2>&1
docker compose exec -T event-api sh -c "id; ls -l /app; grep -E '^(Name|Pid|Uid|VmRSS)' /proc/1/status" >> "%LOG%" 2>&1

echo ---- 6. roteiro pelo gateway, agora em conteineres >> "%LOG%"
%PS% -File "%~dp0lib\gateway-demo.ps1" -Part main -AdminPassword "%ADMIN_PASSWORD%" >> "%LOG%" 2>&1

echo ---- 7. parar um servico: quanto tempo e como ele sai >> "%LOG%"
%PS% -Command "$t=Measure-Command { docker compose stop ticket-api 2>&1 | Out-Null }; 'docker compose stop ticket-api: ' + [int]$t.TotalMilliseconds + ' ms'" >> "%LOG%" 2>&1
docker inspect --format "codigo de saida da ticket-api: {{.State.ExitCode}}" eventos-ticket-api-1 >> "%LOG%" 2>&1
docker compose logs --no-log-prefix --tail 3 ticket-api >> "%LOG%" 2>&1
%C% -w " [%%{http_code}]" http://127.0.0.1:9000/health >> "%LOG%" 2>&1
echo. >> "%LOG%"
docker compose start ticket-api >> "%LOG%" 2>&1
docker compose up -d --wait >> "%LOG%" 2>&1
%C% -w " [%%{http_code}]" http://127.0.0.1:9000/health >> "%LOG%" 2>&1
echo. >> "%LOG%"

echo ---- 8. configuracao invalida em producao >> "%LOG%"
docker compose run --rm --no-deps -e JWT_SECRET=curta ticket-api >> "%LOG%" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"

echo ---- 9. testes de integracao com as portas de desenvolvimento >> "%LOG%"
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait >> "%OUT%\dev-up.txt" 2>&1
docker compose -f docker-compose.yml -f docker-compose.dev.yml ps --format "table {{.Service}}\t{{.Ports}}" >> "%LOG%" 2>&1
"%TESTS%" --include:integracao > "%OUT%\integracao.txt" 2>&1
echo codigo de saida: %ERRORLEVEL% >> "%LOG%"
findstr /c:"Tests Found" /c:"Tests Passed" /c:"Tests Failed" /c:"Tests Errored" "%OUT%\integracao.txt" >> "%LOG%"

echo ---- 10. logs >> "%LOG%"
docker compose logs --no-color > "%OUT%\logs.txt" 2>&1
docker compose down -v >> "%LOG%" 2>&1
del "%CAP%\.env"
popd
echo ==== fim >> "%LOG%"
