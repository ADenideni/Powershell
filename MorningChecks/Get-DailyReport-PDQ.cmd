@REM Author: ADenideni
@REM Email: a.denideni@hotmail.com
@REM Version: 1.0.0
@REM Date: 2026-05-23

powershell.exe -ExecutionPolicy Bypass "& Set-Location '%~dp0'; .\Start-MorningChecks.ps1; exit $LASTEXITCODE"
