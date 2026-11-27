@echo off
"%LOCALAPPDATA%\bin\NASM\nasm.exe" -f bin src\test_p3.asm -o TESTP3.COM -w+all -w-reloc-abs-word
if errorlevel 1 (echo BUILD FAILED) else (echo BUILD OK)
pause