@echo off
rem Garante que o Docker Desktop esta rodando antes dos testes.
docker info >nul 2>&1
if not errorlevel 1 goto :eof
echo iniciando Docker Desktop >> "%~1"
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
for /l %%i in (1,1,60) do (
  timeout /t 3 /nobreak >nul
  docker info >nul 2>&1 && goto :eof
)
echo ERRO: Docker nao respondeu em 3 minutos >> "%~1"
