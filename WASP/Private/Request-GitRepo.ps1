function Request-GitRepo {
<#
   .SYNOPSIS
    Clone a git repo
   .DESCRIPTION
    Clone a git repo with specified user from a specified server
   .NOTES
    FileName: Request-GitRepo.ps1
    Author: Kevin Schaefer, Maximilian Burgert, Tim Koenigl
    Contact: its-wcs-ma@unibas.ch
    Created: 2019-07-31
    Updated: 2019-07-31
    Version: 1.0.0
   .PARAMETER
   .EXAMPLE
    PS>
   .LINK
#>
    [cmdletbinding()]
    param(
        [Parameter()]
        [string]
        $User,
        [Parameter(Mandatory=$true)]
        [string]
        $GitRepo,
        [Parameter(Mandatory=$true)]
        [string]
        $CloneDirectory,
        [Parameter()]
        [switch]
        $WithSubmodules
    )

    process{
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $GitPath = Join-Path -Path $CloneDirectory -ChildPath $GitFolderName
        if (-Not (Test-Path $GitPath)) {
            Write-Log "$GitFolderName is missing. Starting to clone it." -Severity 1
            if($User) {
                Write-Log ([string] (git clone https://$User@$GitRepo $GitPath 2>&1))
            } else {
                Write-Log ([string] (git clone https://$GitRepo $GitPath 2>&1))
            }
            if (Test-Path $GitPath) {
              if ($WithSubmodules) {
                Write-Log "Starting to init and update the submodules in $GitFolderName"
                # TODO: git submodule seems to not provide any output. So maybe remove the Write-Log there
                Write-Log ([string] (git submodule init 2>&1))
                Write-Log ([string] (git submodule update 2>&1))
              }
              Write-Log "Finished cloning $GitFolderName"
            } else {
              Write-Log "Problem while cloning $GitFolderName. Please check the log." -Severity 3
            }
          } else {
            Write-Log "$GitFolderName already exists. Nothing to do." -Severity 1
          }
    }
}
