function Install-ChocolateyPowershellCommand() {
    <#
    .SYNOPSIS
        This function overrides the Install-ChocolateyPowershellCommand function and receives an url and checksums to download the package binary.

    .DESCRIPTION
        This function receives and saves the parameters which are given in the package script.
        With this parameters the Chocolatey Web downloader can be started and the binary can be downloaded into the tools folder of the package.
        In the end the script gets modified by calling the Edit-ChocolateyInstaller script.

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
        $FileItem = Get-item $filePath
        $FileName = $FileItem.Name
        if ($FileItem.Extension -eq '.zip') {
            # If it is a zip package the file param should be provided but not as fullpath, just the main packages name
            $FileName = $file
        }
        Write-Log "Starting editing chocolateyInstall at $filePath."
        Edit-ChocolateyInstaller -ToolsPath (Join-Path (Get-Item -Path ".\").FullName "tools") -FileName $FileName
    }
    else {
        Write-Log "No url in install script of $packageName found. We can continue."
    }
    exit 0
}