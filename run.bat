@echo off
setlocal
cd /d "%~dp0"
set "DOSBOX=%ProgramFiles(x86)%\DOSBox-0.74-3\DOSBox.exe"
if not exist "%DOSBOX%" set "DOSBOX=%ProgramFiles%\DOSBox-0.74-3\DOSBox.exe"
if not exist "%DOSBOX%" (
    where DOSBox.exe >nul 2>&1
    if errorlevel 1 (
        echo DOSBox 0.74-3 not found. Install DOSBox or edit its path in run.bat.
        pause
        exit /b 1
    )
    set "DOSBOX=DOSBox.exe"
)
if not exist "MARIO.COM" (
    echo MARIO.COM not found. Run build.bat first.
    pause
    exit /b 1
)
if not exist "dosbox.conf" (
    echo dosbox.conf not found. Place it next to run.bat.
    pause
    exit /b 1
)
"%DOSBOX%" -conf "%~dp0dosbox.conf" -c "mount c ." -c "c:" -c "MARIO.COM" -exit
