function Install-ChocolateyInstallPackage() {
    <#
    .SYNOPSIS
        This function overrides the Install-ChocolateyInstallPackage function and receives an optional filepath. It checks if the binary already exists or if it has to be downloaded first.

    .DESCRIPTION
        This function receives and saves the parameters which are given in the package script.
        If there is file parameter given the function checks if the binary exists or not. If it does not exist the VERIFICATION.txt will be checked to retrieve an url and checksums.

        With this parameters the Chocolatey Web downloader can be started and the binary can be downloaded into the tools folder of the package.
        In the end the script gets modified by calling the Edit-ChocolateyInstaller script.

    .PARAMETER all
        For further information to the parameters:
        https://github.com/chocolatey/choco/blob/master/src/chocolatey.resources/helpers/functions/Install-ChocolateyInstallPackage.ps1

    .OUTPUTS
        In general this function does not return anything, but the installer script gets modified.
    #>
    param(
        [parameter(Mandatory = $true, Position = 0)][string] $packageName,
        [parameter(Mandatory = $false, Position = 1)]
        [alias("installerType", "installType")][string] $fileType = 'exe',
        [parameter(Mandatory = $false, Position = 2)][string[]] $silentArgs = '',
        [alias("fileFullPath")][parameter(Mandatory = $false, Position = 3)][string] $file,
        [alias("fileFullPath64")][parameter(Mandatory = $false)][string] $file64,
        [parameter(Mandatory = $false)] $validExitCodes = @(0),
        [parameter(Mandatory = $false)]
        [alias("useOnlyPackageSilentArgs")][switch] $useOnlyPackageSilentArguments = $false,
        [parameter(ValueFromRemainingArguments = $true)][Object[]] $ignoredArguments
    )

    if ($file64) {
        # We got a valid paramter for our file64 Path
        # Next check whether the file exists
        Write-Log "$($packageName): We got a valid parameter for our file64 Path. Now checking whether it exists..."
        if (Test-Path $file64) {
            # The parameter we got is valid AND the binary exists.
            # This means we can ignore the installation request.
            Write-Log "$($packageName): Binary exists, ignoring installation request."
        }
        else {
            # We need to download the file, by searching the url in verification.txt
            Write-Log "$($packageName): Getting url for file64 parameter from VERIFICATION.txt"
            $searchArgs = @{
                searchFor32BitUrl = $False
                searchFor64BitUrl = $True
            }
            $url64bit = Get-UrlFromVerificationFile @searchArgs
            if (-Not $url64bit) {
                Write-Log "$($packageName): No url for 64bit file found! Exiting..." -Severity 3
                exit 1
            }
            $searchArgs = @{
                searchFor32BitChecksum = $False
                searchFor64BitChecksum = $True
            }
            $checksum64 = Get-ChecksumFromVerificationFile @searchArgs
        }
    }
    elseif ($file) {
        # We got a valid paramter for our file Path
        # Next check whether the file exists
        Write-Log "$($packageName): We got a valid paramter for our file Path. Now checking whether it exists..."
        if (Test-Path $file) {
            # The parameter we got is valid AND the binary exists.
            # This means we can ignore the installation request.
            Write-Log "$($packageName): Binary exists, ignoring installation request."
        }
        else {
            # We need to download the file, by searching the url in verification.txt
            Write-Log "$($packageName): First checking for a 64-bit url in VERIFICATION.txt"
            $searchArgs = @{
                searchFor32BitUrl = $False
                searchFor64BitUrl = $True
            }
            $url64bit = Get-UrlFromVerificationFile @searchArgs
            if (-Not $url64bit) {
                Write-Log "$($packageName): No url for 64bit file found! Looking for 32 bit." -Severity 3
                Write-Log "$($packageName): Getting url for file parameter from VERIFICATION.txt"
                $searchArgs = @{
                    searchFor32BitUrl = $True
                    searchFor64BitUrl = $False
                }
                $url = Get-UrlFromVerificationFile @searchArgs
                if (-Not $url) {
                    Write-Log "$($packageName): No url for 32bit file found! Exiting..." -Severity 3
                    exit 1
                }
                $searchArgs = @{
                    searchFor32BitChecksum = $True
                    searchFor64BitChecksum = $False
                }
                $checksum = Get-ChecksumFromVerificationFile @searchArgs
            }
            else {
                $searchArgs = @{
                    searchFor32BitChecksum = $False
                    searchFor64BitChecksum = $True
                }
                $checksum64 = Get-ChecksumFromVerificationFile @searchArgs
            }
        }
    }
    else {
        # We got no file/file64 parameter.
        #This means we need to get the url from VERIFICATION.txt and download
        Write-Log "$($packageName): Getting url from VERIFICATION.txt"
        $searchArgs = @{
            searchFor32BitUrl = $False
            searchFor64BitUrl = $True
        }
        $url64bit = Get-UrlFromVerificationFile @searchArgs
        if (-Not $url64bit) {
            Write-Log "$($packageName): No url64bit for file found! Searching for url32bit"
            $searchArgs = @{
                searchFor32BitUrl = $True
                searchFor64BitUrl = $False
            }
            $url = Get-UrlFromVerificationFile @searchArgs
            if (-Not $url) {
                Write-Log "$($packageName): No urls found. Exiting." -Severity 3
                exit 1
            }
        }
        if ($url64bit) {
            # We found a 64bit url which means we need to search for a 64bit checksum
            $searchArgs = @{
                searchFor32BitChecksum = $False
                searchFor64BitChecksum = $True
            }
            $checksum64 = Get-ChecksumFromVerificationFile @searchArgs
            if (-Not $checksum64) {
                # In case we couldn't find a 64bit checksum we try to find a 32bit one
                Write-Log "$($packageName): Could not find a checksum for 64 bit" -Severity 3
                exit 1
            }
        }
        else {
            # We found a 32bit url which means we need to search for a 32bit checksum
            $searchArgs = @{
                searchFor32BitChecksum = $True
                searchFor64BitChecksum = $False
            }
            $checksum = Get-ChecksumFromVerificationFile @searchArgs
            if (-Not $checksum) {
                Write-Log "$($packageName): Could not find a checksum for 32 bit" -Severity 3
                exit 1
            }
        }
    }

    $downloadFilePath = Join-Path (Join-Path (Get-Item -Path ".\").FullName "tools") "$($packageName)Install.$fileType"
    $checksumType = Get-ChecksumTypeFromVerificationFile -Checksums $checksum, $checksum64
    $checksumType64 = $checksumType
    if ($url -or $url64bit) {
        $FilePath = Get-ChocolateyWebFile -PackageName $packageName `
            -FileFullPath $downloadFilePath `
            -Url $url `
            -Url64bit $url64bit `
            -Checksum $checksum `
            -ChecksumType $checksumType `
            -Checksum64 $checksum64 `
            -ChecksumType64 $checksumType64 `
            -Options $options `
            -GetOriginalFileName
    }
    $FileName = Get-item $FilePath | Select-Object -ExpandProperty Name
    Edit-ChocolateyInstaller -ToolsPath (Join-Path (Get-Item -Path ".\").FullName "tools") -FileName $FileName
    exit 0
}