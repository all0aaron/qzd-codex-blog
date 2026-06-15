@echo off
chcp 65001 >nul
title Ralph - 博客系统自动开发 (Codex版)

echo =====================================================
echo   Ralph - 博客系统自动开发
echo   项目：魁战道博客系统（前台+后台）
echo   AI 将自动循环完成所有开发任务
echo =====================================================
echo.

rem === API 配置（与你的 Codex 配置一致）===
set OPENAI_API_KEY=sk-384fd1e4fefa6340b55b643f50d5c17665a3589ac67ea30015dc11aa8b3c58dc
set OPENAI_BASE_URL=https://sub2.12-11.cn/v1
set TERM=xterm-256color

rem === 项目目录（本文件所在目录）===
set PROJECT_DIR=%~dp0

rem === 最大迭代次数（8个任务，设置15次有余量）===
set MAX_ITER=15

echo [配置] 项目目录: %PROJECT_DIR%
echo [配置] 最大迭代: %MAX_ITER% 次
echo [说明] Ralph 将让 Codex 自动完成 prd.json 中的 8 个开发任务
echo.
echo 按任意键开始运行，Ctrl+C 可中止...
pause >nul

cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "& '.\ralph.ps1' -MaxIterations %MAX_ITER% -ProjectDir '%PROJECT_DIR%'"

echo.
echo =====================================================
echo   Ralph 运行结束
echo   查看 progress.txt 了解详情
echo   启动博客：cd backend ^&^& node server.js
echo   访问地址：http://localhost:8942
echo =====================================================
pause
