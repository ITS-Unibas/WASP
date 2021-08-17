BeforeAll {
  $path = Split-Path -Parent $PSCommandPath.Replace('.Tests.ps1', '.ps1').Replace('Tests', 'WASP\Private')
  $Private = @(Get-ChildItem -Path $path\*.ps1 -ErrorAction SilentlyContinue)
  foreach ($import in $Private) {
    . $import.fullname
  }
}

Describe "Getting checksum type from verification file" {
  BeforeAll {
    Mock Write-Log { }
    Mock Get-VerificationFilePath { return "TestDrive:\VERIFICATION.txt" }
  }
  Context "returns md5 type as default" {
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

    It "returns md5 when path to verification file does not exist" {
      Mock Test-Path { return $False }
      Get-ChecksumTypeFromVerificationFile | Should -Be 'md5'
    }
    It "returns md5 when no checksum type is defined in verification file and checksum parameters are not given" {
      Mock Test-Path { return $True }
      Get-ChecksumTypeFromVerificationFile | Should -Be 'md5'
    }
  }

  Context "returns custom types" {
    It "returns custom type when checksum type is defined in verification file" {
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

          checksum type: SHA256
          checksum32: 759AA04D5B03EBEEE13BA01DF554E8C962CA339C74F56627C8BED6984BB7EF80
          checksum64: 0F5D4DBBE5E55B7AA31B91E5925ED901FDF46A367491D81381846F05AD54C45E

        File 'LICENSE.txt' is obtained from <http://www.7-zip.org/license.txt>"

      Mock Test-Path { return $True }
      Get-ChecksumTypeFromVerificationFile | Should -Be 'SHA256'
    }
  }
  Context "returns custom types for given checksums" {
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
    It "returns custom type if no checksum type is defined in verification file and checksum parameters are given" {
      Mock Test-Path { return $True }
      Get-ChecksumTypeFromVerificationFile -Checksums '0F5D4DBBE5E55B7AA31B91E5925ED901FDF46A367491D81381846F05AD54C45E', '759AA04D5B03EBEEE13BA01DF554E8C962CA339C74F56627C8BED6984BB7EF80' | Should -Be 'SHA256'
      Get-ChecksumTypeFromVerificationFile -Checksums '0F5D4DBBE5E55B7AA31B91E5925ED901FDF46A367491D81381846F05AD54C45E0F5D4DBBE5E55B7AA31B91E5925ED901FDF46A367491D81381846F05AD54C45E' | Should -Be 'SHA512'
      Get-ChecksumTypeFromVerificationFile -Checksums '0F5D4DBBE5E55B7AA31B91E5925ED901FDF46A36' | Should -Be 'SHA1'
      Get-ChecksumTypeFromVerificationFile -Checksums '0F5D4DBBE5E55B7AA31B91E5925ED901FDF46A360' | Should -Be 'md5'
    }
  }
}