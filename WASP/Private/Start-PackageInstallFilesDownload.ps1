function Start-PackageInstallFilesDownload {
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
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $packToolInstallPath,

        [ValidateNotNullOrEmpty()]
        [bool]
        $ForcedDownload
    )

    begin {
        $toolPath = Get-Item $packToolInstallPath | Select-Object -ExpandProperty DirectoryName
        $original = Join-Path -Path $toolPath -ChildPath 'chocolateyInstall_old.ps1'
    }

    process {
        $script:localFilePresent = $false
        # Check if package is using localfiles
        $InstallerContent = Get-Content -Path $original -ErrorAction SilentlyContinue
        $InstallerContent | ForEach-Object { if ($_ -match "localFile.*=.*\`$true") {
                Write-Log "Package uses local files." -Severity 1
                $script:localFilePresent = $true
            } }

        if ($ForcedDownload) {
            Write-Log "Forced download, start override." -Severity 1
            if (Test-Path $original) {
                Remove-Item $packToolInstallPath -ErrorAction SilentlyContinue
                Rename-Item $original 'chocolateyInstall.ps1' -ErrorAction SilentlyContinue
            }
            Invoke-Expression -Command $packToolInstallPath
        }
        else {
            if (-Not (Test-Path $original)) {
                Write-Log "No overriden install script found, start override." -Severity 1
                Invoke-Expression -Command $packToolInstallPath
            }
            else {
                # Script has already been executed
                # Check if binary files exist, invoke expression to download otherwise
                $extendedToolsPath = Join-Path $toolPath '*'
                Write-Log "Searching for binaries in path $extendedToolsPath"
                if ($script:localFilePresent -and ((Test-Path -Path $extendedToolsPath -Filter *.exe) -or (Test-Path -Path $extendedToolsPath -Filter *.msi) -or (Test-Path -Path $extendedToolsPath -Filter *.zip) `
                            -or (Test-Path -Path $extendedToolsPath -Filter "overridden.info"))) {
                    Write-Log "Scripts already overridden."
                    return
                }
                else {
                    Write-Log "No binaries found, start override." -Severity 1
                    Invoke-Expression -Command $packToolInstallPath
                }
            }
        }

    }

    end {
    }
}