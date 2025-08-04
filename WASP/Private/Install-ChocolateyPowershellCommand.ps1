function Install-ChocolateyPowershellCommand() {
    <#
    .SYNOPSIS
        This function receives an url and checksums to download the package binary and overrides the Install-ChocolateyPowershellCommand function.

    .DESCRIPTION
        This function receives and saves the parameters which are given in the package script.
        With this parameters the Chocolatey Web downloader can be started and the binary can be downloaded into the tools folder of the package.
        Prior to this step the script gets modified by calling the Edit-ChocolateyInstaller script.

    .PARAMETER all
        For further information to the parameters:
        https://github.com/chocolatey/choco/blob/stable/src/chocolatey.resources/helpers/functions/Install-ChocolateyPowershellCommand.ps1

    .OUTPUTS
        In general this function does not return anything, but the installer script gets modified s.t. it runs with a binary instead an url.
    #>
    param(
        [parameter(Mandatory = $false, Position = 0)][string] $packageName,
        [alias("file", "fileFullPath")][parameter(Mandatory = $true, Position = 1)][string] $psFileFullPath,
        [parameter(Mandatory = $false, Position = 2)][string] $url = '',
        [parameter(Mandatory = $false, Position = 3)]
        [alias("url64")][string] $url64bit = '',
        [parameter(Mandatory = $false)][string] $checksum = '',
        [parameter(Mandatory = $false)][string] $checksumType = '',
        [parameter(Mandatory = $false)][string] $checksum64 = '',
        [parameter(Mandatory = $false)][string] $checksumType64 = '',
        [parameter(Mandatory = $false)][hashtable] $options = @{Headers = @{} },
        [parameter(ValueFromRemainingArguments = $true)][Object[]] $ignoredArguments
    )

    $downloadFilePath = Join-Path (Join-Path (Get-Item -Path ".\").FullName "tools") "$($packageName)Install.ps1"

    # Check the url found above ($url or $url64bit) and download the file. url64bit is preferred over url32 bit!
    $urlFound = ''
    
    if ($url64bit -ne '' -and $null -ne $url64bit) {
        $urlFound = $url64bit
    } elseif ($url -ne '' -and $null -ne $url) {
        $urlFound = $url
    }

    if ($urlFound -eq ''){
        Write-Log "No url in Package found - Stop! url64bit: $url64bit, url: $url" -Severity 3
        exit 1
    }

    Write-Log "Found the following URL: $urlFound" -Severity 1

    Write-Log "Start editing chocolateyInstall..." -Severity 1
    
    $defaultFileName = $urlFound.Split("/")[-1]
    $fileName = Get-WebFileName -url $urlFound -defaultName $defaultFileName

    if ($FileItem.Extension -eq '.zip') {
        # If it is a zip package the file param should be provided but not as fullpath, just the main packages name
        $FileName = $file
    }

    Edit-ChocolateyInstaller -ToolsPath (Join-Path (Get-Item -Path ".\").FullName "tools") -FileName $fileName
    New-Item -Path (Join-Path (Join-Path (Get-Item -Path ".\").FullName "tools") "overridden.info") -Force

    if ($url -or $url64bit) {
        # Get-ChocolateyWebFile works like this: url64bit is preferred over url32 bit!
        $null = Get-ChocolateyWebFile -PackageName $packageName `
            -FileFullPath $downloadFilePath `
            -Url $url `
            -Url64bit $url64bit `
            -Checksum $checksum `
            -ChecksumType $checksumType `
            -Checksum64 $checksum64 `
            -ChecksumType64 $checksumType64 `
            -Options $options `
            -GetOriginalFileName `
            -ForceDownload
    } else {
        Write-Log "No url in install script of $packageName found. Skip."
    }
    exit 0
}
