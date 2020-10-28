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
    New-Item "TestDrive:\package\" -Name "2.0.0" -ItemType Directory
    New-Item "TestDrive:\package\2.0.0\" -Name "tools" -ItemType Directory

    $ToolsPath = "TestDrive:\package\2.0.0\tools"
    $FileName = 'package.exe'
    $UnzipPath = $ToolsPath

    It "Catches error that the installer script does not exist" {
        Edit-ChocolateyInstaller $ToolsPath $FileName
        Assert-MockCalled Write-Log -Exactly 3 -Scope It
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
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly "\sfile[\s]*= \(Join-Path "
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly '(\sfile[\s]*=)'
        }

        BeforeEach {
            Set-Content "$ToolsPath\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"

            $BaseURL = "https://www.cgl.ucsf.edu"

            # Discovering download link
            # Process found here:  https://stackoverflow.com/questions/34422255/
            # Unsure if all settings are needed.
            $url = "$BaseURL/chimera/cgi-bin/secure/chimera-get.py"
            $postData = "choice=Accept&file=win64/chimera-$env:ChocolateyPackageVersion-win64.exe"
            $buffer = [text.encoding]::ascii.getbytes($postData)
            [net.httpWebRequest] $req = [net.webRequest]::create($url)
            $req.method = "POST"
            $req.Accept = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
            $req.Headers.Add("Accept-Language: en-US")
            $req.Headers.Add("Accept-Encoding: gzip,deflate")
            $req.Headers.Add("Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7")
            $req.AllowAutoRedirect = $false
            $req.ContentType = "application/x-www-form-urlencoded"
            $req.ContentLength = $buffer.length
            $req.TimeOut = 50000
            $req.KeepAlive = $true
            $req.Headers.Add("Keep-Alive: 300");
            $reqst = $req.getRequestStream()
            $reqst.write($buffer, 0, $buffer.length)
            $reqst.flush()
            $reqst.close()
            [net.httpWebResponse] $res = $req.getResponse()
            $resst = $res.getResponseStream()
            $sr = new-object IO.StreamReader($resst)
            $result = $sr.ReadToEnd()
            $res.close()

            $URLstub = ($result.split() |? {$_ -match "href="}) -replace ".*href=`"(.*)`".*","$1"

            Write-Host "You are establishing a license agreement as defined here:" -ForegroundColor Cyan
            Write-Host "http://www.cgl.ucsf.edu/chimera/license.html" -ForegroundColor Cyan

            $packageArgs = @{
               packageName   = $env:ChocolateyPackageName
               fileType      = "EXE"
               url64bit      = $BaseURL + $URLstub
               softwareName  = "UCSF Chimera*"
               checksum64    = "7607b11115ba8cbaa87e9f0c8362334b753b531e66dc1341a49dd24802934f80"
               checksumType64= "sha256"
               silentArgs   = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-""
               validExitCodes= @(0)
            }

            Install-ChocolateyPackage @packageArgs'
            Edit-ChocolateyInstaller $ToolsPath $FileName
        }

        AfterEach {
            Get-ChildItem "$ToolsPath\*" -Recurse | Remove-Item
        }
    }

    Context "Additional scripts" {
        It "Finds no previous versions and adds empty additional scripts" {
            Edit-ChocolateyInstaller $ToolsPath $FileName
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'FinalScript'
        }

        It "Finds one previous version and adds the additional scripts" {
            New-Item "TestDrive:\package\" -Name "1.0.0" -ItemType Directory
            New-Item "TestDrive:\package\1.0.0\" -Name "tools" -ItemType Directory
            Set-Content "TestDrive:\package\1.0.0\tools\InitialScript.ps1" -Value 'This is a previous script.'
            Set-Content "TestDrive:\package\1.0.0\tools\FinalScript.ps1" -Value 'This is a previous script.'
            Set-Content "TestDrive:\package\1.0.0\tools\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"

            # Install Sourcetree Enterprise
            $PrevVersion = $true
            $packageArgs = @{
              packageName   = "sourcetree"
              softwareName  = "Sourcetree*"
              fileType      = "msi"
              silentArgs    = "/qn /norestart ACCEPTEULA=1 /l*v `"$env:TEMP\log.log`""
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
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\InitialScript.ps1" | Should -FileContentMatchExactly 'This is a previous script.'
            "$ToolsPath\FinalScript.ps1" | Should -FileContentMatchExactly 'This is a previous script.'
        }

        It "Finds one previous version and adds the install script as well" {
            New-Item "TestDrive:\package\" -Name "1.0.0" -ItemType Directory
            New-Item "TestDrive:\package\1.0.0\" -Name "tools" -ItemType Directory
            Set-Content "TestDrive:\package\1.0.0\tools\InitialScript.ps1" -Value 'This is a previous script.'
            Set-Content "TestDrive:\package\1.0.0\tools\FinalScript.ps1" -Value 'This is a previous script.'
            Set-Content "TestDrive:\package\1.0.0\tools\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop";

            $toolsDir = Split-Path $MyInvocation.MyCommand.Definition
            $Transforms = Join-Path $toolsdir "base.mst"
            $TimeStamp = Get-Date -Format yyyyMMdd-HHmmss
            $LogPath = "$env:SWP\"
            $Transforms = Join-Path $toolsdir "base.mst"
            $LogFileName = "Install_Zoom_$($TimeStamp).log"
            $Logfile = Join-Path $LogPath $LogFileName
            $PrevVersion = $true

            $packageArgs = @{
              file           = (Join-Path $PSScriptRoot "ZoomInstallerFull.msi")
              packageName    = "zoom"
              fileType       = "msi"
              validExitCodes = @(0)
              softwareName   = "Zoom*"
              unzipLocation  = $toolsDir
              silentArgs     = "TRANSFORMS=`"$($Transforms)`" ALLUSERS=1 REBOOT=ReallySuppress ZoomAutoUpdate=`"true`" /qn /L*v `"$Logfile`""
            }
            $SWInstalled = Get-UninstallRegistryKey -softwareName "Zoom"
            $NotInstalled = $true
            if($null -ne $SWInstalled) {
                $FileVersion = Get-Item "C:\Program Files (x86)\Zoom\bin\Zoom.exe" | Select-Object -ExpandProperty VersionInfo | Select-Object -ExpandProperty ProductVersion
                $FileVersion = [version]($FileVersion.Replace(",","."))
                $NotInstalled = $FileVersion -lt [version]($env:ChocolateyPackageVersion)
            }

            if($NotInstalled) {
              &(Join-Path $PSScriptRoot InitialScript.ps1)
              Install-ChocolateyPackage @packageArgs
              &(Join-Path $PSScriptRoot FinalScript.ps1)
            } else {
              Set-PowerShellExitCode -exitCode 0
            }'

            Edit-ChocolateyInstaller $ToolsPath $FileName

            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\InitialScript.ps1" | Should -FileContentMatchExactly 'This is a previous script.'
            "$ToolsPath\FinalScript.ps1" | Should -FileContentMatchExactly 'This is a previous script.'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'ChocolateyPackageName'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly '\$PrevVersion'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'packageName'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'Join-Path \$toolsDir'
        }

        It "Finds one previous version with a config file and adds all additional files and the config" {
            New-Item "TestDrive:\package\" -Name "1.0.0" -ItemType Directory
            New-Item "TestDrive:\package\1.0.0\" -Name "tools" -ItemType Directory
            Set-Content "TestDrive:\package\1.0.0\tools\config.json" -Value '{"Test":0, "Test2":1}'
            Set-Content "TestDrive:\package\1.0.0\tools\InitialScript.ps1" -Value 'This is a previous script.'
            Set-Content "TestDrive:\package\1.0.0\tools\FinalScript.ps1" -Value 'This is a previous script.'
            Set-Content "TestDrive:\package\1.0.0\tools\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"

            # Install Sourcetree Enterprise
            $PrevVersion = $true
            $packageArgs = @{
              packageName   = "sourcetree"
              softwareName  = "Sourcetree*"
              fileType      = "msi"
              silentArgs    = "/qn /norestart ACCEPTEULA=1 /l*v `"$env:TEMP\log.log`""
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
            "$ToolsPath\config.json" | Should -FileContentMatchExactly '{"Test":0, "Test2":1}'
            "$ToolsPath\InitialScript.ps1" | Should -FileContentMatchExactly 'This is a previous script.'
            "$ToolsPath\FinalScript.ps1" | Should -FileContentMatchExactly 'This is a previous script.'
        }

        It "Finds previous version in packaging and copies additional files from one version previous" {
            New-Item "TestDrive:\package\" -Name "1.5.0" -ItemType Directory
            New-Item "TestDrive:\package\1.5.0\" -Name "tools" -ItemType Directory
            Set-Content "TestDrive:\package\1.5.0\tools\config.exe" -Value '{"Test":0, "Test2":1}'

            New-Item "TestDrive:\package\" -Name "1.0.0" -ItemType Directory
            New-Item "TestDrive:\package\1.0.0\" -Name "tools" -ItemType Directory
            Set-Content "TestDrive:\package\1.0.0\tools\config.json" -Value '{"Test":0, "Test2":3}'
            Set-Content "TestDrive:\package\1.0.0\tools\InitialScript.ps1" -Value 'This is a previous script.'
            Set-Content "TestDrive:\package\1.0.0\tools\FinalScript.ps1" -Value 'This is a previous script.'
            Set-Content "TestDrive:\package\1.0.0\tools\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop";

$toolsDir = Split-Path $MyInvocation.MyCommand.Definition
$Transforms = Join-Path $toolsdir "base.mst"
$TimeStamp = Get-Date -Format yyyyMMdd-HHmmss
$LogPath = "$env:SWP\"
$Transforms = Join-Path $toolsdir "base.mst"
$LogFileName = "Install_Zoom_$($TimeStamp).log"
$Logfile = Join-Path $LogPath $LogFileName

$packageArgs = @{
    file = (Join-Path $toolsDir "ZoomInstallerFull.msi")
    packageName = $env:ChocolateyPackageName
    fileType       = "msi"
    validExitCodes = @(0)
    softwareName   = "Zoom*"
    unzipLocation  = $toolsDir
    silentArgs     = "TRANSFORMS=`"$($Transforms)`" ALLUSERS=1 REBOOT=ReallySuppress ZoomAutoUpdate=`"true`" /qn /L*v `"$Logfile`""
}
$SWInstalled = Get-UninstallRegistryKey -softwareName "Zoom"
$NotInstalled = $true
if($null -ne $SWInstalled) {
    $FileVersion = Get-Item "C:\Program Files (x86)\Zoom\bin\Zoom.exe" | Select-Object -ExpandProperty VersionInfo | Select-Object -ExpandProperty ProductVersion
    $FileVersion = [version]($FileVersion.Replace(", ","."))
    $NotInstalled = $FileVersion -lt [version]($env:ChocolateyPackageVersion)
}

if($NotInstalled) {
    &(Join-Path $PSScriptRoot InitialScript.ps1)
    Install-ChocolateyPackage @packageArgs
    &(Join-Path $PSScriptRoot FinalScript.ps1)
} else {
    Set-PowerShellExitCode -exitCode 0
}'

            Edit-ChocolateyInstaller $ToolsPath $FileName
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\config.json" | Should -FileContentMatchExactly '{"Test":0, "Test2":3}'
            "$ToolsPath\InitialScript.ps1" | Should -FileContentMatchExactly 'This is a previous script.'
            "$ToolsPath\FinalScript.ps1" | Should -FileContentMatchExactly 'This is a previous script.'
            $select = (get-content "$ToolsPath\chocolateyInstall.ps1" | select-string -pattern "\sfile =")
            $count = $select.length
            $count | Should -MatchExactly 1
        }

        It "Finds multiple previous versions and adds the latest as additional scripts" {
            New-Item "TestDrive:\package\" -Name "1.5.0" -ItemType Directory
            New-Item "TestDrive:\package\1.5.0\" -Name "tools" -ItemType Directory
            Set-Content "TestDrive:\package\1.5.0\tools\InitialScript.ps1" -Value 'This is the previous script.'
            Set-Content "TestDrive:\package\1.5.0\tools\FinalScript.ps1" -Value 'This is the previous script.'
            Set-Content "TestDrive:\package\1.5.0\tools\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"

            # Install Sourcetree Enterprise
            $PrevVersion = $true
            $packageArgs = @{
              packageName   = "sourcetree"
              softwareName  = "Sourcetree*"
              fileType      = "msi"
              silentArgs    = "/qn /norestart ACCEPTEULA=1 /l*v `"$env:TEMP\log.log`""
              validExitCodes= @(0,1641,3010)
              url           = "https://product-downloads.atlassian.com/software/sourcetree/windows/ga/SourcetreeEnterpriseSetup_3.2.6.msi"
              checksum      = "c8b34688d7f69185b41f9419d8c65d63a2709d9ec59752ce8ea57ee6922cbba4"
              checksumType  = "sha256"
              url64bit      = ""
              checksum64    = ""
              checksumType64= "sha256"
            }

            Install-ChocolateyPackage @packageArgs'

            New-Item "TestDrive:\package\" -Name "1.0.0" -ItemType Directory
            New-Item "TestDrive:\package\1.0.0\" -Name "tools" -ItemType Directory
            Set-Content "TestDrive:\package\1.0.0\tools\InitialScript.ps1" -Value 'This is a previous script.'
            Set-Content "TestDrive:\package\1.0.0\tools\FinalScript.ps1" -Value 'This is a previous script.'
            Set-Content "TestDrive:\package\1.0.0\tools\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"

            # Install Sourcetree Enterprise
            $PrevVersion = $true
            $packageArgs = @{
              packageName   = "sourcetree"
              softwareName  = "Sourcetree*"
              fileType      = "msi"
              silentArgs    = "/qn /norestart ACCEPTEULA=1 /l*v `"$env:TEMP\log.log`""
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
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\InitialScript.ps1" | Should -FileContentMatchExactly 'This is the previous script.'
            "$ToolsPath\FinalScript.ps1" | Should -FileContentMatchExactly 'This is the previous script.'
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
        }

        AfterEach {
            Get-ChildItem "$ToolsPath\*" -Recurse | Remove-Item
            Get-ChildItem "TestDrive:\package\1.0.0\*" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Get-ChildItem "TestDrive:\package\1.5.0\*" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Remove-Item "TestDrive:\package\1.5.0" -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item "TestDrive:\package\1.0.0" -Force -Recurse -ErrorAction SilentlyContinue
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

    Context "Zip package is overridden" {

        It "Adds expansion of archive" {
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'Expand-Archive'
        }

        It "Adds additional files" {
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'FinalScript'
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

    Context "Previous version as a trailing zero" {

        It "Finds correct version even if previous version has a trailing zero" {
            New-Item "TestDrive:\package\" -Name "1.5.0.0891" -ItemType Directory
            New-Item "TestDrive:\package\1.5.0.0891\" -Name "tools" -ItemType Directory
            Set-Content "TestDrive:\package\1.5.0.0891\tools\InitialScript.ps1" -Value 'This is the previous script.'
            Set-Content "TestDrive:\package\1.5.0.0891\tools\FinalScript.ps1" -Value 'This is the previous script.'
            Set-Content "TestDrive:\package\1.5.0.0891\tools\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"

            # Install Sourcetree Enterprise
            $PrevVersion = $true
            $packageArgs = @{
              packageName   = "sourcetree"
              softwareName  = "Sourcetree*"
              fileType      = "msi"
              silentArgs    = "/qn /norestart ACCEPTEULA=1 /l*v `"$env:TEMP\log.log`""
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
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\InitialScript.ps1" | Should -FileContentMatchExactly 'This is the previous script.'
            "$ToolsPath\FinalScript.ps1" | Should -FileContentMatchExactly 'This is the previous script.'
        }

        It "Finds correct version even if previous version has a trailing zero in different segment" {
            New-Item "TestDrive:\package\" -Name "1.5.01.0891" -ItemType Directory
            New-Item "TestDrive:\package\1.5.01.0891\" -Name "tools" -ItemType Directory
            Set-Content "TestDrive:\package\1.5.01.0891\tools\InitialScript.ps1" -Value 'This is the previous script.'
            Set-Content "TestDrive:\package\1.5.01.0891\tools\FinalScript.ps1" -Value 'This is the previous script.'
            Set-Content "TestDrive:\package\1.5.01.0891\tools\chocolateyInstall.ps1" -Value '$ErrorActionPreference = "Stop"

            # Install Sourcetree Enterprise
            $PrevVersion = $true
            $packageArgs = @{
              packageName   = "sourcetree"
              softwareName  = "Sourcetree*"
              fileType      = "msi"
              silentArgs    = "/qn /norestart ACCEPTEULA=1 /l*v `"$env:TEMP\log.log`""
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
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'InitialScript'
            "$ToolsPath\chocolateyInstall_old.ps1" | Should -Not -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\chocolateyInstall.ps1" | Should -FileContentMatchExactly 'FinalScript'
            "$ToolsPath\InitialScript.ps1" | Should -FileContentMatchExactly 'This is the previous script.'
            "$ToolsPath\FinalScript.ps1" | Should -FileContentMatchExactly 'This is the previous script.'
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
        }

        AfterEach {
            Get-ChildItem "$ToolsPath\*" -Recurse | Remove-Item
            Get-ChildItem "TestDrive:\package\1.5.0.0891\*" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Remove-Item "TestDrive:\package\1.5.01.0891" -Force -Recurse -ErrorAction SilentlyContinue
            Get-ChildItem "TestDrive:\package\1.5.01.0891\*" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Remove-Item "TestDrive:\package\1.5.01.0891" -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}