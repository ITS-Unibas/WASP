BeforeAll {
    $path = Split-Path -Parent $PSCommandPath.Replace('.Tests.ps1', '.ps1').Replace('Tests', 'WASP\Private')
    $Private = @(Get-ChildItem -Path $path\*.ps1 -ErrorAction SilentlyContinue)
    foreach ($import in $Private) {
        . $import.fullname
    }
}

Describe "Getting checksum from verification file" {
    BeforeAll {
        Mock Write-Log { }
        Mock Get-VerificationFilePath { return "TestDrive:\VERIFICATION.txt" }
    }
    Context "No verification file exists" {
        It "does not find the verification file in path" {
            Get-ChecksumFromVerificationFile -searchFor32BitChecksum $False -searchFor64BitChecksum $False | Should -Be $null
            Assert-MockCalled Write-Log -Exactly 0 -Scope It
        }
    }

    Context "Verification file exists" {
        BeforeEach {
            Set-Content "TestDrive:\verification.txt" -Value "VERIFICATION
                Verification is intended to assist the Chocolatey moderators and community
                in verifying that this package's contents are trustworthy.

                The installer have been downloaded from their official download link listed on <http://www.7-zip.org/download.html>
                and can be verified like this:

                1. Download the following installers:
                32-Bit: <http://www.7-zip.org/a/7z1900.exe>
                64-Bit: <http://www.7-zip.org/a/7z1900-x64.exe>
                2. You can use one of the following methods to obtain the checksum
                - Use powershell function 'Get-Filehash'
                - Use chocolatey utility 'checksum.exe'

                checksum type:
                checksum32: 759AA04D5B03EBEEE13BA01DF554E8C962CA339C74F56627C8BED6984BB7EF80
                checksum64: 0F5D4DBBE5E55B7AA31B91E5925ED901FDF46A367491D81381846F05AD54C45E

                File 'LICENSE.txt' is obtained from <http://www.7-zip.org/license.txt>"
        }

        It "finds verification file but no architecture specified" {
            Get-ChecksumFromVerificationFile -searchFor32BitChecksum $False -searchFor64BitChecksum $False | Should -Be $null
            Assert-MockCalled Write-Log -Exactly 0 -Scope It
        }
        It "finds verification file and checks for 32bit checksum" {
            Get-ChecksumFromVerificationFile -searchFor32BitChecksum $True -searchFor64BitChecksum $False | Should -Be "759AA04D5B03EBEEE13BA01DF554E8C962CA339C74F56627C8BED6984BB7EF80"
            Assert-MockCalled Write-Log -Exactly 1 -Scope It
        }
        It "finds verification file and checks for 64bit checksum" {
            Get-ChecksumFromVerificationFile -searchFor32BitChecksum $False -searchFor64BitChecksum $True | Should -Be "0F5D4DBBE5E55B7AA31B91E5925ED901FDF46A367491D81381846F05AD54C45E"
            Assert-MockCalled Write-Log -Exactly 1 -Scope It
        }
    }
}