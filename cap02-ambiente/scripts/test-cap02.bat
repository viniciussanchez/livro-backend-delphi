@echo off
rem Roteiro de testes do capitulo 2, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap02.log.
set "LOG=%~dp0test-cap02.log"
cd /d "%~dp0.."
echo ==== iniciando Docker Desktop %date% %time% > "%LOG%"
docker info >nul 2>&1
if errorlevel 1 (
  start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
  for /l %%i in (1,1,60) do (
    timeout /t 3 /nobreak >nul
    docker info >nul 2>&1 && goto :pronto
  )
  echo ERRO: Docker nao respondeu em 3 minutos >> "%LOG%"
  goto :eof
)
:pronto
(
echo ==== testes %date% %time%
echo ---- docker version
docker version --format "{{.Server.Version}}"
echo ---- porta 5432 em uso antes?
netstat -ano | findstr ":5432 " | findstr LISTENING
echo ---- compose up
docker compose up -d --wait
call echo UP_EXIT=%%ERRORLEVEL%%
echo ---- ps
docker compose ps
echo ---- bancos
docker exec eventos-postgres psql -U eventos -d eventos -c "\l"
echo ---- versao
docker exec eventos-postgres psql -U eventos -d eventos -tAc "select version()"
echo ---- compose down
docker compose down -v
call echo DOWN_EXIT=%%ERRORLEVEL%%
echo ==== fim
) >> "%LOG%" 2>&1
