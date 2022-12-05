function Register-ChocolateyPackagingClient {
    <#
   .SYNOPSIS
    Setup a new Chocolatey Packaging Client
   .DESCRIPTION
    Setup a new Chocolatey Packaging Client with all the stuff you need for doing sick packaging
   .NOTES
    FileName: Register-ChocolateyPackagingClient.ps1
    Author: Kevin Schaefer
    Contact: its-wcs-ma@unibas.ch
    Created: 2019-07-31
    Updated: 2020-05-15
    Version: 1.1.0
   .EXAMPLE
    PS>
   .LINK
#>

    [cmdletbinding()]
    param()

    begin {
        $Config = Read-ConfigFile
    } process {
        Write-Log "Starting to setup the chocolatey packaging server." -Severity 1

        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Error -Message "You need administrator rights to execute these operations" -Category AuthenticationError -Exception ([System.NotSupportedException]::new())
            return
        }

        # Install chocolatey
        # TODO: Check if chocolatey already installed before
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | ForEach-Object { Write-Log $_ }
        # TODO: Check if chocolatey was installed

        # Download Nuget
        $NugetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
        $NuGetDirectory = New-Item -Path (Join-Path $Config.Application.BaseDirectory "NuGet") -ItemType Directory -Force
        $NuGetFilePath = (Join-Path $NuGetDirectory.FullName "nuget.exe")
        Invoke-WebRequest -Uri $NugetUrl -OutFile $NuGetFilePath
        if(-Not (Test-Path -Path $NuGetFilePath)) {
            Write-Log "There was an error downloading nuget.exe from $NuGetUrl. Please Download it manually to $NugetDirectory." -Severity 3
        } else {
            Write-Log "Successfully downloaded nuget.exe." -Severity 1
        }

        Request-GitRepo -User $Config.Application.GitHubOrganisation -GitRepo $Config.Application.PackagesInbox -CloneDirectory $Config.Application.BaseDirectory -WithSubmodules
        Request-GitRepo -User $Config.Application.GitHubOrganisation -GitRepo $Config.Application.PackageGallery -CloneDirectory $Config.Application.BaseDirectory
        Request-GitRepo -User $Config.Application.GitHubOrganisation -GitRepo $Config.Application.PackagesInboxFiltered -CloneDirectory $Config.Application.BaseDirectory
        # TODO: Why ist this repo cloned? When you install chocolatey you get all the helpers for free, will have further checks while going on with the refactoring
        # Request-GitRepo -User $Config.Application.GitHubOrganisation -GitRepo $Config.Application.ChocoRepo -CloneDirectory $Config.Application.BaseDirectory
        Request-GitRepo -User $Config.Application.GitHubOrganisation -GitRepo $Config.Application.JiraObserver -CloneDirectory $Config.Application.BaseDirectory
        Request-GitRepo -User $Config.Application.GitHubOrganisation -GitRepo $Config.Application.PackagesWishlist -CloneDirectory $Config.Application.BaseDirectory

        # TODO: ErrorHandling
    } end {
        Write-Log "Finished to setup the chocolatey packaging server." -Severity 1
    }

}
