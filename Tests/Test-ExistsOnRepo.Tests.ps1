BeforeAll {
    $path = Split-Path -Parent $PSCommandPath.Replace('.Tests.ps1', '.ps1').Replace('Tests', 'WASP\Private')
    $Private = @(Get-ChildItem -Path $path\*.ps1 -ErrorAction SilentlyContinue)
    foreach ($import in $Private) {
        . $import.fullname
    }
}

Describe "Package exists on repo" {
    BeforeAll {
        $ParamSplat = @{
            Repository       = "Dev"
            PackageName      = "package"
            PackageVersion   = "1.0.0"
            FileCreationDate = [datetime]"2020-09-10T14:33:46.502Z"
        }

        $EqualDateAnswer = [PSCustomObject]@{
            Content = [xml]@"
        <entry xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices" xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata" xmlns="http://www.w3.org/2005/Atom">
        <m:properties>
          <d:Published m:type="Edm.DateTime">2020-09-10T14:33:46.502Z</d:Published>
        </m:properties>
      </entry>
"@
        }
        $SmallerDateAnswer = [PSCustomObject]@{
            Content = [xml]@"
        <entry xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices" xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata" xmlns="http://www.w3.org/2005/Atom">
        <m:properties>
          <d:Published m:type="Edm.DateTime">2020-09-09T14:33:46.502Z</d:Published>
        </m:properties>
      </entry>
"@
        }
        $BiggerDateAnswer = [PSCustomObject]@{
            Content = [xml]@"
        <entry xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices" xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata" xmlns="http://www.w3.org/2005/Atom">
        <m:properties>
          <d:Published m:type="Edm.DateTime">2020-09-10T15:33:46.502Z</d:Published>
        </m:properties>
      </entry>
"@
        }

        Mock Write-Log { }
    }
    It "tests if package with a given version and exists on repo, should be false if an error is thrown" {
        Mock Invoke-WebRequest { Throw 'url not found error' }

        $test = Test-ExistsOnRepo @ParamSplat
        $test | Should -Be $false
    }

    It "tests if package with smaller date on repo exists, should be false if not exists" {
        Mock Invoke-WebRequest { $SmallerDateAnswer }

        $test = Test-ExistsOnRepo @ParamSplat
        $test | Should -Be $false
    }

    It "tests if package with a equal date exists repo, should be true if exists" {
        Mock Invoke-WebRequest { return $EqualDateAnswer }

        $test = Test-ExistsOnRepo @ParamSplat
        $test | Should -Be $true
    }

    It "tests if package with a bigger date exists repo, should be true if exists" {
        Mock Invoke-WebRequest { return $BiggerDateAnswer }

        $test = Test-ExistsOnRepo @ParamSplat
        $test | Should -Be $true
    }
}