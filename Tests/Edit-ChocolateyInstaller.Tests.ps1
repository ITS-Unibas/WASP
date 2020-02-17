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
    $UnzipPath = $ToolsPath

    New-Item "TestDrive:\" -Name "tools" -ItemType Directory

    It "Catches error that the installer script does not exist" {
        Edit-ChocolateyInstaller $ToolsPath $FileName
        Assert-MockCalled Write-Log -Exactly 1 -Scope It
    }

    Context "Installer script exists at path" {
        It "Makes copy of script and renames it" {
            Test-Path "$ToolsPath\chocolateyInstall_old.ps1" | Should -Be $true
        }

        It "Checks that contents of edited and original script are not equal" {
            (Get-FileHash "$ToolsPath\chocolateyInstall_old.ps1").Hash -eq (Get-FileHash "$ToolsPath\chocolateyInstall.ps1").Hash | Should -Be $false
        }

        It "Checks that all comments are removed from original script" {
            $Content = Get-Content -Path "$ToolsPath\chocolateyInstall.ps1"
            $Content -contains "#" | Should -Be $false
        }

        It "Checks that url and checksum args are removed from file" {
            $Content = Get-Content -Path "$ToolsPath\chocolateyInstall.ps1"
            $Content -contains "url." | Should -Be $false
            $Content -contains "checksum." | Should -Be $false
        }

        It "Finds that file path is not yet set" {
            Assert-MockCalled Write-Log -Exactly 1 -Scope It

        }

        BeforeEach {
            Set-Content "TestDrive:\tools\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"

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
            Edit-ChocolateyInstaller $ToolsPath $FileName
        }

        AfterEach {
            Get-ChildItem "TestDrive:\tools\*" -Recurse | Remove-Item
        }
    }

    Context "" {
        It "Finds that file path is not yet set" {
            Assert-MockCalled Write-Log -Exactly 1 -Scope It

        }

    }

    Context "Unzip path is provided" {

        It "Writes unzip path to file" {
            $Content = Get-Content -Path "$ToolsPath\chocolateyInstall.ps1"
            $Content -contains "Install-ChocolateyZipPackage" | Should -Be $true
        }

        BeforeEach {
            Set-Content "TestDrive:\tools\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"; # stop on all errors
                $packageName= "unibas-netcrunchconsole" # arbitrary name for the package, used in messages
                $toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
                $url        = "http://url.com/NC10Console.exe" # download url
                $fileLocation = Join-Path $toolsDir "NC10Console.exe"

                $packageArgs = @{
                packageName   = $packageName
                unzipLocation = $toolsDir
                fileType      = "EXE" #only one of these: exe, msi, msu
                url           = $url
                file          = $fileLocation
                validExitCodes= @(0) #please insert other valid exit codes here

                softwareName  = "unibas-netcrunchconsole*" #part or all of the Display Name as you see it in Programs and Features. It should be enough to be unique
                checksum      = "3aeb5e8c7ed947ff28b998594a01be872f7994bdb4832fde4bd13e4351b93172"
                checksumType  = "sha256" #default is md5, can also be sha1
                }

                Install-ChocolateyPackage @packageArgs'
            Edit-ChocolateyInstaller $ToolsPath $FileName $UnzipPath
        }

        AfterEach {
            Get-ChildItem "TestDrive:\tools\*" -Recurse | Remove-Item
        }
    }
}