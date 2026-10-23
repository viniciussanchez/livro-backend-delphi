@echo off
rem Roteiro de testes do capitulo 20, como foi usado na escrita do livro.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap20.log.
set "LOG=%~dp0test-cap20.log"
for %%i in ("%~dp0..") do set "CAP=%%~fi"
for %%i in ("%~dp0..\..\cap19-kubernetes") do set "CAP19=%%~fi"
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0lib\k8s-purge-images.ps1" -Images eventos/event-api:1.0.1,eventos/customer-api:1.0.1,eventos/ticket-api:1.0.1,eventos/api-gateway:1.0.1,eventos/customer-api:cap19 >> "%LOG%" 2>&1

echo ---- 1. imagens >> "%LOG%"
for %%s in (event-api customer-api ticket-api api-gateway) do (
  docker build -t eventos/%%s:1.0.1 "%CAP%\%%s" >> "%OUT%\build.txt" 2>&1
)
docker build -t eventos/customer-api:cap19 "%CAP19%\customer-api" >> "%OUT%\build.txt" 2>&1
docker image ls "eventos/*" >> "%LOG%" 2>&1

echo ---- 2. kubectl apply -k >> "%LOG%"
%PS% -File "%~dp0lib\new-env.ps1" -Path "%CAP%\k8s\.env"
for /f "usebackq tokens=1,* delims==" %%a in ("%CAP%\k8s\.env") do if "%%a"=="ADMIN_PASSWORD" set "ADMIN_PASSWORD=%%b"
kubectl kustomize "%CAP%\k8s" > "%OUT%\kustomize.yaml" 2>&1
echo inicio %time% >> "%LOG%"
kubectl apply -k "%CAP%\k8s" >> "%LOG%" 2>&1
%K% rollout status statefulset/postgres --timeout=180s >> "%LOG%" 2>&1
%K% rollout status deploy/event-api --timeout=180s >> "%LOG%" 2>&1
%K% rollout status deploy/customer-api --timeout=180s >> "%LOG%" 2>&1
%K% rollout status deploy/ticket-api --timeout=180s >> "%LOG%" 2>&1
%K% rollout status deploy/api-gateway --timeout=180s >> "%LOG%" 2>&1
echo fim %time% >> "%LOG%"
del "%CAP%\k8s\.env"
%K% get pods -o wide >> "%LOG%" 2>&1
%K% get pods -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image >> "%LOG%" 2>&1
%K% get svc,statefulset,deploy,pvc,secret >> "%LOG%" 2>&1

echo ---- 3. migracoes com 3 copias da ticket-api >> "%LOG%"
for /f "usebackq delims=" %%p in (`kubectl -n eventos get pods -l app.kubernetes.io/name^=ticket-api -o jsonpath^="{range .items[*]}{.metadata.name}{'\n'}{end}"`) do (
  echo == %%p >> "%LOG%"
  kubectl -n eventos logs %%p -c wait-for-postgres >> "%LOG%" 2>&1
  kubectl -n eventos logs %%p | findstr /c:"Migra" /c:"rodando" >> "%LOG%" 2>&1
)
%K% exec postgres-0 -- psql -U eventos -d ticket_db -c "select version, description, applied_at from schema_migration" >> "%LOG%" 2>&1

echo ---- 4. pela porta da frente >> "%LOG%"
%C% -w " [%%{http_code}]" http://127.0.0.1:9000/health >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -w " [%%{http_code}]" http://127.0.0.1:9000/health/live >> "%LOG%" 2>&1
echo. >> "%LOG%"

echo ---- 5. corrida: 30 compradores, 10 ingressos, 3 copias da ticket-api >> "%LOG%"
%PS% -File "%~dp0lib\race-k8s.ps1" -AdminPassword "%ADMIN_PASSWORD%" >> "%LOG%" 2>&1
%PS% -File "%~dp0lib\race-k8s.ps1" -AdminPassword "%ADMIN_PASSWORD%" -Buyers 60 -Tickets 20 >> "%LOG%" 2>&1
kubectl -n eventos logs -l app.kubernetes.io/name=ticket-api --prefix --tail=-1 | findstr /c:"Exception" /c:"indispon" >> "%LOG%" 2>&1
kubectl -n eventos logs -l app.kubernetes.io/name=event-api --prefix --tail=-1 | findstr /c:"Exception" >> "%LOG%" 2>&1
%K% get pods -l app.kubernetes.io/name=ticket-api -o custom-columns=POD:.metadata.name,IP:.status.podIP >> "%LOG%" 2>&1
%K% exec postgres-0 -- psql -U eventos -d ticket_db -c "select client_addr, count(*) as conexoes from pg_stat_activity where datname = 'ticket_db' and client_addr is not null group by client_addr order by 1" >> "%LOG%" 2>&1

rem As corridas fizeram logins; espera a janela do limite de login (60 s) zerar.
timeout /t 61 /nobreak >nul
echo ---- 6. roteiro do capitulo 16 >> "%LOG%"
%PS% -File "%~dp0lib\gateway-demo.ps1" -Part main -AdminPassword "%ADMIN_PASSWORD%" > "%OUT%\demo.txt" 2>&1
findstr /c:"-- " /c:"status" /c:"acentos" "%OUT%\demo.txt" >> "%LOG%"

echo ---- 7. o administrador criado por varias copias ao mesmo tempo >> "%LOG%"
%PS% -File "%~dp0lib\customer-race.ps1" -Image eventos/customer-api:cap19 >> "%LOG%" 2>&1
%PS% -File "%~dp0lib\customer-race.ps1" -Image eventos/customer-api:1.0.1 >> "%LOG%" 2>&1

echo ---- 7b. corrida grande: 150 compradores, 50 ingressos (MAX_CONNECTIONS) >> "%LOG%"
%PS% -File "%~dp0lib\race-k8s.ps1" -AdminPassword "%ADMIN_PASSWORD%" -Buyers 150 -Tickets 50 >> "%LOG%" 2>&1

echo ---- 8. o banco perde o Pod, mas nao os dados >> "%LOG%"
%K% exec postgres-0 -- psql -U eventos -d ticket_db -t -A -c "select count(*) from reservation" >> "%LOG%" 2>&1
%K% get pod postgres-0 -o custom-columns=POD:.metadata.name,UID:.metadata.uid,IP:.status.podIP >> "%LOG%" 2>&1
%K% delete pod postgres-0 >> "%LOG%" 2>&1
%K% wait --for=condition=Ready pod/postgres-0 --timeout=120s >> "%LOG%" 2>&1
%K% get pod postgres-0 -o custom-columns=POD:.metadata.name,UID:.metadata.uid,IP:.status.podIP >> "%LOG%" 2>&1
%K% exec postgres-0 -- psql -U eventos -d ticket_db -t -A -c "select count(*) from reservation" >> "%LOG%" 2>&1
timeout /t 15 /nobreak >nul
%C% -w " [%%{http_code}]" http://127.0.0.1:9000/health >> "%LOG%" 2>&1
echo. >> "%LOG%"
%K% get pods >> "%LOG%" 2>&1

echo ---- 9. limpeza >> "%LOG%"
%K% get events --sort-by=.lastTimestamp > "%OUT%\events.txt" 2>&1
kubectl delete namespace eventos >> "%LOG%" 2>&1
echo ==== fim >> "%LOG%"
