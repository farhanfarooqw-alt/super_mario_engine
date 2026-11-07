@echo off
"%LOCALAPPDATA%\bin\NASM\nasm.exe" -f bin src\mario.asm -o MARIO.COM -w+all -w-reloc-abs-word
if errorlevel 1 (echo BUILD FAILED) else (echo BUILD OK)
pause