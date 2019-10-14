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
        $packToolInstallPath,

        [bool]
        $ForcedDownload
    )

    begin {
        $toolPath = Get-Item $packToolInstallPath | Select-Object -ExpandProperty DirectoryName
        $original = Join-Path -Path $toolPath -ChildPath 'chocolateyInstall_old.ps1'
    }

    process {
        if ($ForcedDownload) {
            Invoke-Expression -Command $packToolInstallPath
        }
        else {
            if (-Not (Test-Path $original)) {
                Invoke-Expression -Command $packToolInstallPath
            }
            else {
                # Script has already been executed
                Write-Log "Scripts were already overridden, no need to do it again."
                return
            }
        }
    }

    end {
    }
}