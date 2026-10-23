@echo off
rem Roteiro de testes do capitulo 19, como foi usado na escrita do livro.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap19.log.
set "LOG=%~dp0test-cap19.log"
for %%i in ("%~dp0..") do set "CAP=%%~fi"
set "OUT=%~dp0out"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
set "K=kubectl -n eventos"
set "C=curl -s --max-time 10"
echo ==== testes %date% %time% > "%LOG%"
if not exist "%OUT%" mkdir "%OUT%"
call "%~dp0lib\ensure-docker.bat" "%LOG%"
taskkill /im kubectl.exe /f >nul 2>&1

echo ---- 1. o cluster >> "%LOG%"
kubectl config current-context >> "%LOG%" 2>&1
kubectl version >> "%LOG%" 2>&1
kubectl get nodes -o wide >> "%LOG%" 2>&1
kubectl get pods -n kube-system >> "%LOG%" 2>&1

echo ---- 2. imagem da event-api >> "%LOG%"
docker build -t eventos/event-api:cap19 "%CAP%\event-api" > "%OUT%\build.txt" 2>&1
echo docker build: %ERRORLEVEL% >> "%LOG%"

echo ---- 3. aplicando os manifestos >> "%LOG%"
kubectl delete namespace eventos --wait=true >nul 2>&1
rem Tira do no do cluster as imagens antigas com a mesma etiqueta (capitulo 20).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0lib\k8s-purge-images.ps1" -Images eventos/event-api:cap19 >> "%LOG%" 2>&1
kubectl apply -f "%CAP%\k8s\00-namespace.yaml" >> "%LOG%" 2>&1
%PS% -File "%~dp0lib\new-env.ps1" -Path "%OUT%\.env"
%K% create secret generic eventos-secrets --from-env-file="%OUT%\.env" >> "%LOG%" 2>&1
del "%OUT%\.env"
kubectl apply -f "%CAP%\k8s" >> "%LOG%" 2>&1
echo inicio %time% >> "%LOG%"
%K% rollout status deploy/postgres --timeout=180s >> "%LOG%" 2>&1
%K% rollout status deploy/event-api --timeout=180s >> "%LOG%" 2>&1
echo fim %time% >> "%LOG%"
%K% get all -o wide >> "%LOG%" 2>&1
%K% get configmap,secret,pvc >> "%LOG%" 2>&1
%K% get endpoints event-api >> "%LOG%" 2>&1
%K% get secret eventos-secrets -o jsonpath="{.data.JWT_SECRET}" > "%OUT%\secret-b64.txt" 2>&1

echo ---- 4. conversando com a event-api >> "%LOG%"
start "pf" /min cmd /c "kubectl -n eventos port-forward svc/event-api 19001:9001 > "%OUT%\port-forward.txt" 2>&1"
timeout /t 4 /nobreak >nul
%C% -w " [%%{http_code}]" http://127.0.0.1:19001/health >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -w " [%%{http_code}]" http://127.0.0.1:19001/health/live >> "%LOG%" 2>&1
echo. >> "%LOG%"
%C% -w " [%%{http_code}]" http://127.0.0.1:19001/categories >> "%LOG%" 2>&1
echo. >> "%LOG%"
taskkill /im kubectl.exe /f >nul 2>&1
for /f "usebackq delims=" %%p in (`kubectl -n eventos get pods -l app.kubernetes.io/name^=event-api -o jsonpath^="{.items[0].metadata.name}"`) do set "POD1=%%p"
%K% logs %POD1% >> "%LOG%" 2>&1
%K% exec %POD1% -- /app/EventApi --healthcheck >> "%LOG%" 2>&1
echo healthcheck dentro do pod: %ERRORLEVEL% >> "%LOG%"

echo ---- 5. apagando um Pod: o Deployment repoe >> "%LOG%"
echo apagando %POD1% >> "%LOG%"
%K% delete pod %POD1% --wait=false >> "%LOG%" 2>&1
%K% get pods -l app.kubernetes.io/name=event-api >> "%LOG%" 2>&1
%PS% -File "%~dp0lib\k8s-wait-ready.ps1" -Deploy event-api -Count 2 >> "%LOG%" 2>&1
%K% get pods -l app.kubernetes.io/name=event-api >> "%LOG%" 2>&1

echo ---- 6. escalando para 3 >> "%LOG%"
%K% scale deploy/event-api --replicas=3 >> "%LOG%" 2>&1
%PS% -File "%~dp0lib\k8s-wait-ready.ps1" -Deploy event-api -Count 3 >> "%LOG%" 2>&1
%K% get pods -l app.kubernetes.io/name=event-api -o wide >> "%LOG%" 2>&1

echo ---- 7. banco fora do ar: readiness x liveness >> "%LOG%"
%K% scale deploy/postgres --replicas=0 >> "%LOG%" 2>&1
timeout /t 30 /nobreak >nul
%K% get pods >> "%LOG%" 2>&1
%K% get endpoints event-api >> "%LOG%" 2>&1
%K% scale deploy/postgres --replicas=1 >> "%LOG%" 2>&1
%PS% -File "%~dp0lib\k8s-wait-ready.ps1" -Deploy event-api -Count 3 >> "%LOG%" 2>&1
%K% get pods >> "%LOG%" 2>&1
%K% get endpoints event-api >> "%LOG%" 2>&1

echo ---- 8. atualizacao em etapas >> "%LOG%"
for /f "usebackq delims=" %%p in (`kubectl -n eventos get pods -l app.kubernetes.io/name^=event-api -o jsonpath^="{.items[0].metadata.name}"`) do set "OLD=%%p"
start "logs" /min cmd /c "kubectl -n eventos logs -f %OLD% > "%OUT%\old-pod.txt" 2>&1"
echo inicio %time% >> "%LOG%"
%K% set env deploy/event-api DB_POOL_SIZE=20 >> "%LOG%" 2>&1
%K% rollout status deploy/event-api --timeout=180s >> "%LOG%" 2>&1
echo fim %time% >> "%LOG%"
%K% rollout history deploy/event-api >> "%LOG%" 2>&1
%K% get pods -l app.kubernetes.io/name=event-api >> "%LOG%" 2>&1
timeout /t 2 /nobreak >nul
echo -- fim do log do pod antigo %OLD% >> "%LOG%"
%PS% -Command "Get-Content '%OUT%\old-pod.txt' -Encoding UTF8 | Select-Object -Last 4" >> "%LOG%" 2>&1
taskkill /im kubectl.exe /f >nul 2>&1

echo ---- 9. eventos e descricao >> "%LOG%"
%K% get events --sort-by=.lastTimestamp > "%OUT%\events.txt" 2>&1
%K% describe deploy/event-api > "%OUT%\describe.txt" 2>&1
%K% get deploy event-api -o yaml > "%OUT%\deploy.yaml" 2>&1

echo ---- 10. limpeza >> "%LOG%"
kubectl delete namespace eventos >> "%LOG%" 2>&1
echo ==== fim >> "%LOG%"
