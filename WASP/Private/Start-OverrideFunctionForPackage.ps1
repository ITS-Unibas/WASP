function Start-OverrideFunctionForPackage {
    <#
    .SYNOPSIS
        This script is called to run the install script of a package. There are three different install functions that are overwritten.

    .DESCRIPTION
        When this script is called with a ChocolateyInstall.ps1 script the script is run normally and when the script reaches one of the three
        overwritten install functions we can intersect and do our own settings to adapt the package to our workflow

        The overwritten install functions are:
        - Install-ChocolateyPackage
        - Install-ChocolateyInstallPackage
        - Install-ChocolateyZipPackage

        What exactly each overwritten function does can be read in each functions description.
    #>
    [CmdletBinding()]
    param (
        [string]
        $packToolInstallPath
    )

    begin {
        $original = '.\chocolateyInstall_original.ps1'
    }

    process {
        # TODO: Check if a location switch is needed when executing chocos 'install' functions
        # Set-Location $packToolInstallPath
        if (!(Test-Path $original)) {
            Invoke-Expression -Command $packToolInstallPath
        }
        else {
            # Script has already been executed
            Write-Log "Scripts were already overridden, no need to do it again."
            return
        }
    }

    end {
    }
}