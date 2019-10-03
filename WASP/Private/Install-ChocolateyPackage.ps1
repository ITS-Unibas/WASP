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

    $downloadFilePath = Join-Path (Get-Item -Path ".\").FullName "$($packageName)Install.$fileType"

    if ($url -or $url64bit) {
        $filePath = Get-ChocolateyWebFile -PackageName $packageName `
            -FileFullPath $downloadFilePath `
            -Url $url `
            -Url64bit $url64bit `
            -Checksum $checksum `
            -ChecksumType $checksumType `
            -Checksum64 $checksum64 `
            -ChecksumType64 $checksumType64 `
            -Options $options `
            -GetOriginalFileName
        $outputFile = Split-Path $filePath -leaf
        Write-Log "Starting editiing chocolateyInstall at $filePath."
        Edit-ChocolateyInstaller $outputFile
    }
    else {
        Write-Log "No url in install script of $packageName found. We can continue."
    }
}