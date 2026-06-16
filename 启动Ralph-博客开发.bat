@echo off
chcp 65001 >nul
title Ralph - Blog Auto Dev (Codex)

echo =====================================================
echo   Ralph - Blog System Auto Development
echo   AI will auto-loop to complete all 8 tasks
echo =====================================================
echo.

set OPENAI_API_KEY=sk-384fd1e4fefa6340b55b643f50d5c17665a3589ac67ea30015dc11aa8b3c58dc
set OPENAI_BASE_URL=https://sub2.12-11.cn/v1
set TERM=xterm-256color

set PROJECT_DIR=%~dp0
set MAX_ITER=15

echo [Config] ProjectDir: %PROJECT_DIR%
echo [Config] MaxIter:    %MAX_ITER%
echo.
echo Press any key to start (Ctrl+C to abort)...
pause >nul

cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "& '.\ralph.ps1' -MaxIterations %MAX_ITER% -ProjectDir '%PROJECT_DIR%'"

echo.
echo =====================================================
echo   Ralph finished.
echo   Start blog:  cd backend ^&^& node server.js
echo   Visit:       http://localhost:8942
echo =====================================================
pause
