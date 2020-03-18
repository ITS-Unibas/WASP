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
        if (-Not $ChocoPath) {
            Write-Log "Chocolatey seems not to be installed, please run 'Register-ChocolateyPackagingServer' first."
            return
        }

        $ChocoHelperPath = Join-Path -Path $ChocoPath -ChildPath "helpers"
        $ChocoFunctionsPath = Join-Path -Path $ChocoHelperPath -ChildPath "functions"
        Get-ChildItem $ChocoFunctionsPath -Filter "Install*" | Foreach-Object { Rename-Item $_.FullName "$($_.FullName).old" }
        Import-Module "$ChocoHelperPath\chocolateyInstaller.psm1" -Force
        Get-ChildItem $ChocoFunctionsPath -Filter "Install*" | Foreach-Object { Rename-Item $_.FullName "$($_.FullName.replace('.old', ''))" }
        [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'
    }

}
