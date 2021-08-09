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
        $UnzipPath,

        [Parameter(Mandatory = $false)]
        [string]
        $FileUrl
    )

    begin {
        $Config = Read-ConfigFile
        $NewFile = Join-Path -Path $ToolsPath -ChildPath "chocolateyInstall.ps1"
        $OriginalFile = Join-Path -Path $ToolsPath -ChildPath "chocolateyInstall_old.ps1"
        $ParentSWDirectory = Split-Path (Split-Path -Path $ToolsPath)
        $PreAdditionalScripts = $Config.Application.PreAdditionalScripts
        $PostAddtionalScripts = $Config.Application.PostAdditionalScripts

        #Regex
        $URLRegex = '.*url.*' #replace url
        $ChecksumRegex = '.*checksum.*' # replace checksum
        $LocalFileRegex = '.*localFile.*' # regex to determine if package is local package

        # get current package version
        $currentVersion = (Get-Item $ToolsPath).Parent.Name
        Write-Log "Current Version $currentVersion"
    } process {
        try {
            # Check if there was already version packaged. If yes get the last version
            $VersionHistory, $StringVersionHistory = Get-LocalPackageVersionHistory $ParentSWDirectory $currentVersion
            Write-Log "Version History: $StringVersionHistory"
            # Test if a previous chocolateyInstall file exist.
            $override = $false
            if ($VersionHistory) {
                $LastVersion = $StringVersionHistory | Where-Object { [version]$_ -eq $VersionHistory[0] }
                Write-Log "Copying previous package version: $LastVersion." -Severity 1

                Copy-Item -Path $NewFile -Destination $OriginalFile -ErrorAction Stop

                $LastVersionPath = Join-Path -Path $ParentSWDirectory -ChildPath "$LastVersion\tools"
                $prevChocolateyInstallFile = Join-Path -Path $LastVersionPath -ChildPath "chocolateyinstall.ps1"

                # search for the next preceeding version that is not in packaging to copy the install content
                # Is versionin packaging? -> Then the installfile does not exist on current dev branch and therefore cannot be copied
                $counter = 1
                while (-Not (Test-Path $prevChocolateyInstallFile) -and ($counter -lt $VersionHistory.Count)) {
                    Write-Log "$counter"
                    $counter += 1
                    $LastVersion = $StringVersionHistory | Where-Object { [version]$_ -eq $VersionHistory[$counter] }
                    $LastVersionPath = Join-Path -Path $ParentSWDirectory -ChildPath "$LastVersion\tools"
                    $prevChocolateyInstallFile = Join-Path -Path $LastVersionPath -ChildPath "chocolateyinstall.ps1"
                }
                if (-Not (Test-Path $prevChocolateyInstallFile)) {
                    $override = $True
                }
                else {
                    # Only copy file if it contains url or is a local file if no url exist
                    # Check if previous install file contains urls
                    $LocalFile = $false
                    $URLfound = $false
                    $InstallerContent | ForEach-Object { if ($_ -match "localFile.*=.*\`$true") { $LocalFile = $true } }
                    $InstallerContent | ForEach-Object { if ($_ -match ".*url.*=.*") { $URLfound = $true } }
                    if ($LocalFile -or $URLfound) {
                        Write-Log "Copying $prevChocolateyInstallFile to $ToolsPath"
                        Copy-Item $prevChocolateyInstallFile -Destination $ToolsPath -Force -Recurse

                        $InstallerContent = Get-Content -Path $NewFile -ErrorAction Stop
                    }
                    else {
                        Write-Log "Previous package is not a local package or has no url defined! File is not copied to current version" -Severity 2
                        $override = $True
                    }
                }
            }
            else {
                $override = $True
            }
            if ($override) {
                Write-Log "No previous package version found. Start overriding $NewFile."

                Copy-Item -Path $NewFile -Destination $OriginalFile -ErrorAction Stop

                $InstallerContent = Get-Content -Path $NewFile -ErrorAction Stop

                # Remove all comments in the template
                $InstallerContent = $InstallerContent | Where-Object { $_ -notmatch "^\s*#" } | ForEach-Object { $_ -replace '(^.*?)\s*?[^``]#.*', '$1' } #| Set-Content -Path $NewFile

                $script:FilePathPresent = $false
                $script:LocalFile = $false

                $InstallerContent | ForEach-Object { if ($_ -match "localFile.*=.*\`$true") { $script:LocalFile = $true } }

                # Remove url, checksum and localpackage parameter from script if package is a local package
                if ($script:LocalFile) {
                    Write-Log "Package uses local files. Url and checksums are removed from package args." -Severity 1
                    $InstallerContent = $InstallerContent | Where-Object { $_ -notmatch $URLRegex -and $_ -notmatch $ChecksumRegex }  #| Set-Content -Path $NewFile
                    $InstallerContent = $InstallerContent | Where-Object { $_ -notmatch $LocalFileRegex }
                }
                else {
                    # replace original url with given file url on repo server
                    $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace '\$url32bit[\s]*=[\s]*.*', "`$url32bit = `"$FileUrl`"" }
                    $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace 'url32bit[\s]*=[\s]*.*', "url32bit = `"$FileUrl`"" }
                    $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace '\$url64bit[\s]*=[\s]*.*', "`$url64bit = `"$FileUrl`"" }
                    $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace 'url64bit[\s]*=[\s]*.*', "url64bit = `"$FileUrl`"" }
                    $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace '\$url[\s]*=[\s]*.*', "`$url = `"$FileUrl`"" }
                    $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace 'url[\s]*=[\s]*.*', "url = `"$FileUrl`"" }
                }
                $InstallerContent = $InstallerContent | Where-Object { $_.trim() -ne "" }

            }
            # Check if filepath already present
            $InstallerContent | ForEach-Object {
                if ($_ -match '(\sfile[\s]*=)') {
                    $script:FilePathPresent = $true
                }
            }

            $script:ToolsPathPresent = $false
            $script:ToolsDirPresent = $false
            $InstallerContent | ForEach-Object {
                if ($_ -match '(\$toolsPath =)') {
                    $script:ToolsPathPresent = $true
                }
                if ($_ -match '(\$toolsDir =)') {
                    $script:ToolsDirPresent = $true
                }
            }

            # if filepath is not already present and this is not a remote file package, we have to set the filepath
            if (-Not $script:FilePathPresent -and $script:LocalFile) {
                Write-Log "Calling Set File Path with path $ToolsPath" -Severity 1

                $InstallerContent = $InstallerContent | ForEach-Object {
                    $_
                    if ($_ -match "packageArgs = @") {
                        if ($script:ToolsPathPresent) {
                            "  file          = (Join-Path `$toolsPath '$FileName')"
                        }
                        elseif ($script:ToolsDirPresent) {
                            "  file          = (Join-Path `$toolsDir '$FileName')"
                        }
                        else {
                            "  file          = (Join-Path `$PSScriptRoot '$FileName')"
                        }
                    }
                }
            }

            # If package uses local files and package is a zip package
            if ($UnzipPath -and $script:LocalFile) {
                Write-Log "Set unzip location to $UnzipPath" -Severity 1
                $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace '.*unzipLocation[\s]*=[\s]*Get-PackageCacheLocation', "unzipLocation = $UnzipPath" }
                $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace 'Install-ChocolateyZipPackage\s*@packageArgs', "Install-ChocolateyInstallPackage @packageArgs" }
            }

            # Replace fixed version and name with generic expression
            $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace '\$version[\s]*=[\s]*.*', '$version = $env:ChocolateyPackageVersion' }
            $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace '\$packageVersion[\s]*=[\s]*.*', '$version = $env:ChocolateyPackageVersion' }
            $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace '\$packageName[\s]*=[\s]*.*', '$packageName = $env:ChocolateyPackageName' }
            $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace 'packageName[\s]*=[\s]*.*', 'packageName = $env:ChocolateyPackageName' }

            if ($script:ToolsPathPresent -and $script:LocalFile) {
                $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace '\sfile[\s]*=[\s]*.*', " file = (Join-Path `$toolsPath '$FileName')" }
            }
            elseif ($script:ToolsDirPresent -and $script:LocalFile) {
                $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace '\sfile[\s]*=[\s]*.*', " file = (Join-Path `$toolsDir '$FileName')" }
            }
            elseif ($script:LocalFile) {
                $InstallerContent = $InstallerContent | ForEach-Object { $_ -replace '\sfile[\s]*=[\s]*.*', " file = (Join-Path `$PSScriptRoot '$FileName')" }
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
            $Regex += ".*Install-Choco"
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

            # Fetch the additional scripts and configs from the last version
            $AdditionalScripts = $PreAdditionalScripts + $PostAddtionalScripts
            if ($VersionHistory) {
                $LastVersion = $StringVersionHistory | Where-Object { [version]$_ -eq $VersionHistory[1] }
                $LastVersionPath = Join-Path -Path $ParentSWDirectory -ChildPath "$LastVersion\tools"
                $files = Get-ChildItem $LastVersionPath -Exclude *.msi, *.exe | Select-Object -ExpandProperty FullName

                # search for the next preceeding version that is not in packaging to copy the install content
                $counter = 1
                while (-Not ($files) -and ($counter -lt $VersionHistory.Count)) {
                    $counter += 1
                    $LastVersion = $StringVersionHistory | Where-Object { [version]$_ -eq $VersionHistory[$counter] }
                    $LastVersionPath = Join-Path -Path $ParentSWDirectory -ChildPath "$LastVersion\tools"
                    $files = Get-ChildItem $LastVersionPath -Exclude *.msi, *.exe | Select-Object -ExpandProperty FullName
                }

                # Fetch all files except the install/uninstallscripts from the last version
                foreach ($file in $files) {
                    if (!($file -like "*chocolateyInstall.ps1*" -or $file -like "*chocolateyInstall_old.ps1*")) {
                        Copy-item $file -Destination $ToolsPath -Force -Recurse
                    }
                }
            }

            # Remove zip files when remote files are present
            if ($script:RemoteFilePresent) {
                $files = Get-ChildItem $ToolsPath | Select-Object -ExpandProperty FullName
                foreach ($file in $files) {
                    # Fetch all files except the install/uninstallscripts from the last version
                    if ($file -like "*.zip*") {
                        Write-Log "Removing $file." -Severity 1
                        Remove-item $file -Force -Recurse
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
        }
        catch {
            Write-Log "$($_.Exception.Message) at line: $($_.InvocationInfo.ScriptLineNumber)" -Severity 3
        }
    }

}
