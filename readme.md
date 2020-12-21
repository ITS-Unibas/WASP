# Windows Automatic Software Packaging (WASP)

## Introduction

WASP is a PowerShell Module to automatically build and push software packages.
All packages are built using chocolatey. The chocolatey manifests are taken from existing community or own-hosted repositories.
The built packages will be pushed to a given NuGet repository and the source code will be commited to a defined Git repository.

## Requirements

You need to have the following system and configuration set up:
* Own-hosted NuGet repository e.g. Sonatype Nexus Repository Manager. There should be three NuGet repositories
  * dev for hosting the packages which are in development
  * test for hosting the packages which are in QA
  * prod for hosting the packages which can be deployed to your clients
* Four git repositories
  * Packages inbox repository to define the sources as git submodules to get the chocolatey manifests
  * Packages wishlist which only consits of a txt file to add your wished software. Software are added with their chocolatey id and each on a new line
  * Packages inbox filtered repository to filter only the wished software from all the defined sources in the wishlist
  * Packages gallery where your productive package manifests can be changed. This repository has to be a fork of the packages inbox filtered repository because PRs will be create from package inbox filtered

### Chocolatey Manifests Requirement

The chocolateyInstall.ps1 should be structured as the following to work best:

```powershell
$ErrorActionPreference = 'Stop';

$packageName = 'atlassian-companion'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
  packageName    = $packageName
  unzipLocation  = $toolsDir
  fileType       = 'MSI'
  url            = 'https://update-nucleus.atlassian.com/Atlassian-Companion/291cb34fe2296e5fb82b83a04704c9b4/latest/win32/ia32/Atlassian%20Companion.msi'
  silentArgs     = "/qn /norestart /l*v `"$($env:SWP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`"" # ALLUSERS=1 DISABLEDESKTOPSHORTCUT=1 ADDDESKTOPICON=0 ADDSTARTMENU=0
  validExitCodes = @(0, 3010, 1641)
  softwareName   = 'atlassian-companion*' #part or all of the Display Name as you see it in Programs and Features. It should be enough to be unique
  checksum       = '37a465886b08a16ae8c3c51509e412b1a2b533189616ed333654ee1fdaa82c92'
  checksumType   = 'sha256' #default is md5, can also be sha1
}

Install-ChocolateyPackage @packageArgs
```

## Features

1. Package update selection
2. Combination of internal and public packages due to define your wanted sources
3. Build and push NuPkg of the chocolatey packages
4. Dedicated development branches for each package and version
5. Detect changes of install scripts to automatically rebuild packages
6. Binaries are downloaded and included in the NuPkgs
7. Configurations and changes from an older version are automatically moved to the new version
8. Multiple package sources from the community or your own git repositories
9. Live-Log to see what's actually happening
10. Configuration via JSON

## Get Started

1. Download the sources of the module from this git repository.
2. Import the module in your PowerShell session

```powershell
Import-Module Path-to-the-Module\Wasp
```

3. Configure wasp.json for your environment. It's located in the modules directory
4. Run the register cmdlet to set up your packaging client correctly

```powershell
Register-ChocolateyPackagingClient
```

5. Add some sources to your packages inbox repository
6. Wish your software (add package id to the wishlist.txt in the wishlist's repository)
7. Run the workflow to see the magic happen

```powershell
Start-Workflow
```

8. Monitor the progess with the dedicated log watcher cmdlet

```powershell
Start-ChocoLogWatcher
```
