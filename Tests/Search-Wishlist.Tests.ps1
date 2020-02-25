$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}

Describe "Finding package name in wishlist" {
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
    New-Item "TestDrive:\" -Name "urltofilteredinbox" -ItemType Directory

    Set-Content "TestDrive:\urltowishlistrepo\wishlist.txt" -Value "
    #packagethatshouldnotberead@1.0.0
    package@1.0.0
    package2@0.1.2.123
    package3"

    It "Finds no package name" {
        New-Item "TestDrive:\urltofilteredinbox\" -Name "package4" -ItemType Directory
        $packages = @(Get-ChildItem "TestDrive:\urltofilteredinbox\" | Where-Object { $_.PSIsContainer })
        $packageVersion = "2.0.0"

        foreach ($package in $packages) {
            $packageToUpdate = Search-Wishlist -packagePath $package -packageVersion $packageVersion
            $packageToUpdate | Should -Be $null
        }
    }

    It "Finds package name and has no new package version" {
        New-Item "TestDrive:\urltofilteredinbox\" -Name "package" -ItemType Directory
        $packages = @(Get-ChildItem "TestDrive:\urltofilteredinbox\" | Where-Object { $_.PSIsContainer })
        $packageVersion = "1.0.0"

        foreach ($package in $packages) {
            $packageToUpdate = Search-Wishlist -packagePath $package -packageVersion $packageVersion
            $packageToUpdate| Should -Be $null
        }
    }

    It "Finds package name and has new package version" {
        New-Item "TestDrive:\urltofilteredinbox\" -Name "package" -ItemType Directory
        $packages = @(Get-ChildItem "TestDrive:\urltofilteredinbox\" | Where-Object { $_.PSIsContainer })
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
        New-Item "TestDrive:\urltofilteredinbox\" -Name "package" -ItemType Directory
        $packages = @(Get-ChildItem "TestDrive:\urltofilteredinbox\" | Where-Object { $_.PSIsContainer })
        $packageVersion = "2.r.d.0"

        foreach ($package in $packages) {
            $packageToUpdate = Search-Wishlist -packagePath $package -packageVersion $packageVersion
            $packageToUpdate | Should -Not -Be $null
            $packageToUpdate.path | Should -Be "TestDrive:\urltofilteredinbox\package\2.0.0.0"
            $packageToUpdate.name | Should -Be "package"
            $packageToUpdate.version | Should -Be 2.0.0.0
        }
    }

    # TODO: Add test if multiple packages can be updated at once

    AfterEach {
        Get-ChildItem "TestDrive:\urltofilteredinbox\" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }
}