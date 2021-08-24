BeforeAll {
    $path = Split-Path -Parent $PSCommandPath.Replace('.Tests.ps1', '.ps1').Replace('Tests', 'WASP\Private')
    $Private = @(Get-ChildItem -Path $path\*.ps1 -ErrorAction SilentlyContinue)
    foreach ($import in $Private) {
        . $import.fullname
    }
}

Describe "Overriding function for package" {
    BeforeAll {
        Mock Write-Log { }
        Mock Invoke-Expression { }

        New-Item "TestDrive:\" -Name "package" -ItemType Directory
        New-Item "TestDrive:\package" -Name "2.0.0" -ItemType Directory
        New-Item "TestDrive:\package\2.0.0" -Name "chocolateyInstall.ps1" -ItemType File
        #Set-Content "TestDrive:\package\2.0.0\chocolateyInstall.ps1" -Value "#Content"
        $packToolInstallPath = "TestDrive:\package\2.0.0\chocolateyInstall.ps1"
    }

    Context "Script has not been executed previously" {
        It "Has forced download disabled" {
            $ForcedDownload = $false
            Start-PackageInstallFilesDownload $packToolInstallPath $ForcedDownload
            Assert-MockCalled Invoke-Expression -Times 1 -ParameterFilter { $command -eq $packToolInstallPath }
        }

        It "Has forced download enabled" {
            $ForcedDownload = $true
            Start-PackageInstallFilesDownload $packToolInstallPath $ForcedDownload
            Assert-MockCalled Invoke-Expression -Times 1 -ParameterFilter { $command -eq $packToolInstallPath }
        }
    }

    Context "Script has been executed previously" {
        BeforeAll {
            $ForcedDownload = $false
        }
        It "Has forced download disabled" {
            Start-PackageInstallFilesDownload $packToolInstallPath $ForcedDownload
            Assert-MockCalled Invoke-Expression -Times 0 -ParameterFilter { $command -eq $packToolInstallPath }
        }
        It "Has forced download disabled and finds downloaded binary (exe)" {
            New-Item "TestDrive:\package\2.0.0" -Name "package.exe" -ItemType File
            Start-PackageInstallFilesDownload $packToolInstallPath $ForcedDownload
            Assert-MockCalled Invoke-Expression -Times 0 -Scope It
        }
        It "Has forced download disabled and finds downloaded binary (msi)" {
            New-Item "TestDrive:\package\2.0.0" -Name "package.msi" -ItemType File
            Start-PackageInstallFilesDownload $packToolInstallPath $ForcedDownload
            Assert-MockCalled Invoke-Expression -Times 0 -Scope It
        }
        It "Has forced download disabled and finds downloaded binary (zip)" {
            New-Item "TestDrive:\package\2.0.0" -Name "package.zip" -ItemType File
            Start-PackageInstallFilesDownload $packToolInstallPath $ForcedDownload
            Assert-MockCalled Invoke-Expression -Times 0 -Scope It
        }
        It "Has forced download disabled, has localFiles enabled but finds no binary" {
            $toolPath = Get-Item $packToolInstallPath | Select-Object -ExpandProperty DirectoryName
            $original = Join-Path -Path $toolPath -ChildPath 'chocolateyInstall_old.ps1'
            Set-Content $original 'Write-Host "http://www.cgl.ucsf.edu/chimera/license.html" -ForegroundColor Cyan

            $packageArgs = @{
               packageName   = $env:ChocolateyPackageName
               fileType      = "EXE"
               localFile     = $true
               url64bit      = $BaseURL + $URLstub
               softwareName  = "UCSF Chimera*"
               checksum64    = "7607b11115ba8cbaa87e9f0c8362334b753b531e66dc1341a49dd24802934f80"
               checksumType64= "sha256"
               silentArgs   = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-""
               validExitCodes= @(0)
            }

            Install-ChocolateyPackage @packageArgs'
            Start-PackageInstallFilesDownload $packToolInstallPath $ForcedDownload
            Assert-MockCalled Invoke-Expression -Times 1 -Scope It
        }

        BeforeEach {
            New-Item "TestDrive:\package\2.0.0" -Name "chocolateyInstall.ps1" -ItemType File -ErrorAction SilentlyContinue
            New-Item "TestDrive:\package\2.0.0" -Name "chocolateyInstall_old.ps1" -ItemType File -ErrorAction SilentlyContinue
        }

        AfterEach {
            Get-ChildItem "TestDrive:\package\2.0.0\*" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}