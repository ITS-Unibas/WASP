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
        $script:remoteFilePresent = $false
        # Check if package is using remote files
        $InstallerContent = Get-Content -Path $original -ErrorAction SilentlyContinue
        $InstallerContent | ForEach-Object { if ($_ -match "remoteFile.*=.*\`$true") {
                Write-Log "Package uses remote files."
                $script:remoteFilePresent = $true
            } }
        if ($ForcedDownload -and (-Not $script:remoteFilePresent)) {
            Invoke-Expression -Command $packToolInstallPath
        }
        else {
            if (-Not (Test-Path $original)) {
                Invoke-Expression -Command $packToolInstallPath
            }
            else {
                # Script has already been executed
                # Check if binary files exist, invoke expression to download otherwise
                $extendedToolsPath = Join-Path $toolPath '*'
                Write-Log "Searching for binaries in path $extendedToolsPath"
                if ($script:remoteFilePresent) {
                    Write-Log "Do not override again or download any binaries."
                    return
                }
                elseif ((Test-Path -Path $extendedToolsPath -Filter *.exe) -or (Test-Path -Path $extendedToolsPath -Filter *.msi) -or (Test-Path -Path $extendedToolsPath -Filter *.zip)) {
                    Write-Log "Scripts were already overridden, no need to do it again."
                    return
                }
                else {
                    Write-Log "No binaries were found, start override."
                    Invoke-Expression -Command $packToolInstallPath
                }
            }
        }

    }

    end {
    }
}