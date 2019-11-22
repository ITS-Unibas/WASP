function Edit-ChocolateyInstaller {
    <#
    .SYNOPSIS
        This function is called to modify the install script after the binaries and all dependencies have bin downloaded to adpat it to our workflow.
    .DESCRIPTION
        In this function the original InstallScript gets renamed to "chocolateyInstall_old.ps1" and a copy of it is modified and replaces it as original file for our workflow.
        The changes made are that the path and checksum fields are generalized s.t. in the InstallScript always a binary will be executed and the path to it is specified.
    .NOTES
        FileName: Edit-ChocolateyInstaller.ps1
        Author: Kevin Schaefer, Maximilian Burgert, Tim Koenigl
        Contact: its-wcs-ma@unibas.ch
        Created: 2019-08-07
        Updated: 2019-08-07
        Version: 1.0.0
    .PARAMETER
    .EXAMPLE
        PS>
    .LINK
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ToolsPath,

        [Parameter(Mandatory = $true)]
        [string]
        $FileName,

        [Parameter()]
        [string]
        $UnzipPath

    )

    begin {
        $NewFile = Join-Path -Path $ToolsPath -ChildPath "chocolateyInstall.ps1"
        $OriginalFile = Join-Path -Path $ToolsPath -ChildPath "chocolateyInstall_old.ps1"
        $ParentSWDirectory = Split-Path (Split-Path -Path $ToolsPath)
        $PreAdditionalScripts = $Config.Application.PreAdditionalScripts
        $PostAddtionalScripts = $Config.Application.PostAdditionalScripts
    } process {
        Copy-Item -Path $NewFile -Destination $OriginalFile
        #Regex
        $URLRegex = '.*url.*' #replace url
        $ChecksumRegex = '.*checksum.*' # replace checksum

        $InstallerContent = Get-Content -Path $NewFile

        # Remove all comments in the template
        $InstallerContent = $InstallerContent | Where-Object { $_ -notmatch "^\s*#" } | ForEach-Object { $_ -replace '(^.*?)\s*?[^``]#.*', '$1' } #| Set-Content -Path $NewFile
        $InstallerContent = $InstallerContent | Where-Object { $_ -notmatch $URLRegex -and $_ -notmatch $ChecksumRegex }  #| Set-Content -Path $NewFile
        $script:FilePathPresent = $false
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
                    else {
                        "  file          = (Join-Path `$PSScriptRoot '$FileName')"
                    }
                }
            }
        }

        if ($UnzipPath) {
            Write-Log "Calling set unzip location and remove installzip, got unzip location $UnzipPath" -Severity 1
            $InstallerContent -Replace ".*unzipLocation[\s]*=[\s]*Get-PackageCacheLocation", "unzipLocation = $UnzipPath"
            $InstallerContent -Replace "Install-ChocolateyZipPackage[\s]*=[\s]@packageArgs", ""
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
                $null = $VersionList.Add([version]$Version)
            }
            $VersionList.Sort()
            $VersionList.Reverse()
            $LastVersion = $VersionList[1]
        }

        # Fetch the additional scripts from the last version or create them from scratch
        $AdditionalScripts = $PreAdditionalScripts + $PostAddtionalScripts
        if ($LastVersion) {
            $LastVersionPath = Join-Path -Path $ParentSWDirectory -ChildPath "$LastVersion\tools"
            foreach ($AdditionalScript in $AdditionalScripts) {
                $SourcePath = Join-Path -Path $LastVersionPath -ChildPath $AdditionalScript
                $DestinationPath = Join-Path -Path $ToolsPath -ChildPath $AdditionalScript
                if (Test-Path $SourcePath -ErrorAction SilentlyContinue) {
                    Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
                }
                else {
                    $null = New-Item -Path $DestinationPath
                }
            }
        }
        else {
            foreach ($AdditionalScript in $AdditionalScripts) {
                $ScriptPath = Join-Path -Path $ToolsPath -ChildPath $AdditionalScript
                $null = New-Item -Path $ScriptPath -ErrorAction SilentlyContinue
            }
        }

        # Fetch the file content raw so we can check with a regex if the additional scripts are already included
        $InstallerContentRaw = Get-Content -Path $NewFile -Raw

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
            $InstallerLine = $InstallerContent | Where-Object { $_ -match "(I|i)nstall-Choco.*" }
            $InstallerContent = $InstallerContent -replace $InstallerLine, "$($PreInstallerLine)$($InstallerLine)$($PostInstallerLine)"
        }

        Set-Content -Path $NewFile -Value $InstallerContent
    }

}
