function Register-ChocolateyServer {
<#
   .SYNOPSIS
    Setup a new Chocolatey Server
   .DESCRIPTION
    Setup a new Chocolatey Server with all the stuff you need for doing sick packaging
   .NOTES
    FileName: Register-ChocolateyServer.ps1
    Author: schaefek
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
    Write-Log "Starting to setup the chocolatey server." -Severity 1
    Request-GitRepo -User $Config.Application.GitServiceUser -GitRepo $Config.Application.PackagesIncomingAll -CloneDirectory $Config.Application.BaseDirectory -WithSubmodules
    Request-GitRepo -User $Config.Application.GitServiceUser -GitRepo $Config.Application.PackagesIncomingFiltered -CloneDirectory $Config.Application.BaseDirectory
    Request-GitRepo -User $Config.Application.GitServiceUser -GitRepo $Config.Application.WindowsSoftware -CloneDirectory $Config.Application.BaseDirectory
    Request-GitRepo -User $Config.Application.GitServiceUser -GitRepo $Config.Application.ChocoRepo -CloneDirectory $Config.Application.BaseDirectory    
    Request-GitRepo -User $Config.Application.GitServiceUser -GitRepo $Config.Application.JiraObserver -CloneDirectory $Config.Application.BaseDirectory

    # TODO: Porting Set-Profile
    # TODO: Install chocolatey while setting up server
    # TODO: ErrorHandling
} end {
    Write-Log "Finished to setup the chocolatey server." -Severity 1
}

}
