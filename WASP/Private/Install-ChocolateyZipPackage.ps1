<#
  .SYNOPSIS
    This function overrides the Install-ChocolateyZipPackage function and receives a optional filepath or an url to a zip file. Depending on the input the functions downloads and/or unzips the binaries.

  .DESCRIPTION
    This function receives and saves the parameters which are given in the package script.
    If there is file parameter given the function checks if the binary exists or not. If it does not exist and there is also no url given the VERIFICATION.txt will be checked to retrieve an url and checksums.
    If there is a url given or a url found in the VERIFICATION.txt file it will be downloaded.
    Afterwards the zip will be unpacked into the tools folder.

    In the end the script gets modified by calling the Edit-ChocolateyInstaller script.

  .PARAMETER all
    For further information to the parameters:
    https://github.com/chocolatey/choco/blob/master/src/chocolatey.resources/helpers/functions/Install-ChocolateyZipPackage.ps1

  .OUTPUTS
    In general this function does not return anything, but the installer script gets modified.
#>
function Install-ChocolateyZipPackage() {
    param(
      [parameter(Mandatory=$true, Position=0)][string] $packageName,
      [parameter(Mandatory=$false, Position=1)][string] $url = '',
      [parameter(Mandatory=$true, Position=2)]
      [alias("destination")][string] $unzipLocation,
      [parameter(Mandatory=$false, Position=3)]
      [alias("url64")][string] $url64bit = '',
      [parameter(Mandatory=$false)][string] $specificFolder ='',
      [parameter(Mandatory=$false)][string] $checksum = '',
      [parameter(Mandatory=$false)][string] $checksumType = '',
      [parameter(Mandatory=$false)][string] $checksum64 = '',
      [parameter(Mandatory=$false)][string] $checksumType64 = '',
      [parameter(Mandatory=$false)][hashtable] $options = @{Headers=@{}},
      [alias("fileFullPath")][parameter(Mandatory=$false)][string] $file = '',
      [alias("fileFullPath64")][parameter(Mandatory=$false)][string] $file64 = '',
      [parameter(ValueFromRemainingArguments = $true)][Object[]] $ignoredArguments
    )
    $fileType = 'zip'
    $downloadFilePath = Join-Path (Get-Item -Path ".\").FullName "$($packageName)Install.$fileType"
  
    $urlWasSetToFile = $False
  
    if ($url -eq '' -or $url -eq $null) {
      if ($file -and (Test-Path $file)){
        # first check whether we already have our zip file
        Write-Log "$($packageName): The zip32 package is already present and no download is needed"
        $url = $file
        $urlWasSetToFile = $True
      } else {
        # we do not have the file, so we need to get the download url from
        # VERIFICATION.txt
        Write-Log "$($packageName): Getting url for file from VERIFICATION.txt"
        $searchArgs = @{
          searchFor32BitUrl = $True
          searchFor64BitUrl = $False
        }
        $url = Get-UrlFromVerificationFile @searchArgs
  
        $searchArgs = @{
          searchFor32BitChecksum = $True
          searchFor64BitChecksum = $False
        }
        $checksum = Get-ChecksumFromVerificationFile @searchArgs
      }
    }
  
    if ($url64bit -eq '' -or $url64bit -eq $null) {
      if ($file64 -and (Test-Path $file64)){
        # first check whether we already have our zip file
        Write-Log "$($packageName): The zip64 package is already present and no download is needed"
        $url64bit = $file64
        $urlWasSetToFile = $True
      } else {
        # we do not have the file, so we need to get the download url from
        # VERIFICATION.txt
        Write-Log "$($packageName): Getting url for file64 from VERIFICATION.txt"
        $searchArgs = @{
          searchFor32BitUrl = $False
          searchFor64BitUrl = $True
        }
        $url64bit = Get-UrlFromVerificationFile @searchArgs
  
        $searchArgs = @{
          searchFor32BitChecksum = $False
          searchFor64BitChecksum = $True
        }
        $checksum64 = Get-ChecksumFromVerificationFile @searchArgs
      }
    }
    # Check if any urls were found
    if (-Not $urlWasSetToFile -And (($url -and $checksum) -or ($url64bit -and $checksum64))){
      Write-Log "$($packageName): Urls found! $url $url64bit" -Severity 1
    } else {
      Write-Log "$($packageName): No urls found! Exiting..." -Severity 3
      exit 1
    }
  
    if($checksumType -or $checksumType64){
      # Checksum was defined in install.ps1 script as parameter
      if($checksumType){
        $checksumType64 = $checksumType 
      } else {
        $checksumType = $checksumType64 
      }
    } else {
      $checksumType = Get-ChecksumTypeFromVerificationFile
      $checksumType64 = $checksumType
    }
  
    try{
      $filePath = Get-ChocolateyWebFile $packageName $downloadFilePath $url $url64bit -checkSum $checksum -checksumType $checksumType -checkSum64 $checksum64 -checksumType64 $checksumType64 -options $options -getOriginalFileName
  
      # Set Choco env variable needed by the Unzipper
      # TODO Remove hardcoded itunes path with generic package location
      $env:ChocolateyPackageFolder = "$env:ChocoCommunityRepoPath\automatic\$packageName\tools"
      $unzipLocation = $env:ChocolateyPackageFolder
      Get-ChocolateyUnzip "$filePath" $unzipLocation $specificFolder $packageName
      $outputFile = Split-Path $filePath -leaf
      Edit-ChocolateyInstaller $outputFile $unzipLocation
    } catch{
      Write-Log ($($packageName) + ":" + " " +$_.Exception.toString()) -Severity 3
      exit 1
    }
    exit 0
  }