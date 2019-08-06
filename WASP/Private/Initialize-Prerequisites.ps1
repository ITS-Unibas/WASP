function Initialize-Prerequisites {
<#
   .SYNOPSIS
   Imports and sets all needed components
   .DESCRIPTION
   Imports chocolatey helper functions and manages securityprotocols
   .NOTES
    FileName: Initialize-Prerequisites.ps1
    Author: Kevin Schaefer, Maximilian Burgert, Tim Koenigl
    Contact: its-wcs-ma@unibas.ch
    Created: 2019-08-05
    Updated: 2019-08-05
    Version: 1.0.0
   .EXAMPLE
    PS> Initialize-Prequisites
   .LINK
#>

process {
    $ChocoPath = $env:ChocolateyInstall
    if(-Not $ChocoPath) {
        Write-Log "Chocolatey seems not to be installed, please run 'Register-ChocolateyServer' first."
        return
    }

    $ChocoHelperPath = Join-Path -Path $ChocoPath -ChildPath "helpers"
    Get-ChildItem -Path $ChocoHelperPath -Filter "*.psm1" | ForEach-Object {Import-Module $_.FullName}
    [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'
}

}
