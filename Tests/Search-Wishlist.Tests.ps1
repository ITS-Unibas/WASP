BeforeAll {
    $path = Split-Path -Parent $PSCommandPath.Replace('.Tests.ps1', '.ps1').Replace('Tests', 'WASP\Private')
    $Private = @(Get-ChildItem -Path $path\*.ps1 -ErrorAction SilentlyContinue)
    foreach ($import in $Private) {
        . $import.fullname
    }

    Mock Write-Log { }

    $test = '{
        "Application": {
            "BaseDirectory": "TestDrive:\\",
            "PackagesWishlist": "http://urltowishlistrepo.git",
            "PackagesInboxFiltered": "http://urltofilteredinbox.git",
            "WishlistSeperatorChar": "@"
        }
    }'

    Mock Read-ConfigFile { return ConvertFrom-Json $test }

    New-Item "TestDrive:\" -Name "urltowishlistrepo" -ItemType Directory
    New-Item "TestDrive:\" -Name "urltoinbox" -ItemType Directory
    New-Item "TestDrive:\" -Name "urltofilteredinbox" -ItemType Directory

    Set-Content "TestDrive:\urltowishlistrepo\wishlist.txt" -Value "#packagethatshouldnotberead@1.0.0
package@1.0.0
package2@0.1.2.1231
package3"
}

Describe "Finding package name in wishlist" {
    BeforeEach {
        Get-ChildItem -Path "TestDrive:\urltoinbox\"-Recurse | Remove-Item -Force -Recurse
        Get-ChildItem -Path "TestDrive:\urltofilteredinbox\"-Recurse | Remove-Item -Force -Recurse
    }

    It "Finds no package name" {
        New-Item "TestDrive:\urltoinbox\" -Name "package4" -ItemType Directory
        $packages = @(Get-ChildItem "TestDrive:\urltoinbox\" | Where-Object { $_.PSIsContainer })
        $packageVersion = "2.0.0"

        foreach ($package in $packages) {
            $packageToUpdate = Search-Wishlist -packagePath $package -packageVersion $packageVersion
            $packageToUpdate | Should -Be $null
        }
    }

    It "Finds package name and has no new package version" {
        New-Item "TestDrive:\urltoinbox\" -Name "package" -ItemType Directory
        $packages = @(Get-ChildItem "TestDrive:\urltoinbox\" | Where-Object { $_.PSIsContainer })
        $packageVersion = "1.0.0"

        foreach ($package in $packages) {
            $packageToUpdate = Search-Wishlist -packagePath $package -packageVersion $packageVersion
            $packageToUpdate | Should -Be $null
        }
    }

    It "Finds package name and has new package version" {
        New-Item "TestDrive:\urltoinbox\" -Name "package" -ItemType Directory
        $packages = @(Get-ChildItem "TestDrive:\urltoinbox\" | Where-Object { $_.PSIsContainer })
        $packageVersion = "2.0.0"

        foreach ($package in $packages) {
            $packageToUpdate = Search-Wishlist -packagePath $package -packageVersion $packageVersion
            $packageToUpdate | Should -Not -Be $null
            $packageToUpdate.path | Should -Be "TestDrive:\urltofilteredinbox\package\2.0.0"
            $packageToUpdate.name | Should -Be "package"
            $packageToUpdate.version | Should -Be 2.0.0
        }
    }

    It "Finds package name and new package version needs formatting" {
        New-Item "TestDrive:\urltoinbox\" -Name "package" -ItemType Directory
        $packages = @(Get-ChildItem "TestDrive:\urltoinbox\" | Where-Object { $_.PSIsContainer })
        $packageVersion = "2.r.d.0"

        foreach ($package in $packages) {
            $packageToUpdate = Search-Wishlist -packagePath $package -packageVersion $packageVersion
            $packageToUpdate | Should -Not -Be $null
            $packageToUpdate.path | Should -Be "TestDrive:\urltofilteredinbox\package\2.0.0.0"
            $packageToUpdate.name | Should -Be "package"
            $packageToUpdate.version | Should -Be 2.0.0.0
        }
    }

    It "Finds empty version after WhishlistSeperatorChar and interprets it as no version" {
        Set-Content "TestDrive:\urltowishlistrepo\wishlist.txt" -Value "#packagethatshouldnotberead@1.0.0
package@1.0.0
package2@0.1.2.1231
package3@"

        New-Item "TestDrive:\urltoinbox\" -Name "package3" -ItemType Directory
        $packages = @(Get-ChildItem "TestDrive:\urltoinbox\" | Where-Object { $_.PSIsContainer })
        $packageVersion = "2.0.0"

        foreach ($package in $packages) {
            $packageToUpdate = Search-Wishlist -packagePath $package -packageVersion $packageVersion
            $packageToUpdate | Should -Not -Be $null
            $packageToUpdate.path | Should -Be "TestDrive:\urltofilteredinbox\package3\2.0.0"
            $packageToUpdate.name | Should -Be "package3"
            $packageToUpdate.version | Should -Be 2.0.0
        }

    }
}