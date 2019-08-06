function Register-ChocolateyPackagingServer {
<#
   .SYNOPSIS
    Setup a new Chocolatey Packaging Server
   .DESCRIPTION
    Setup a new Chocolatey Packaging Server with all the stuff you need for doing sick packaging
   .NOTES
    FileName: Register-ChocolateyPackagingServer.ps1
    Author: Kevin Schaefer
    Contact: its-wcs-ma@unibas.ch
    Created: 2019-07-31
    Updated: 2019-07-31
    Version: 1.0.0
   .EXAMPLE
    PS>
   .LINK
#>

[cmdletbinding()]
param()

begin {
    $Config = Read-ConfigFile
} process{
    Write-Log "Starting to setup the chocolatey packaging server." -Severity 1

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
      Write-Error -Message "You need administrator rights to execute these operations" -Category AuthenticationError -Exception ([System.NotSupportedException]::new())
      return
    }
    
    # Install chocolatey
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | ForEach-Object {Write-Log $_}
    # TODO: Check if chocolatey was installed

    Request-GitRepo -User $Config.Application.GitServiceUser -GitRepo $Config.Application.PackagesIncomingAll -CloneDirectory $Config.Application.BaseDirectory -WithSubmodules
    Request-GitRepo -User $Config.Application.GitServiceUser -GitRepo $Config.Application.PackagesIncomingFiltered -CloneDirectory $Config.Application.BaseDirectory
    Request-GitRepo -User $Config.Application.GitServiceUser -GitRepo $Config.Application.WindowsSoftware -CloneDirectory $Config.Application.BaseDirectory
    # TODO: Why ist this repo cloned? When you install chocolatey you get all the helpers for free, will have further checks while going on with the refactoring
    Request-GitRepo -User $Config.Application.GitServiceUser -GitRepo $Config.Application.ChocoRepo -CloneDirectory $Config.Application.BaseDirectory    
    Request-GitRepo -User $Config.Application.GitServiceUser -GitRepo $Config.Application.JiraObserver -CloneDirectory $Config.Application.BaseDirectory

    # TODO: ErrorHandling
} end {
    Write-Log "Finished to setup the chocolatey packaging server." -Severity 1
}

}
