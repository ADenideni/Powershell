# Powershell

This repository is a showcase of some of the PowerShell work I do, including automation, reporting, and operational tooling.

## Repository Contents

- `Microsoft` contains Azure, Microsoft Graph, Intune, Hyper-V, and compliance-related scripts, including sanitized examples for cloud administration and reporting.
- `Monitoring` contains standalone monitoring and health-check scripts, including sanitized examples that can be adapted for other environments.
- `MorningChecks` contains a daily operational reporting solution with modular checks for systems, services, updates, and infrastructure health.
- `Templates` contains reusable example scripts, including `Invoke-TemplateTask.ps1`, which shows a sanitized function pattern for parameters, logging, HTML output, and email delivery.
- `Windows-Administration` contains a broad set of Windows administration scripts for areas such as Active Directory, BitLocker, DNS, DHCP, RDP, local administration, services, file administration, and general workstation or server support.
- `WSL` contains Windows Subsystem for Linux setup and maintenance scripts.

## Purpose

The goal of this repository is to share examples of how I structure PowerShell scripts for real-world administration tasks while keeping published code safe, readable, reusable, and suitable for others to learn from or adapt.

The content in this repository should be used at your own risk and reviewed before use in your own environment.

The writing style and implementation approach will vary across scripts to showcase different ways to write and structure PowerShell code.

Some folders are still being reorganized and standardized. As part of that work, environment-specific values, exported report data, and internal-only details are being removed or replaced with generic examples where appropriate.

Where scripts generate output files such as CSV or JSON reports, those outputs are intended to stay local rather than be committed back into the repository.

## Contact

Name: Abdel Denideni

Email: [a.denideni@hotmail.com](mailto:a.denideni@hotmail.com)
