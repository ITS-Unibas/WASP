function Install-ChocolateyPackage() {
    <#
    .SYNOPSIS
        This function overrides the Install-ChocolateyPackage function and receives an url and checksums to download the package binary.

    .DESCRIPTION
        This function receives and saves the parameters which are given in the package script.
        With this parameters the Chocolatey Web downloader can be started and the binary can be downloaded into the tools folder of the package.
        In the end the script gets modified by calling the Edit-ChocolateyInstaller script.

    .PARAMETER all
        For further information to the parameters:
        https://github.com/chocolatey/choco/blob/master/src/chocolatey.resources/helpers/functions/Install-ChocolateyPackage.ps1

    .OUTPUTS
        In general this function does not return anything, but the installer script gets modified s.t. it runs with a binary instead an url.
    #>
    param(
        [parameter(Mandatory = $true, Position = 0)][string] $packageName,
        [parameter(Mandatory = $false, Position = 1)]
        [alias("installerType", "installType")][string] $fileType = 'exe',
        [parameter(Mandatory = $false, Position = 2)][string[]] $silentArgs = '',
        [parameter(Mandatory = $false, Position = 3)][string] $url = '',
        [parameter(Mandatory = $false, Position = 4)]
        [alias("url64")][string] $url64bit = '',
        [parameter(Mandatory = $false)] $validExitCodes = @(0),
        [parameter(Mandatory = $false)][string] $checksum = '',
        [parameter(Mandatory = $false)][string] $checksumType = '',
        [parameter(Mandatory = $false)][string] $checksum64 = '',
        [parameter(Mandatory = $false)][string] $checksumType64 = '',
        [parameter(Mandatory = $false)][hashtable] $options = @{Headers = @{ } },
        [alias("fileFullPath")][parameter(Mandatory = $false)][string] $file = '',
        [alias("fileFullPath64")][parameter(Mandatory = $false)][string] $file64 = '',
        [parameter(Mandatory = $false)]
        [alias("useOnlyPackageSilentArgs")][switch] $useOnlyPackageSilentArguments = $false,
        [parameter(Mandatory = $false)][switch]$useOriginalLocation,
        [parameter(ValueFromRemainingArguments = $true)][Object[]] $ignoredArguments
    )

    # Check the url found above ($url or $url64bit) and download the file
    if ($null -ne $url) {
        $urlFound = $url
    } elseif ($null -ne $url64bit) {
        $urlFound = $url64bit
    }    

    Write-Log "Start editing chocolateyInstall..." -Severity 1
    
    $defaultFileName = $urlFound.Split("/")[-1]
    $fileName = Get-WebFileName -url $urlFound -defaultName $defaultFileName

    if ($FileItem.Extension -eq '.zip') {
        # If it is a zip package the file param should be provided but not as fullpath, just the main packages name
        $FileName = $file
    }

    Edit-ChocolateyInstaller -ToolsPath (Join-Path (Get-Item -Path ".\").FullName "tools") -FileName $FileName

    if ($url -or $url64bit) {
        $downloadFilePath = Join-Path (Join-Path (Get-Item -Path ".\").FullName "tools") "$($packageName)Install.$fileType"
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
