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

    Context "Script has not been executed previously" {
        BeforeAll {
            $ForcedDownload = $false
        }
        It "Has forced download disabled" {
            Start-PackageInstallFilesDownload $packToolInstallPath $ForcedDownload
            Assert-MockCalled Invoke-Expression -Times 1 -ParameterFilter { $command -eq $packToolInstallPath }
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

        BeforeEach {
            New-Item "TestDrive:\package\2.0.0" -Name "chocolateyInstall.ps1" -ItemType File -ErrorAction SilentlyContinue
            New-Item "TestDrive:\package\2.0.0" -Name "chocolateyInstall_old.ps1" -ItemType File -ErrorAction SilentlyContinue
        }

        AfterEach {
            Get-ChildItem "TestDrive:\package\2.0.0\*" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}