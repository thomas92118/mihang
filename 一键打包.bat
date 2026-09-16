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
echo 未检测到 Godot 4 引擎，请先安装 Godot 4。
pause
exit /b 1

:found
if not exist "%PROJECT_DIR%\build" mkdir "%PROJECT_DIR%\build"

:: 清理旧的独立 pck 和临时残留文件（已配置为 PCK 嵌入 EXE 单文件）
if exist "%PROJECT_DIR%\build\深蓝回声.pck" del /q /f "%PROJECT_DIR%\build\深蓝回声.pck" >nul 2>&1
if exist "%PROJECT_DIR%\build\*.tmp" del /q /f "%PROJECT_DIR%\build\*.tmp" >nul 2>&1

echo ======================================================================
echo  开始打包《深蓝回声 · Abyssal Echo》Windows 可执行程序...
echo  引擎路径: !GODOT_BIN!
echo  打包模式: 嵌入 PCK 到单个 EXE
echo ======================================================================
echo.

"!GODOT_BIN!" --headless --path "." --export-release "Windows Desktop" "build/深蓝回声.exe"
set "EXIT_CODE=%errorlevel%"

if %EXIT_CODE% equ 0 goto :success

echo.
echo ======================================================================
echo  [X] 打包失败，退出码: %EXIT_CODE%
echo ======================================================================
echo.
goto :done

:success
echo.
echo ======================================================================
echo  [√] 打包成功！
echo  输出目录: %PROJECT_DIR%\build
echo  生成文件:
echo    - 深蓝回声.exe [独立单文件可执行程序，PCK 资源已内置]
echo.
echo  分发时只需将 build 目录中的 深蓝回声.exe 提供给玩家，单文件双击即可游玩。
echo ======================================================================
echo.
:done
pause
exit /b %EXIT_CODE%
