$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}

Describe "Editing package installer script from chocolatey" {
    $config = '{
        "Application": {
            "GitProject": "csswcs",
            "GitBaseUrl": "https://git.its.unibas.ch",
            "PreAdditionalScripts": [
                "InitialScript.ps1"
            ],
            "PostAdditionalScripts": [
                "FinalScript.ps1"
            ]
        }
    }'
    Mock Read-ConfigFile { return ConvertFrom-Json $config }
    Mock Write-Log { }

    $ToolsPath = 'TestDrive:\tools'
    $FileName = 'package.exe'
    $UnzipPath = ''

    It "Catches error that the installer script does not exist" {
        Edit-ChocolateyInstaller $ToolsPath $FileName
        Assert-MockCalled Write-Log -Exactly 1 -Scope It
    }

    Context "Installer script exists at path" {
        New-Item "TestDrive:\" -Name "tools" -ItemType Directory
        Set-Content "TestDrive:\tools\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"

        # Check if Sourcetree standard (with Squirrel installer) is installed
        [array] $key = Get-UninstallRegistryKey "sourcetree" | Where-Object { -Not ($_.WindowsInstaller) }
        if ($key.Count -gt 0) {
          Write-Warning "Found installation of standard version of Sourcetree."
          Write-Warning "This package will install the enterprise version of Sourcetree."
          Write-Warning "Both applications can be installed side-by-side. Settings wont be migrated from the existing installation. If you no longer want the standard version installed you can uninstall it from Windows control panel."
        }

        # Install Sourcetree Enterprise
        $packageArgs = @{
          packageName   = $env:ChocolateyPackageName
          softwareName  = "Sourcetree*"
          fileType      = "msi"
          silentArgs    = "/qn /norestart ACCEPTEULA=1 /l*v `"$env:TEMP\$env:ChocolateyPackageName.$env:ChocolateyPackageVersion.log`""
          validExitCodes= @(0,1641,3010)
          url           = "https://product-downloads.atlassian.com/software/sourcetree/windows/ga/SourcetreeEnterpriseSetup_3.2.6.msi"
          checksum      = "c8b34688d7f69185b41f9419d8c65d63a2709d9ec59752ce8ea57ee6922cbba4"
          checksumType  = "sha256"
          url64bit      = ""
          checksum64    = ""
          checksumType64= "sha256"
        }

        Install-ChocolateyPackage @packageArgs'

        It "Catches error that the installer script does not exist" {
            Edit-ChocolateyInstaller $ToolsPath $FileName
        }
    }
}