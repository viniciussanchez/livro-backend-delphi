@echo off
rem Roteiro de testes do capitulo 21, como foi usado na escrita do livro.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap21.log.
set "LOG=%~dp0test-cap21.log"
for %%i in ("%~dp0..") do set "CAP=%%~fi"
set "OUT=%~dp0out"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
set "K=kubectl -n eventos"
set "C=curl -s --max-time 10"
echo ==== testes %date% %time% > "%LOG%"
if not exist "%OUT%" mkdir "%OUT%"
call "%~dp0lib\ensure-docker.bat" "%LOG%"
for /l %%i in (1,1,40) do (
  kubectl get nodes 2>nul | findstr /c:" Ready" >nul && goto :pronto
  timeout /t 15 /nobreak >nul
)
:pronto
kubectl delete namespace eventos --wait=true >nul 2>&1
rem Tira do no do cluster as imagens antigas com a mesma etiqueta (capitulo 20).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0lib\k8s-purge-images.ps1" -Images eventos/event-api:1.1.1,eventos/customer-api:1.1.1,eventos/ticket-api:1.1.1,eventos/api-gateway:1.1.1 >> "%LOG%" 2>&1
taskkill /im kubectl.exe /f >nul 2>&1

echo ---- 0. log em texto, no desenvolvimento >> "%LOG%"
rem A libpq.dll (capitulo 5) precisa estar no PATH; PGSQL_BIN aponta a pasta dela.
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "PORT=9501"
set "DB_HOST=127.0.0.9"
start "ev" /min cmd /c ""%CAP%\event-api\Win64\Debug\EventApi.exe" > "%OUT%\dev-text.txt" 2>&1"
set "PORT="
set "DB_HOST="
timeout /t 5 /nobreak >nul
taskkill /im EventApi.exe /f >nul 2>&1
type "%OUT%\dev-text.txt" >> "%LOG%"

echo ---- 1. imagens 1.1.1 >> "%LOG%"
for %%s in (event-api customer-api ticket-api api-gateway) do (
  docker build -t eventos/%%s:1.1.1 "%CAP%\%%s" >> "%OUT%\build.txt" 2>&1
)
docker image ls "eventos/*:1.1.1" >> "%LOG%" 2>&1

echo ---- 2. apply -k >> "%LOG%"
%PS% -File "%~dp0lib\new-env.ps1" -Path "%CAP%\k8s\.env"
for /f "usebackq tokens=1,* delims==" %%a in ("%CAP%\k8s\.env") do if "%%a"=="ADMIN_PASSWORD" set "ADMIN_PASSWORD=%%b"
kubectl apply -k "%CAP%\k8s" >> "%LOG%" 2>&1
del "%CAP%\k8s\.env"
%K% rollout status statefulset/postgres --timeout=180s >> "%LOG%" 2>&1
for %%s in (event-api customer-api ticket-api api-gateway prometheus) do %K% rollout status deploy/%%s --timeout=240s >> "%LOG%" 2>&1
%K% get pods >> "%LOG%" 2>&1

echo ---- 3. uma compra seguida pelos logs >> "%LOG%"
%PS% -File "%~dp0lib\trace-k8s.ps1" -AdminPassword "%ADMIN_PASSWORD%" >> "%LOG%" 2>&1
echo ---- 4. corrida >> "%LOG%"
%PS% -File "%~dp0lib\race-k8s.ps1" -AdminPassword "%ADMIN_PASSWORD%" -Buyers 60 -Tickets 20 >> "%LOG%" 2>&1
timeout /t 3 /nobreak >nul
echo ---- 5. logs >> "%LOG%"
%PS% -File "%~dp0lib\logs-k8s.ps1" -TraceId livro-cap21-compra >> "%LOG%" 2>&1
%PS% -File "%~dp0lib\logs-k8s.ps1" >> "%LOG%" 2>&1
for /f "usebackq delims=" %%p in (`kubectl -n eventos get pods -l app.kubernetes.io/name^=customer-api -o jsonpath^="{.items[0].metadata.name}"`) do set "CPOD=%%p"
%K% logs %CPOD% --tail=-1 > "%OUT%\customer-pod.txt" 2>&1

echo ---- 6. /metrics de uma copia da ticket-api >> "%LOG%"
start "pf1" /min cmd /c "kubectl -n eventos port-forward svc/ticket-api 19003:9003 > nul 2>&1"
timeout /t 4 /nobreak >nul
%C% -o nul -w "FOO1 %%{http_code} " -X FOO1 http://127.0.0.1:19003/health/live >> "%LOG%" 2>&1
%C% -o nul -w "BAR2 %%{http_code}" -X BAR2 http://127.0.0.1:19003/health/live >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% http://127.0.0.1:19003/metrics > "%OUT%\metrics-ticket.txt" 2>&1
echo -- rotulos de metodo inventados: >> "%LOG%"
findstr /c:"OTHER" /c:"FOO1" /c:"BAR2" "%OUT%\metrics-ticket.txt" >> "%LOG%"
%PS% -File "%~dp0lib\show-metrics.ps1" -Path "%OUT%\metrics-ticket.txt" >> "%LOG%" 2>&1

echo ---- 7. Prometheus >> "%LOG%"
start "pf2" /min cmd /c "kubectl -n eventos port-forward svc/prometheus 19090:9090 > nul 2>&1"
timeout /t 20 /nobreak >nul
%PS% -File "%~dp0lib\prom-query.ps1" >> "%LOG%" 2>&1
taskkill /im kubectl.exe /f >nul 2>&1

echo ---- 8. limpeza >> "%LOG%"
kubectl delete namespace eventos >> "%LOG%" 2>&1
echo ==== fim >> "%LOG%"
