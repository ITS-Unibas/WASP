<#
  .SYNOPSIS
    This function checks if a package has alreday been overridden and if so, does not override it again. Otherwise it will run the install script at the given path.

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
function Start-OverrideFunctionForPackage($packToolInstallPath) {
    # TODO: might not be useful to have it in this additional function!
    $original = '.\chocolateyInstall_old.ps1'
    Set-Location ([System.IO.Path]::GetDirectoryName($packToolInstallPath))
    if(Test-Path $original){
      # Script has already been executed
      Write-Log "Scripts were already overridden, no need to do it again."
      return
    }
    Invoke-Expression -Command $packToolInstallPath
  }