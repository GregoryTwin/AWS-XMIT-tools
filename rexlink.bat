@echo off
assoc .rex=RexxScript
if /i $%1==$OOREXX goto OOREXX
if /i $%1==$REGINA goto REGINA
echo Parameter is missed or invalid
goto :EOF
:OOREXX
ftype RexxScript="%REXX_HOME%\rexx.exe" "%%1" %%*
goto :EOF
:REGINA
ftype RexxScript="%REGINA_HOME%\regina.exe" "%%1" %%*
goto :EOF