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

    Set-Content "TestDrive:\urltowishlistrepo\wishlist.txt" -Value "
    #packagethatshouldnotberead@1.0.0\n
    package@1.0.0\n
    package2@0.1.2.123\n
    package3\n
    "

    It "Finds no package name" {
        $packageName = "package4"
        $packageVersion = "2.0.0"

        Search-Wishlist -packageName $packageName -packageVersion $packageVersion | Should -Be $null
    }

    It "Finds no package name" {
        $packageName = "package"
        $packageVersion = "2.0.0"

        Search-Wishlist -packageName $packageName -packageVersion $packageVersion | Should -Be @("package")
    }
}