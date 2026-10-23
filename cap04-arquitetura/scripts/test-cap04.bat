@echo off
rem Roteiro de testes do capitulo 4, como foi usado na escrita do livro.
rem Antes, compile os projetos do capitulo (Win64, Debug).
rem Rode a partir de qualquer pasta: o resultado vai para scripts\test-cap04.log.
set "LOG=%~dp0test-cap04.log"
set "URL=http://localhost:9001"
cd /d "%~dp0..\event-api\Win64\Debug"

taskkill /im EventApi.exe /f >nul 2>&1
start "EventApi" /min EventApi.exe
timeout /t 3 /nobreak >nul

(
echo ==== testes %date% %time%
echo.
echo ---- 3. GET /events vazio
curl -s -i %URL%/events
echo.
echo ---- 4. POST /events valido
curl -s -i -X POST %URL%/events -H "Content-Type: application/json" -d "{\"name\":\"Delphi Conference\",\"city\":\"Belo Horizonte\",\"eventDate\":\"2026-11-20\",\"capacity\":300}"
echo.
echo ---- 5. POST /events segundo evento
curl -s -i -X POST %URL%/events -H "Content-Type: application/json" -d "{\"name\":\"Festival de Rock\",\"city\":\"Sao Paulo\",\"eventDate\":\"2026-12-05\",\"capacity\":5000}"
echo.
echo ---- 6. GET /events?city=belo horizonte
curl -s -i "%URL%/events?city=belo%%20horizonte"
echo.
echo ---- 7. GET /events/1
curl -s -i %URL%/events/1
echo.
echo ---- 8. GET /events/abc
curl -s -i %URL%/events/abc
echo.
echo ---- 9. GET /events/99
curl -s -i %URL%/events/99
echo.
echo ---- 10. POST capacidade invalida
curl -s -i -X POST %URL%/events -H "Content-Type: application/json" -d "{\"name\":\"X\",\"city\":\"Y\",\"eventDate\":\"2026-11-20\",\"capacity\":0}"
echo.
echo ---- 11. POST data invalida
curl -s -i -X POST %URL%/events -H "Content-Type: application/json" -d "{\"name\":\"X\",\"city\":\"Y\",\"eventDate\":\"20/11/2026\",\"capacity\":10}"
echo.
echo ---- 12. POST JSON quebrado
curl -s -i -X POST %URL%/events -H "Content-Type: application/json" -d "{\"name\":"
echo.
echo ---- 13. POST sem Content-Type JSON
curl -s -i -X POST %URL%/events -d "name=X"
echo.
echo ---- 14. POST com array
curl -s -i -X POST %URL%/events -H "Content-Type: application/json" -d "[1,2]"
echo.
echo ---- 15. DELETE /events/1
curl -s -i -X DELETE %URL%/events/1
echo.
echo ---- 16. GET /events/1 depois do delete
curl -s -i %URL%/events/1
echo.
echo ---- 17. GET /events final
curl -s -i %URL%/events
echo.
echo ---- 18. PUT /events/2 metodo nao registrado
curl -s -i -X PUT %URL%/events/2
echo.
echo ==== fim
) > "%LOG%" 2>&1

taskkill /im EventApi.exe /f >nul 2>&1
