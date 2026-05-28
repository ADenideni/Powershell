

#Enable the Feature (Reboot required)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

#Download Linux OS
Invoke-WebRequest -Uri https://aka.ms/wslubuntu2004 -OutFile Ubuntu.appx -UseBasicParsing

#Add Linux Feature
Add-AppxPackage .\Ubuntu.appx

dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

#Set Distribution Level
wsl --set-default-version 2

powershell.exe -executionpolicy Bypass -nologo -noninteractive -windowstyle hidden -command {Start-Process "C:\ProgramData\bomgar-scc*\pinuninstall.bat"}