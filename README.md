# Powershell

This repository is a showcase of some of the PowerShell work I do, including automation, reporting, and operational tooling.

## Repository Contents

- `Microsoft`
  - `Graph/Get-StaleNodes.ps1` contains a Microsoft Graph-based stale device reporting script.
  - `Hyper-V/Get-Hyper-VHealthReport.ps1` contains a Hyper-V health reporting script.
- `Monitoring`
  - `Get-NetworkHealthCheck.ps1` runs connectivity, replication, share access, file copy, and internet speed checks.
- `MorningChecks`
  - `Start-MorningChecks.ps1` is the main entry point for the daily checks workflow.
  - `Set-ServiceAccountPassword.ps1` stores the encrypted service-account password used by the reporting workflow.
  - `Get-DailyReport.cmd` and `Get-DailyReport-PDQ.cmd` provide command-based launch points for the morning checks process.
  - `Config` contains `devices.psd1`, `settings.psd1`, and `sites.psd1` for environment-specific configuration.
  - `Logs` stores timestamped runtime log files and includes a local README describing the log format.
  - `Modules` contains the reusable components that power the report:
    - `MorningChecks.AD`
    - `MorningChecks.DiskSpace`
    - `MorningChecks.Email`
    - `MorningChecks.HtmlReport`
    - `MorningChecks.Logging`
    - `MorningChecks.Network`
    - `MorningChecks.SharePoint`
    - `MorningChecks.VMware`
    - `MorningChecks.WindowsUpdate`
- `Templates`
  - `Invoke-TemplateTask.ps1` provides a reusable script pattern for parameters, reporting, and optional email delivery.
- `WSL`
  - `Install-WSL.ps1` enables WSL and installs an Ubuntu distribution.
  - `Update-WSL.ps1` checks the installed WSL version and runs `wsl --update` when a newer release is available.

## Purpose

The goal of this repository is to share examples of how I structure PowerShell scripts for real-world administration tasks while keeping published code safe, readable, reusable, and suitable for others to learn from or adapt.

Current areas covered in the repository include Microsoft platform reporting, network health checks, a modular morning-checks reporting solution, reusable script templates, and WSL setup and maintenance.

The content in this repository should be used at your own risk and reviewed before use in your own environment.

The writing style and implementation approach will vary across scripts to showcase different ways to write and structure PowerShell code.

Some folders are still being reorganized and standardized. As part of that work, environment-specific values, exported report data, and internal-only details are being removed or replaced with generic examples where appropriate.

Where scripts generate output files such as CSV or JSON reports, those outputs are intended to stay local rather than be committed back into the repository.

## Contact

Name: Abdel Denideni

Email: [a.denideni@hotmail.com](mailto:a.denideni@hotmail.com)
