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
    [Parameter(Mandatory=$true)]
    [string]
    $FileName,

    [Parameter(Mandatory=$true)]
    [string]
    $PackagePath,

    [Parameter()]
    [string]
    $UnzipPath
)

begin{
    $NewFile = Join-Path -Path $PackagePath -ChildPath "chocolateyInstall.ps1"
    $OriginalFile = Join-Path -Path $PackagePath -ChildPath "chocolateyInstall_old.ps1"
    $ParentSWDirectory = Split-Path -Path (Split-Path -Path $PackagePath)
} process {
    Copy-Item -Path $NewFile -Destination $OriginalFile
    #Regex
    $URLRegex = '.*url.*' #replace url
    $ChecksumRegex = '.*checksum.*' # replace checksum

    $InstallerContent = Get-Content -Path $NewFile

    # Remove all comments in the template
    $InstallerContent = $InstallerContent | Where-Object {$_ -notmatch "^\s*#"} | ForEach-Object {$_ -replace '(^.*?)\s*?[^``]#.*','$1'} #| Set-Content -Path $NewFile
    $InstallerContent = $InstallerContent | Where-Object {$_ -notmatch $URLRegex -and $_ -notmatch $ChecksumRegex}  #| Set-Content -Path $NewFile
    $script:FilePathPresent = $false
    $InstallerContent | ForEach-Object {
        if ($_ -match '(file[\s]*=)') {
            $script:FilePathPresent = $true
        }
    }
    if(-Not $script:FilePathPresent) {
        Write-Log "Calling Set File Path with path $FileName" -Severity 1
        $script:ToolsPathPresent = $false
        $script:ToolsDirPresent = $false
        $InstallerContent | ForEach-Object {
            if($_ -match '(\$toolsPath =)')  {
                $script:FilePathPresent = $true
            }
            if($_ -match '(\$toolsDir =)'){
                $script:ToolsDirPresent = $true
            }
        }
        
        $InstallerContent = $InstallerContent | ForEach-Object {
            $_
            if($_ -match "packageArgs = @"){
                if($script:ToolsPathPresent) {
                    "  file          = (Join-Path `$toolsPath '$FileName')"
                } elseif($script:ToolsDirPresent) {
                    "  file          = (Join-Path `$toolsDir '$FileName')"
                } else {
                    "  file          = (Join-Path `$PSScriptRoot '$FileName')"
                }
            }
        }
    }

    if($UnzipPath) {
        Write-Log "Calling set unzip location and remove installzip, got unzip location $UnzipPath" -Severity 1
        $ChocolateyPackageFolder = Join-Path -Path $PackagePath -ChildPath 'tools'
        $InstallerContent -Replace ".*unzipLocation[\s]*=[\s]*Get-PackageCacheLocation","unzipLocation = $ChocolateyPackageFolder"
        $InstallerContent -Replace "Install-ChocolateyZipPackage[\s]*=[\s]@packageArgs",""
    }

    $Versions = Get-ChildItem -Path $ParentSWDirectory -Directory | Select-Object -ExpandProperty $_.Name # | Sort-object $_ -descending | Select-Object -First 2
    $LastVersions = New-Object System.Collections.ArrayList
    $Versions | ForEach-Object {$LastVersions.Add([version]$LastVersions)}
    Write-host $Versions
    Set-Content -Path $NewFile -Value $InstallerContent
}

}
