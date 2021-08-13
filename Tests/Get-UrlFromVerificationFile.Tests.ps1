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
  Context "returns urls for searched architectures" {
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

    It "returns url for 32 bit" {
      Get-UrlFromVerificationFile -searchFor32Biturl $true -searchFor64BitUrl $false | Should -Be 'http://www.7-zip.org/a/7z1900.exe'
    }
    It "returns url for 64 bit" {
      Get-UrlFromVerificationFile -searchFor32Biturl $false -searchFor64BitUrl $true | Should -Be 'http://www.7-zip.org/a/7z1900-x64.exe'
    }
  }


  Context "returns first matched urls for searched architectures" {
    BeforeEach {
      Set-Content "TestDrive:\verification.txt" -Value "VERIFICATION
      Verification is intended to assist the Chocolatey moderators and community
      in verifying that this package's contents are trustworthy.

      The installer have been downloaded from their official download link listed on <http://www.7-zip.org/download.html>
      and can be verified like this:

      1. Download the following installers:
        32-Bit: <http://www.7-zip.org/a/7z1900.exe>
        32-Bit: <http://www.7-zip.org/a/7z1901.exe>
        64-Bit: <http://www.7-zip.org/a/7z1900-x64.exe>
        64-Bit: <http://www.7-zip.org/a/7z1901-x64.exe>
      2. You can use one of the following methods to obtain the checksum
        - Use powershell function 'Get-Filehash'
        - Use chocolatey utility 'checksum.exe'

        checksum type:
        checksum32: 759AA04D5B03EBEEE13BA01DF554E8C962CA339C74F56627C8BED6984BB7EF80
        checksum64: 0F5D4DBBE5E55B7AA31B91E5925ED901FDF46A367491D81381846F05AD54C45E

      File 'LICENSE.txt' is obtained from <http://www.7-zip.org/license.txt>"
    }
    It "returns url for 32 bit" {
      Get-UrlFromVerificationFile -searchFor32Biturl $true -searchFor64BitUrl $false | Should -Be 'http://www.7-zip.org/a/7z1900.exe'
    }
    It "returns url for 64 bit" {
      Get-UrlFromVerificationFile -searchFor32Biturl $false -searchFor64BitUrl $true | Should -Be 'http://www.7-zip.org/a/7z1900-x64.exe'
    }
  }

  Context "returns any found url" {
    BeforeEach {
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
    }
    It "returns any url when specified architecture 32 bit url is not found" {
      Get-UrlFromVerificationFile -searchFor32Biturl $true -searchFor64BitUrl $false | Should -Be 'http://www.7-zip.org/a/7z1900.exe'
    }
    It "returns any url when specified architecture 64 bit url is not found" {
      Get-UrlFromVerificationFile -searchFor32Biturl $false -searchFor64BitUrl $true | Should -Be $None
    }
  }
  Context "returns none if no url with appropriate file ending is found" {
    BeforeEach {
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
    }
    It "returns none when specified architecture 32 bit url is not found" {
      Get-UrlFromVerificationFile -searchFor32Biturl $true -searchFor64BitUrl $false | Should -Be $null
    }
    It "returns none when specified architecture 64 bit url is not found" {
      Get-UrlFromVerificationFile -searchFor32Biturl $false -searchFor64BitUrl $true | Should -Be $null
    }
  }
  Context "returns correct url when it does include a tilde" {
    BeforeEach {
      Set-Content "TestDrive:\verification.txt" -Value "VERIFICATION
    Verification is intended to assist the Chocolatey moderators and community
    in verifying that this package's contents are trustworthy.

    The extension has been downloaded from their official download link listed on <http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html>
    and can be verified like this:


    1. Download the following installers:
      32-Bit: <https://the.earth.li/~sgtatham/putty/latest/w32/putty-0.74-installer.msi>
      64-Bit: <https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.74-installer.msi>
    2. You can use one of the following methods to obtain the checksum
      - Use powershell function 'Get-Filehash'
      - Use chocolatey utility 'checksum.exe'

      checksum type: sha256
      checksum32: A630B507D726D7B378F1D82108B99FE7A0CC8713F7182957325AD07CF288228C
      checksum64: 2A001DD1C5D81AE1C17DB97B0BB6C2C7CADA43888D4F30A814C18D55AA28FEB6

    File 'LICENSE.txt' is obtained from <http://www.chiark.greenend.org.uk/~sgtatham/putty/licence.html>"
    }
    It "returns url for 32 bit" {
      Get-UrlFromVerificationFile -searchFor32Biturl $true -searchFor64BitUrl $false | Should -Be 'https://the.earth.li/~sgtatham/putty/latest/w32/putty-0.74-installer.msi'
    }
    It "returns url for 64 bit" {
      Get-UrlFromVerificationFile -searchFor32Biturl $false -searchFor64BitUrl $true | Should -Be 'https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.74-installer.msi'
    }
  }
}