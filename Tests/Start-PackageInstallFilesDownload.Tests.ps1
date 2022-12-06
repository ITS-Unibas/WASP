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
        Mock Search-TemplateFile { }
        Mock Rewrite-ChocolateyInstallScriptWithTemplate { }

        New-Item "C:\" -Name "package" -ItemType Directory
        New-Item "C:\package" -Name "2.0.0" -ItemType Directory
        New-Item "C:\package\2.0.0" -Name "tools" -ItemType Directory
        New-Item "C:\package\2.0.0\tools" -Name "chocolateyInstall.ps1" -ItemType File
        New-Item "C:\package\2.0.0\tools" -Name "chocolateyInstall_old.ps1" -ItemType File

        #Set-Content "C:\package\2.0.0\chocolateyInstall.ps1" -Value "#Content"
        $package = "package"
        $packToolInstallPath = "C:\package\2.0.0\tools\chocolateyInstall.ps1"
    }

    Context "Script has not been executed previously" {
        It "Has forced download disabled" {
            $ForcedDownload = $false
            Start-PackageInstallFilesDownload -package $package -packToolInstallPath $packToolInstallPath -ForcedDownload $ForcedDownload
            Assert-MockCalled Invoke-Expression -Times 1 -ParameterFilter { $command -eq $packToolInstallPath }
        }

        It "Has forced download enabled" {
            $ForcedDownload = $true
            Start-PackageInstallFilesDownload -package $package -packToolInstallPath $packToolInstallPath -ForcedDownload $ForcedDownload
            Assert-MockCalled Invoke-Expression -Times 1 -ParameterFilter { $command -eq $packToolInstallPath }
        }
    }

    Context "Script has been executed previously" {
        It "Has forced download disabled" {
            Start-PackageInstallFilesDownload -package $package -packToolInstallPath $packToolInstallPath -ForcedDownload $ForcedDownload
            Assert-MockCalled Invoke-Expression -Times 1 -ParameterFilter { $command -eq $packToolInstallPath }
        }

        BeforeAll {
            $ForcedDownload = $false
        }

        AfterAll {
            Remove-Item "c:\package" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}
