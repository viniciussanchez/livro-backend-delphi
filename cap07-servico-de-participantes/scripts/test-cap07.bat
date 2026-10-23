@echo off
rem Roteiro de testes do capitulo 7, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem A pasta da libpq.dll (capitulo 5) precisa estar no PATH, ou em PGSQL_BIN.
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap07.log.
set "LOG=%~dp0test-cap07.log"
set "URL=http://localhost:9002"
if defined PGSQL_BIN set "PATH=%PGSQL_BIN%;%PATH%"
set "CAP=%~dp0.."
set "EXE=%CAP%\customer-api\Win64\Debug\CustomerApi.exe"
set "JSON=Content-Type: application/json"
echo ==== testes %date% %time% > "%LOG%"
taskkill /im CustomerApi.exe /f >nul 2>&1
docker rm -f eventos-postgres >nul 2>&1
pushd "%CAP%"
docker compose up -d --wait >> "%LOG%" 2>&1
popd
start "customer-api" /min "%EXE%"
timeout /t 4 /nobreak >nul
(
echo ---- 1. POST participante valido
curl -s --max-time 15 -i -X POST %URL%/customers -H "%JSON%" -d "{\"name\":\"Jo\u00e3o da Silva\",\"cpf\":\"529.982.247-25\",\"email\":\"Joao.Silva@Exemplo.com\",\"phone\":\"31 99999-8888\",\"birthDate\":\"1990-05-20\"}"
echo.
echo ---- 2. POST mesmo CPF
curl -s --max-time 15 -i -X POST %URL%/customers -H "%JSON%" -d "{\"name\":\"Outro\",\"cpf\":\"52998224725\",\"email\":\"outro@exemplo.com\"}"
echo.
echo ---- 3. POST CPF com digito errado
curl -s --max-time 15 -i -X POST %URL%/customers -H "%JSON%" -d "{\"name\":\"Teste\",\"cpf\":\"123.456.789-00\",\"email\":\"t@exemplo.com\"}"
echo.
echo ---- 4. POST CPF repetido 111
curl -s --max-time 15 -i -X POST %URL%/customers -H "%JSON%" -d "{\"name\":\"Teste\",\"cpf\":\"111.111.111-11\",\"email\":\"t@exemplo.com\"}"
echo.
echo ---- 5. POST email invalido
curl -s --max-time 15 -i -X POST %URL%/customers -H "%JSON%" -d "{\"name\":\"Teste\",\"cpf\":\"111.444.777-35\",\"email\":\"maria-exemplo.com\"}"
echo.
echo ---- 6. POST email ja usado
curl -s --max-time 15 -i -X POST %URL%/customers -H "%JSON%" -d "{\"name\":\"Maria\",\"cpf\":\"111.444.777-35\",\"email\":\"joao.silva@exemplo.com\"}"
echo.
echo ---- 7. POST segundo participante
curl -s --max-time 15 -i -X POST %URL%/customers -H "%JSON%" -d "{\"name\":\"Maria Souza\",\"cpf\":\"111.444.777-35\",\"email\":\"maria@exemplo.com\"}"
echo.
echo ---- 8. GET por cpf
curl -s --max-time 15 "%URL%/customers?cpf=52998224725"
echo.
echo ---- 9. GET por email maiusculo
curl -s --max-time 15 "%URL%/customers?email=MARIA@EXEMPLO.COM"
echo.
echo ---- 10. GET sem filtro
curl -s --max-time 15 -i %URL%/customers
echo.
echo ---- 11. GET /customers/1
curl -s --max-time 15 %URL%/customers/1
echo.
echo ---- 12. PUT email de outro
curl -s --max-time 15 -i -X PUT %URL%/customers/1 -H "%JSON%" -d "{\"name\":\"Jo\u00e3o da Silva\",\"email\":\"maria@exemplo.com\"}"
echo.
echo ---- 13. PUT valido tentando trocar CPF
curl -s --max-time 15 -i -X PUT %URL%/customers/1 -H "%JSON%" -d "{\"name\":\"Jo\u00e3o Pedro da Silva\",\"cpf\":\"111.444.777-35\",\"email\":\"joao.pedro@exemplo.com\",\"phone\":\"3133334444\"}"
echo.
echo ---- 14. DELETE /customers/1
curl -s --max-time 15 -i -X DELETE %URL%/customers/1
echo.
echo ---- 15. GET /customers/1 depois
curl -s --max-time 15 -i %URL%/customers/1
echo.
echo ---- 16. DELETE de novo
curl -s --max-time 15 -i -X DELETE %URL%/customers/1
echo.
echo ---- 17. GET por cpf removido
curl -s --max-time 15 "%URL%/customers?cpf=529.982.247-25"
echo.
echo ---- 18. POST novo cadastro com o CPF removido
curl -s --max-time 15 -i -X POST %URL%/customers -H "%JSON%" -d "{\"name\":\"Jo\u00e3o da Silva\",\"cpf\":\"529.982.247-25\",\"email\":\"joao.silva@exemplo.com\"}"
echo.
echo ---- 19. GET id invalido
curl -s --max-time 15 -i %URL%/customers/abc
echo.
echo ---- 20. banco
docker exec eventos-postgres psql -U eventos -d customer_db -c "select id, name, cpf, email, phone, anonymized_at is not null as anon from customer order by id"
) >> "%LOG%" 2>&1
taskkill /im CustomerApi.exe /f >nul 2>&1
docker rm -f eventos-postgres >nul 2>&1
pushd "%CAP%"
docker compose down -v >> "%LOG%" 2>&1
popd
echo ==== fim >> "%LOG%"
