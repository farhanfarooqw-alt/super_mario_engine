@echo off
"%LOCALAPPDATA%\bin\NASM\nasm.exe" -f bin src\test_p2.asm -o TESTP2.COM -w+all -w-reloc-abs-word
if errorlevel 1 (echo BUILD FAILED) else (echo BUILD OK)
pause
