$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}

Describe 'Search new package' {

    Context "Check list handling" {
        BeforeAll {
            $NuspecItem = New-Item "TestDrive:\chocolatey-packages\automatic\7zip.install\19.0\7zip.install.nuspec" -Force
            $NuspecContent = @"
<?xml version=`"1.0`" encoding=`"utf-8`"?>
<package xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`">
    <metadata>
    <id>7zip.install</id>
    <title>7-Zip (Install)</title>
    <version>19.0</version>
    <authors>Igor Pavlov</authors>
    <owners>chocolatey,Rob Reynolds</owners>
    <summary>7-Zip is a file archiver with a high compression ratio.</summary>
    <description>7-Zip is a file archiver with a high compression ratio.
    </description>
    <projectUrl>http://www.7-zip.org/</projectUrl>
    <packageSourceUrl>https://github.com/chocolatey/chocolatey-coreteampackages/tree/master/automatic/7zip.install</packageSourceUrl>
    <tags>7zip zip archiver admin cross-platform cli foss</tags>
    <licenseUrl>http://www.7-zip.org/license.txt</licenseUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <iconUrl>https://cdn.jsdelivr.net/gh/chocolatey/chocolatey-coreteampackages@68b91a851cee97e55c748521aa6da6211dd37c98/icons/7zip.svg</iconUrl>
    <docsUrl>http://www.7-zip.org/faq.html</docsUrl>
    <mailingListUrl>https://sourceforge.net/p/sevenzip/discussion/45797/</mailingListUrl>
    <bugTrackerUrl>https://sourceforge.net/p/sevenzip/_list/tickets?source=navbar</bugTrackerUrl>
    <dependencies></dependencies>
    </metadata>
    <files>
    <file src='tools\**' target='tools' />
    </files>
</package>
"@
            Set-Content $NuspecItem.FullName -Value $NuspecContent
            $Packages = @(Get-ChildItem "TestDrive:\chocolatey-packages\automatic" | Where-Object { $_.PSIsContainer })

        }

        BeforeEach {
            $newPackages = New-Object System.Collections.ArrayList
            $newPackages.Add((New-Object psobject @{'path' = $TestDrive; 'name' = 'testpackage'; 'version' = '1.0.0' }))
        }

        AfterEach {
            $newPackages = $null
        }

        AfterAll {
            Remove-Item "TestDrive:\chocolatey-packages\automatic\7zip.install\19.0\7zip.install.nuspec"
            $Packages = $null
        }

        It "Should not overwrite already found package with new packages" {
            Mock Search-Wishlist { New-Object psobject @{'path' = $NuspecItem.FullName; 'name' = '7zip.install'; 'version' = '19.0' } }
            $newPackages.Count | Should -BeExactly 1
            $newPackages = Search-NewPackages -Packages $Packages -NewPackagesList $newPackages
            $newPackages.Count | Should -BeExactly 2
            $newPackages[1].name | Should -MatchExactly '7zip.install'
        }

        It "Should not overwrite with empty arraylist" {
            Mock Search-Wishlist { }
            $newPackages.Count | Should -BeExactly 1
            $newPackages = Search-NewPackages -Packages $Packages -NewPackagesList $newPackages
            $newPackages.Count | Should -BeExactly 1
        }

        It "Should find more than one package" {
            $NuspecItem2 = New-Item "TestDrive:\chocolatey-packages\automatic\anotherpackage\19.0\anotherpackage.nuspec" -Force
            $NuspecContent2 = @"
<?xml version=`"1.0`" encoding=`"utf-8`"?>
<package xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`">
    <metadata>
    <id>7zip.install</id>
    <title>7-Zip (Install)</title>
    <version>19.0</version>
    <authors>Igor Pavlov</authors>
    <owners>chocolatey,Rob Reynolds</owners>
    <summary>7-Zip is a file archiver with a high compression ratio.</summary>
    <description>7-Zip is a file archiver with a high compression ratio.
    </description>
    <projectUrl>http://www.7-zip.org/</projectUrl>
    <packageSourceUrl>https://github.com/chocolatey/chocolatey-coreteampackages/tree/master/automatic/7zip.install</packageSourceUrl>
    <tags>7zip zip archiver admin cross-platform cli foss</tags>
    <licenseUrl>http://www.7-zip.org/license.txt</licenseUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <iconUrl>https://cdn.jsdelivr.net/gh/chocolatey/chocolatey-coreteampackages@68b91a851cee97e55c748521aa6da6211dd37c98/icons/7zip.svg</iconUrl>
    <docsUrl>http://www.7-zip.org/faq.html</docsUrl>
    <mailingListUrl>https://sourceforge.net/p/sevenzip/discussion/45797/</mailingListUrl>
    <bugTrackerUrl>https://sourceforge.net/p/sevenzip/_list/tickets?source=navbar</bugTrackerUrl>
    <dependencies></dependencies>
    </metadata>
    <files>
    <file src='tools\**' target='tools' />
    </files>
</package>
"@
            Set-Content $NuspecItem2.FullName -Value $NuspecContent2
            $script:mockCount = 0
            $ScriptBlock = {
                if ($script:mockCount -eq 1) {
                    return New-Object psobject @{'path' = $NuspecItem2.FullName; 'name' = 'anotherpackage'; 'version' = '19.0' }
                }
                $script:mockCount += 1
                return New-Object psobject @{'path' = $NuspecItem.FullName; 'name' = '7zip.install'; 'version' = '19.0' }

            }
            Mock Search-Wishlist -MockWith $ScriptBlock
            $Packages = @(Get-ChildItem "TestDrive:\chocolatey-packages\automatic" | Where-Object { $_.PSIsContainer })
            $newPackages.Count | Should -BeExactly 1
            $newPackages = Search-NewPackages -Packages $Packages -NewPackagesList $newPackages
            $newPackages.Count | Should -BeExactly 3
            Assert-MockCalled Search-Wishlist -Times 2
        }
    }

    Context "Check error handling" {
        Mock Write-Log { }
        It "Should call Write-Log when nuspec is not in correct schema" {
            Mock Search-Wishlist { }
            $NuspecItem = New-Item "TestDrive:\chocolatey-packages\automatic\7zip.install\19.0\7zip.install.nuspec" -Force
            $NuspecContent = @"
    <metadata>
    <id>7zip.install</id>
    <version>19.0</version>
    <title>7-Zip (Install)</title>
    <authors>Igor Pavlov</authors>
    <owners>chocolatey,Rob Reynolds</owners>
    <summary>7-Zip is a file archiver with a high compression ratio.</summary>
    <description>7-Zip is a file archiver with a high compression ratio.
    </description>
    <projectUrl>http://www.7-zip.org/</projectUrl>
    <packageSourceUrl>https://github.com/chocolatey/chocolatey-coreteampackages/tree/master/automatic/7zip.install</packageSourceUrl>
    <tags>7zip zip archiver admin cross-platform cli foss</tags>
    <licenseUrl>http://www.7-zip.org/license.txt</licenseUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <iconUrl>https://cdn.jsdelivr.net/gh/chocolatey/chocolatey-coreteampackages@68b91a851cee97e55c748521aa6da6211dd37c98/icons/7zip.svg</iconUrl>
    <docsUrl>http://www.7-zip.org/faq.html</docsUrl>
    <mailingListUrl>https://sourceforge.net/p/sevenzip/discussion/45797/</mailingListUrl>
    <bugTrackerUrl>https://sourceforge.net/p/sevenzip/_list/tickets?source=navbar</bugTrackerUrl>
    <dependencies></dependencies>
    </metadata>
    <files>
    <file src='tools\**' target='tools' />
    </files>
</package>
"@
            Set-Content $NuspecItem.FullName -Value $NuspecContent
            $Packages = @(Get-ChildItem "TestDrive:\chocolatey-packages\automatic" | Where-Object { $_.PSIsContainer })
            $newPackages = New-Object System.Collections.ArrayList
            $newPackages = Search-NewPackages -Packages $Packages -NewPackagesList $newPackages
            Assert-MockCalled Write-Log -Times 2
        }

        It "Should not crash, if nuspec is missing" {
            Mock Search-Wishlist { New-Object psobject @{'path' = $NuspecItem.FullName; 'name' = '7zip.install'; 'version' = '19.0' } }
            New-Item "TestDrive:\chocolatey-packages\automatic\7zip.install\19.0" -Force -ItemType Directory
            $Packages = @(Get-ChildItem "TestDrive:\chocolatey-packages\automatic" | Where-Object { $_.PSIsContainer })
            $newPackages = New-Object System.Collections.ArrayList
            $newPackages = Search-NewPackages -Packages $Packages -NewPackagesList $newPackages
            $newPackages.Count | Should -BeExactly 0
        }

        It "Should not crash, if more than one nuspec is found" {
            Mock Search-Wishlist { New-Object psobject @{'path' = $NuspecItem.FullName; 'name' = '7zip.install'; 'version' = '19.0' } }
            New-Item "TestDrive:\chocolatey-packages\automatic\7zip.install\19.0\7zip.install.nuspec" -Force
            New-Item "TestDrive:\chocolatey-packages\automatic\7zip.install\19.0\second.nuspec" -Force
            $Packages = @(Get-ChildItem "TestDrive:\chocolatey-packages\automatic" | Where-Object { $_.PSIsContainer })
            $newPackages = New-Object System.Collections.ArrayList
            $newPackages = Search-NewPackages -Packages $Packages -NewPackagesList $newPackages
            $newPackages.Count | Should -BeExactly 0
        }
    }

    Context "Handle packages from packages-manual" {
        BeforeAll {
            1..3 | ForEach-Object {
                $NuspecItem = New-Item "TestDrive:\packages-manual\package\$_.0\package.nuspec" -Force
                $NuspecContent = @"
<?xml version=`"1.0`" encoding=`"utf-8`"?>
<package xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`">
    <metadata>
    <id>package</id>
    <title>7-Zip (Install)</title>
    <version>$_.</version>
    <authors>Igor Pavlov</authors>
    <owners>chocolatey,Rob Reynolds</owners>
    <summary>7-Zip is a file archiver with a high compression ratio.</summary>
    <description>7-Zip is a file archiver with a high compression ratio.
    </description>
    <projectUrl>http://www.7-zip.org/</projectUrl>
    <packageSourceUrl>https://github.com/chocolatey/chocolatey-coreteampackages/tree/master/automatic/7zip.install</packageSourceUrl>
    <tags>7zip zip archiver admin cross-platform cli foss</tags>
    <licenseUrl>http://www.7-zip.org/license.txt</licenseUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <iconUrl>https://cdn.jsdelivr.net/gh/chocolatey/chocolatey-coreteampackages@68b91a851cee97e55c748521aa6da6211dd37c98/icons/7zip.svg</iconUrl>
    <docsUrl>http://www.7-zip.org/faq.html</docsUrl>
    <mailingListUrl>https://sourceforge.net/p/sevenzip/discussion/45797/</mailingListUrl>
    <bugTrackerUrl>https://sourceforge.net/p/sevenzip/_list/tickets?source=navbar</bugTrackerUrl>
    <dependencies></dependencies>
    </metadata>
    <files>
    <file src='tools\**' target='tools' />
    </files>
</package>
"@
                Set-Content $NuspecItem.FullName -Value $NuspecContent
            }
            $packagesManual = @(Get-ChildItem "TestDrive:\packages-manual\")
        }

        It "Should be able to find a manual packages with more than one version" {
            $packagesManual.Count | Should -BeExactly 1
            Mock Search-Wishlist {New-Object psobject @{'path' = $NuspecItem.FullName; 'name' = 'package'; 'version' = '3.0' }}
            $newPackages = New-Object System.Collections.ArrayList
            $newPackages = Search-NewPackages -Packages $packagesManual -NewPackagesList $newPackages -Manual
            Assert-MockCalled Search-Wishlist -Times 1
            $newPackages.Count | Should -BeExactly 1
        }
    }
}