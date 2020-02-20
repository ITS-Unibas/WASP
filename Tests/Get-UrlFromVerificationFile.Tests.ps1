$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}

Describe "Getting checksum type from verification file" {
    Mock Write-Log { }
    Mock Get-VerificationFilePath { return "TestDrive:\VERIFICATION.txt" }

    Context "returns urls for searched architectures" {
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

        It "returns md5 when path to verification file does not exist" {
            Get-UrlFromVerificationFile -searchFor32Biturl $true -searchFor64BitUrl $false | Should -Be 'http://www.7-zip.org/a/7z1900.exe'
        }
        It "returns md5 when no checksum type is defined in verification file and checksum parameters are not given" {
            Get-UrlFromVerificationFile -searchFor32Biturl $false -searchFor64BitUrl $true | Should -Be 'http://www.7-zip.org/a/7z1900-x64.exe'
        }
    }

    Context "returns any found url" {
        Set-Content "TestDrive:\verification.txt" -Value "VERIFICATION
      Verification is intended to assist the Chocolatey moderators and community
      in verifying that this package's contents are trustworthy.

      The installer have been downloaded from their official download link listed on <http://www.7-zip.org/download.html>
      and can be verified like this:

      1. Download the following installers:
        url: <http://www.7-zip.org/a/7z1900.exe>
      2. You can use one of the following methods to obtain the checksum
        - Use powershell function 'Get-Filehash'
        - Use chocolatey utility 'checksum.exe'

        checksum type:
        checksum32: 759AA04D5B03EBEEE13BA01DF554E8C962CA339C74F56627C8BED6984BB7EF80
        checksum64: 0F5D4DBBE5E55B7AA31B91E5925ED901FDF46A367491D81381846F05AD54C45E

      File 'LICENSE.txt' is obtained from <http://www.7-zip.org/license.txt>"

        It "returns md5 when path to verification file does not exist" {
            Get-UrlFromVerificationFile -searchFor32Biturl $true -searchFor64BitUrl $false | Should -Be 'http://www.7-zip.org/a/7z1900.exe'
        }
        It "returns md5 when no checksum type is defined in verification file and checksum parameters are not given" {
            Get-UrlFromVerificationFile -searchFor32Biturl $false -searchFor64BitUrl $true | Should -Be 'http://www.7-zip.org/a/7z1900.exe'
        }
    }
    Context "returns none if no url with appropriate file ending is found" {
        Set-Content "TestDrive:\verification.txt" -Value "VERIFICATION
      Verification is intended to assist the Chocolatey moderators and community
      in verifying that this package's contents are trustworthy.

      The installer have been downloaded from their official download link listed on <http://www.7-zip.org/download.html>
      and can be verified like this:

      1. Download the following installers:
        url: <insert-here>
      2. You can use one of the following methods to obtain the checksum
        - Use powershell function 'Get-Filehash'
        - Use chocolatey utility 'checksum.exe'

        checksum type:
        checksum32: 759AA04D5B03EBEEE13BA01DF554E8C962CA339C74F56627C8BED6984BB7EF80
        checksum64: 0F5D4DBBE5E55B7AA31B91E5925ED901FDF46A367491D81381846F05AD54C45E

      File 'LICENSE.txt' is obtained from <http://www.7-zip.org/license.txt>"

        It "returns md5 when path to verification file does not exist" {
            Get-UrlFromVerificationFile -searchFor32Biturl $true -searchFor64BitUrl $false | Should -Be $null
        }
        It "returns md5 when no checksum type is defined in verification file and checksum parameters are not given" {
            Get-UrlFromVerificationFile -searchFor32Biturl $false -searchFor64BitUrl $true | Should -Be $null
        }
    }
}