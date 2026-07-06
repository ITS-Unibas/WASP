function Initialize-Prerequisites {
    <#
    .SYNOPSIS
    Imports and sets all needed components
    .DESCRIPTION
    Imports chocolatey helper functions and manages securityprotocols
    .NOTES
        FileName: Initialize-Prerequisites.ps1
        Author: Kevin Schaefer, Maximilian Burgert, Tim Koenigl, Molnar Uwe 
        Contact: its-wcs-ma@unibas.ch
        Created: 2019-08-05
        Updated: 2026-07-06
        Version: 1.1.0
    .EXAMPLE
        PS> Initialize-Prequisites
    .LINK
    #>
    begin {
        $ChocoPath = $env:ChocolateyInstall
        if (-Not $ChocoPath) {
            Write-Log "Chocolatey seems not to be installed, please run 'Register-ChocolateyPackagingServer' first." -Severity 3
            return
        }

        $ChocoHelperPath = Join-Path -Path $ChocoPath -ChildPath "helpers"
        $ChocoFunctionsPath = Join-Path -Path $ChocoHelperPath -ChildPath "functions"

        $config = Read-ConfigFile
		$chocoFunctionsToOverride = $config.Application.ChocoFunctionsToOverride
    }
    
    process {					
		$scriptsToOverride = foreach ($chocoFunctionToOverride in $chocoFunctionsToOverride) {Get-ChildItem .\ -Filter $chocoFunctionToOverride}
			
		# Check each script that needs to be overridden if it exists and remove the corresponding .old-file if available
		foreach ($scriptToOverride in $scriptsToOverride){
			$scriptToOverrideOld = $scriptToOverride.PSChildName + ".old"
			Get-ChildItem $ChocoFunctionsPath -Filter $scriptToOverrideOld | Remove-Item -ErrorAction SilentlyContinue
		}
			
		# Rename all original scripts that should be overridden
		$scriptsToOverride | Foreach-Object { Rename-Item $_.FullName "$($_.FullName).old" -Force}
			
		# Now import everything except the files we do not want
		Import-Module "$ChocoHelperPath\chocolateyInstaller.psm1" -Force
			
		# Set up the initial configuration
		Get-ChildItem $ChocoFunctionsPath -Filter "*.old" | Foreach-Object { Rename-Item $_.FullName "$($_.FullName.replace('.old', ''))" -Force}

        # Setup security Protocols
        [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'
    }

}
