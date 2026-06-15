@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ========================================
echo   雨中人心理测试 — Git 一键上传
echo ========================================
echo.

:: 检查远程仓库（结果缓存，避免重复调用）
set HAS_REMOTE=0
git remote get-url origin >nul 2>&1
if %errorlevel% equ 0 set HAS_REMOTE=1

if %HAS_REMOTE% equ 0 (
    echo [!] 未配置远程仓库，当前只能本地提交
    echo     如需推送，请先: git remote add origin ^<仓库地址^>
    echo.
)

:: 输入提交信息（先于 git status，不阻塞用户）
set /p commitMsg="请输入提交信息: "
if "%commitMsg%"=="" (
    for /f "delims=" %%i in ('powershell -Command "Get-Date -Format 'yyyy-MM-dd HH:mm'"') do set commitMsg=update: %%i
)
echo [i] 提交信息: %commitMsg%

:: 显示变更
echo.
echo --- 当前变更 ---
git status --short
echo.

echo --- 执行中 ---

:: add
echo [1/3] git add -A ...
git add -A
if %errorlevel% neq 0 (
    echo [X] git add 失败
    pause
    exit /b 1
)

:: commit
echo [2/3] git commit ...
git commit -m "%commitMsg%"
if %errorlevel% neq 0 (
    echo [i] 提交被跳过 — 可能无新变更，或提交信息与上次相同
)

:: push
if %HAS_REMOTE% equ 1 (
    echo [3/3] git push ...
    git push
    if %errorlevel% neq 0 (
        echo [!] push 失败 — 请检查网络连接或远程仓库权限
    ) else (
        echo [√] 推送成功！
    )
) else (
    echo [3/3] 跳过 push — 无远程仓库
)

echo.
echo ========================================
echo   完成！按任意键关闭...
echo ========================================
pause >nul
