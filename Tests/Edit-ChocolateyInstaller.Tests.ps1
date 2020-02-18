$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}

Describe "Editing package installer script from chocolatey" {
    $config = '{
        "Application": {
            "GitProject": "project",
            "GitBaseUrl": "https://base.url.com",
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

    New-Item "TestDrive:\" -Name "package" -ItemType Directory
    New-Item "TestDrive:\package\" -Name "1.0.0" -ItemType Directory
    New-Item "TestDrive:\package\1.0.0\" -Name "tools" -ItemType Directory

    $ToolsPath = "TestDrive:\package\1.0.0\tools"
    $FileName = 'package.exe'
    $UnzipPath = $ToolsPath

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
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -FileContentMatchExactly '#'
            "$ToolsPath\chocolateyInstall.ps1" | Should -Not -FileContentMatchExactly '#'
        }

        It "Checks that url and checksum args are removed from file" {
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -FileContentMatchExactly 'url'
            "$ToolsPath\chocolateyInstall.ps1" | Should -Not -FileContentMatchExactly 'url'
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -FileContentMatchExactly 'checksum'
            "$ToolsPath\chocolateyInstall.ps1" | Should -Not -FileContentMatchExactly 'checksum'
        }

        It "Finds that file path is not yet set and sets it" {
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly '(file[\s]*=)'
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly '(file[\s]*=)'
        }

        Context "Additional scripts" {
            It "Finds no previous versions and adds empty additional scripts" {
                "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'InitialScript'
                "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'InitialScript'
                "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'FinalScript'
                "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'FinalScript'
            }

            It "Finds one previous version and adds the additional scripts" {

            }

            It "Finds multiple previous versions and adds the latest as additional scripts" {

            }
        }

        BeforeEach {
            Set-Content "$ToolsPath\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"

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
            Get-ChildItem "$ToolsPath\*" -Recurse | Remove-Item
        }
    }

    Context "File path is already set in script" {
        It "Finds that file path is set" {
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -FileContentMatchExactly '(file[\s]*=)'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly '(file[\s]*=)'
        }

        BeforeEach {
            Set-Content "$ToolsPath\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"; # stop on all errors
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
            Edit-ChocolateyInstaller $ToolsPath $FileName
        }

        AfterEach {
            Get-ChildItem "$ToolsPath\*" -Recurse | Remove-Item
        }

    }

    Context "Unzip path is provided" {

        It "Writes unzip path to file" {
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -FileContentMatchExactly 'Install-ChocolateyZipPackage'
            "$ToolsPath\chocolateyInstall.ps1" | Should -Not -FileContentMatchExactly 'Install-ChocolateyZipPackage'
        }

        BeforeEach {
            Set-Content "$ToolsPath\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"; # stop on all errors
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

                Install-ChocolateyZipPackage @packageArgs'
            Edit-ChocolateyInstaller $ToolsPath $FileName $UnzipPath
        }

        AfterEach {
            Get-ChildItem "$ToolsPath\*" -Recurse | Remove-Item
        }
    }
}