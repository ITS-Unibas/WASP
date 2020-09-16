function Edit-ChocolateyInstaller {
    <#
    .SYNOPSIS
        This function is called to modify the install script after the binaries and all dependencies have been downloaded to adpat it to our workflow.
    .DESCRIPTION
        In this function the original InstallScript gets renamed to "chocolateyInstall_old.ps1" and a copy of it is modified and replaces it as original file for our workflow.
        The changes made are that the path and checksum fields are generalized s.t. in the InstallScript always a binary will be executed and the path to it is specified.
    .NOTES
        FileName: Edit-ChocolateyInstaller.ps1
        Author: Kevin Schaefer, Maximilian Burgert, Tim Koenigl
        Contact: its-wcs-ma@unibas.ch
        Created: 2019-08-07
        Updated: 2020-02-18
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ToolsPath,

        [Parameter(Mandatory = $false)]
        [string]
        $FileName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $UnzipPath
    )

    begin {
        $Config = Read-ConfigFile
        $NewFile = Join-Path -Path $ToolsPath -ChildPath "chocolateyInstall.ps1"
        $OriginalFile = Join-Path -Path $ToolsPath -ChildPath "chocolateyInstall_old.ps1"
        $ParentSWDirectory = Split-Path (Split-Path -Path $ToolsPath)
        $PreAdditionalScripts = $Config.Application.PreAdditionalScripts
        $PostAddtionalScripts = $Config.Application.PostAdditionalScripts
    } process {
        try {
            Copy-Item -Path $NewFile -Destination $OriginalFile -ErrorAction Stop
            #Regex
            $URLRegex = '.*url.*' #replace url
            $ChecksumRegex = '.*checksum.*' # replace checksum
            $RemoteFileRegex = '.*remoteFile.*' # replace remoteFile

            $InstallerContent = Get-Content -Path $NewFile -ErrorAction Stop

            # Remove all comments in the template
            $InstallerContent = $InstallerContent | Where-Object { $_ -notmatch "^\s*#" } | ForEach-Object { $_ -replace '(^.*?)\s*?[^``]#.*', '$1' } #| Set-Content -Path $NewFile

            $script:FilePathPresent = $false
            $script:RemoteFilePresent = $false

            $InstallerContent | ForEach-Object { if ($_ -match "remoteFile.*=.*\`$true") { $script:RemoteFilePresent = $true } }

            # Do not remove url and checksum if a remote file is available
            if (-Not $script:RemoteFilePresent) {
                $InstallerContent = $InstallerContent | Where-Object { $_ -notmatch $URLRegex -and $_ -notmatch $ChecksumRegex }  #| Set-Content -Path $NewFile
            }
            else {
                Write-Log "Package uses remote files, url and checksums are not removed." -Severity 1
                $InstallerContent = $InstallerContent | Where-Object { $_ -notmatch $RemoteFileRegex }
            }
            $InstallerContent = $InstallerContent | Where-Object { $_.trim() -ne "" }

            # Check if filepath already present
            $InstallerContent | ForEach-Object {
                if ($_ -match '(file[\s]*=)') {
                    $script:FilePathPresent = $true
                }
            }
            # if filepath is not already present, we have to set the filepath
            if (-Not $script:FilePathPresent) {
                Write-Log "Calling Set File Path with path $ToolsPath" -Severity 1
                $script:ToolsPathPresent = $false
                $script:ToolsDirPresent = $false
                $InstallerContent | ForEach-Object {
                    if ($_ -match '(\$toolsPath =)') {
                        $script:FilePathPresent = $true
                    }
                    if ($_ -match '(\$toolsDir =)') {
                        $script:ToolsDirPresent = $true
                    }
                }

                $InstallerContent = $InstallerContent | ForEach-Object {
                    $_
                    if ($_ -match "packageArgs = @") {
                        if ($script:ToolsPathPresent) {
                            "  file          = (Join-Path `$toolsPath '$FileName')"
                        }
                        elseif ($script:ToolsDirPresent) {
                            "  file          = (Join-Path `$toolsDir '$FileName')"
                        }
                        elseif (-Not $script:RemoteFilePresent) {
                            "  file          = (Join-Path `$PSScriptRoot '$FileName')"
                        }
                    }
                }
            }

            # If a remote file is available, unzip path is empty
            if ($UnzipPath -and (-Not $script:RemoteFilePresent)) {
                Write-Log "Calling set unzip location and remove installzip, got unzip location $UnzipPath" -Severity 1
                $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace '.*unzipLocation[\s]*=[\s]*Get-PackageCacheLocation', "unzipLocation = $UnzipPath" }
                $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace 'Install-ChocolateyZipPackage\s*@packageArgs', "Install-ChocolateyInstallPackage @packageArgs" }
            }

            # Now we're getting to check if there was already version packaged. If yes we're going to get the last version
            [string[]]$StringVersions = Get-ChildItem -Path $ParentSWDirectory -Directory | Select-Object -ExpandProperty Name # | Select-Object -ExpandProperty $_.Name # | Sort-object $_ -descending | Select-Object -First 2
            if ($StringVersions.Length -gt 1) {
                $VersionList = New-Object System.Collections.ArrayList
                $StringVersions | ForEach-Object {
                    $SplitVersion = $_.Split('.')
                    # Ensure to have minimum x.x or else ps is not able to cast
                    if ($SplitVersion -gt 1) {
                        # Loop through each version part an remove any character which is not a number, so it can be casted.
                        for ($i = 0; $i -lt $SplitVersion.Length; $i++) {
                            $SplitVersion[$i] = $SplitVersion[$i] -replace "\D+"
                        }
                    }
                    $Version = $SplitVersion -join "."
                    $null = $VersionList.Add($Version)
                }
                $VersionList.Sort()
                $VersionList.Reverse()
                $LastVersion = $VersionList[1]
                Write-Log ("Previous version of package found: " + $VersionList[1]) -Severity 1
            }

            # Fetch the additional scripts and configs from the last version
            $AdditionalScripts = $PreAdditionalScripts + $PostAddtionalScripts
            if ($LastVersion) {
                $LastVersionPath = Join-Path -Path $ParentSWDirectory -ChildPath "$LastVersion\tools"
                $files = Get-ChildItem $LastVersionPath | Select-Object -ExpandProperty FullName
                foreach ($file in $files) {
                    # Fetch all files except the install/uninstallscripts from the last version
                    if (!($file -like "*chocolateyInstall.ps1*" -or $file -like "*chocolateyInstall_old.ps1*" -or $file -like "*.msi*" -or $file -like "*.exe*")) {
                        Copy-item $file -Destination $ToolsPath -Force -Recurse
                    }
                }
            }

            # Create additional scripts if not yet existing
            foreach ($AdditionalScript in $AdditionalScripts) {
                $ScriptPath = Join-Path -Path $ToolsPath -ChildPath $AdditionalScript
                if (!(Test-Path $ScriptPath -ErrorAction SilentlyContinue)) {
                    $null = New-Item -Path $ScriptPath -ErrorAction SilentlyContinue
                    $null = Set-Content -Path $ScriptPath -Value '# This script is run prior/post to the installation.'
                }
            }

            # Fetch the file content raw so we can check with a regex if the additional scripts are already included
            $InstallerContentRaw = Get-Content -Path $NewFile -Raw -ErrorAction Stop

            # Build regex dynamically with all additional scripts
            $Regex = ""
            $PreInstallerLine = ""
            foreach ($PreAdditionalScript in $PreAdditionalScripts) {
                $Regex += ".*$PreAdditionalScript.*\n"
                $PreInstallerLine += "&(Join-Path `$PSScriptRoot $PreAdditionalScript)`r`n"
            }
            $Regex += "Install-Choco"
            $PostInstallerLine = ""
            foreach ($PostAdditionalScript in $PostAddtionalScripts) {
                $Regex += ".*\n.*$PostAdditionalScript.*"
                $PostInstallerLine += "`r`n&(Join-Path `$PSScriptRoot $PostAdditionalScript)"
            }
            $PostInstallerLine += "`r`n"
            $Regex = [regex]$Regex
            if (-Not $Regex.Matches($InstallerContentRaw).value) {
                if ($script:RemoteFilePresent) {
                    $InstallerLine = $InstallerContent | Where-Object { $_ -match "(I|i)nstall-Choco.*" }
                    $InstallerContent = $InstallerContent -replace $InstallerLine, "$($PreInstallerLine)$($InstallerLine)`r`n`$packageArgs.file = `$fileLocation`r`nInstall-ChocolateyInstallPackage @packageArgs`r`n$($PostInstallerLine)"
                }
                elseif ($InstallerContentRaw -match 'Install-ChocolateyZipPackage*') {
                    $InstallerLine = $InstallerContent | Where-Object { $_ -match "(I|i)nstall-Choco.*" }
                    $InstallerContent = $InstallerContent -replace $InstallerLine, "$($PreInstallerLine)Expand-Archive -Path (Join-Path `$toolsDir '$FileName') -DestinationPath `$toolsDir -Force`r`n$($InstallerLine)$($PostInstallerLine)"
                }
                else {
                    $InstallerLine = $InstallerContent | Where-Object { $_ -match "(I|i)nstall-Choco.*" }
                    $InstallerContent = $InstallerContent -replace $InstallerLine, "$($PreInstallerLine)$($InstallerLine)$($PostInstallerLine)"
                }
            }

            Set-Content -Path $NewFile -Value $InstallerContent
        }
        catch {
            Write-Log "$($_.Exception.Message)" -Severity 3
        }
    }

}
