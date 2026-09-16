@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

cd /d "%~dp0"
set "PROJECT_DIR=%CD%"
set "GODOT_BIN="

:: 1. 检查当前目录下是否有 godot*.exe
for %%f in ("%PROJECT_DIR%\godot*.exe" "%PROJECT_DIR%\Godot*.exe") do (
    if exist "%%f" (
        set "GODOT_BIN=%%f"
        goto :found
    )
)

:: 2. 检查 .tools 目录下是否有 godot*.exe
for %%f in ("%PROJECT_DIR%\.tools\godot*.exe" "%PROJECT_DIR%\.tools\Godot*.exe") do (
    if exist "%%f" (
        set "GODOT_BIN=%%f"
        goto :found
    )
)

:: 3. 检查系统 PATH 中的 godot / Godot
where godot >nul 2>&1
if %errorlevel% equ 0 (
    for /f "delims=" %%i in ('where godot') do (
        set "GODOT_BIN=%%i"
        goto :found
    )
)

:: 4. 检查 WinGet 默认安装路径
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages" (
    for /d %%p in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*") do (
        for %%f in ("%%p\Godot*win64.exe" "%%p\Godot*.exe" "%%p\godot*.exe") do (
            if exist "%%f" (
                set "GODOT_BIN=%%f"
                goto :found
            )
        )
    )
)

:: 5. 检查常见 Program Files 路径
if exist "%ProgramFiles%\Godot" (
    for %%f in ("%ProgramFiles%\Godot\Godot*.exe" "%ProgramFiles%\Godot\godot*.exe") do (
        if exist "%%f" (
            set "GODOT_BIN=%%f"
            goto :found
        )
    )
)

:not_found
echo.
echo ======================================================================
echo  未检测到 Godot 4 引擎！
echo ======================================================================
echo.
echo 运行《深蓝回声 · Abyssal Echo》需要 Godot 4 (标准版)。
echo.
echo 请选择以下任一方式获取引擎：
echo.
echo   [方式 1] 命令行一键安装 (推荐):
echo           打开终端并执行: winget install GodotEngine.GodotEngine
echo.
echo   [方式 2] 官网绿色免安装版:
echo           访问 https://godotengine.org/download/windows/
echo           下载 Godot 4 Standard 64-bit，解压后将 godot.exe
echo           放入本项目根目录或添加到系统环境变量 PATH 中。
echo.
echo ======================================================================
echo.
pause
exit /b 1

:found
:: 首次运行或缺少导入缓存时自动执行资产导入
if not exist "%PROJECT_DIR%\.godot\imported" (
    echo [1/2] 首次运行，正在自动导入 3D 资产和材质，请稍候...
    "!GODOT_BIN!" --headless --path "." --import
    echo 资产导入完成！
    echo.
)

echo 正在启动《深蓝回声 · Abyssal Echo》...
echo 引擎路径: !GODOT_BIN!
"!GODOT_BIN!" --path "." %*
set "EXIT_CODE=%errorlevel%"
if %EXIT_CODE% neq 0 (
    echo.
    echo 游戏退出，退出码: %EXIT_CODE%
    pause
)
exit /b %EXIT_CODE%
