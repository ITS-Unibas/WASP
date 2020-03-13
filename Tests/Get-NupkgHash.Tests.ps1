$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
  . $import.fullname
}

Describe "Getting hash of nupkg" {

  BeforeEach {
    New-Item "TestDrive:\" -Name "sources" -ItemType Directory -Force
    New-Item "TestDrive:\sources\" -Name "tools" -ItemType Directory -Force
    New-Item "TestDrive:\sources\" -Name "legal" -ItemType Directory -Force
    Set-Content "TestDrive:\sources\package.nuspec" -Value "Content nuspec" -Force
    Set-Content "TestDrive:\sources\tools\chocoInstall.ps1" -Value "Content choco install" -Force
    Set-Content "TestDrive:\sources\legal\verification.txt" -Value "Content verification" -Force
    Set-Content "TestDrive:\sources\.README" -Value "READ ME PLEASE" -Force

    New-Item "TestDrive:\" -Name "nupkg" -ItemType Directory

    Compress-Archive -Path "TestDrive:\sources\*" -DestinationPath "TestDrive:\nupkg\package.zip" -Force
    Rename-Item -Path "TestDrive:\nupkg\package.zip" -NewName "package.nupkg"

    $nupkgPath = "TestDrive:\nupkg\package.nupkg"
    $packageFolder = "TestDrive:\nupkg"
  }

  AfterEach {
    Remove-Item "TestDrive:\*" -Recurse -Force
  }

  It "hashes contents of nupkg" {
    $hash = Get-NupkgHash $nupkgPath $packageFolder
    $hash | Should -Be -Not $null
  }

  It "has the same hash if nothing is changed" {
    $hash = Get-NupkgHash $nupkgPath $packageFolder
    Remove-Item "TestDrive:\*" -Recurse -Force

    New-Item "TestDrive:\" -Name "sources" -ItemType Directory -Force
    New-Item "TestDrive:\sources\" -Name "tools" -ItemType Directory -Force
    New-Item "TestDrive:\sources\" -Name "legal" -ItemType Directory -Force
    Set-Content "TestDrive:\sources\package.nuspec" -Value "Content nuspec" -Force
    Set-Content "TestDrive:\sources\tools\chocoInstall.ps1" -Value "Content choco install" -Force
    Set-Content "TestDrive:\sources\legal\verification.txt" -Value "Content verification" -Force
    Set-Content "TestDrive:\sources\.README" -Value "READ ME PLEASE" -Force

    New-Item "TestDrive:\" -Name "nupkg" -ItemType Directory

    Compress-Archive -Path "TestDrive:\sources\*" -DestinationPath "TestDrive:\nupkg\package.zip" -Force
    Rename-Item -Path "TestDrive:\nupkg\package.zip" -NewName "package.nupkg"
    $newhash = Get-NupkgHash $nupkgPath $packageFolder
    $hash | Should -BeExactly $newhash
  }

  It "changes to the readme do not have an effect to the hash" {
    $hash = Get-NupkgHash $nupkgPath $packageFolder
    Remove-Item "TestDrive:\nupkg\package.nupkg" -Recurse -Force
    Set-Content "TestDrive:\sources\.README" -Value "READ ME PLEASE!" -Force
    Compress-Archive -Path "TestDrive:\sources\*" -DestinationPath "TestDrive:\nupkg\package.zip" -Force
    Rename-Item -Path "TestDrive:\nupkg\package.zip" -NewName "package.nupkg" -Force
    $newhash = Get-NupkgHash $nupkgPath $packageFolder
    $hash | Should -BeExactly $newhash
  }

  It "tests hash for changes to file in \tools directory" {
    $hash = Get-NupkgHash $nupkgPath $packageFolder
    Remove-Item "TestDrive:\nupkg\package.nupkg" -Recurse -Force
    Set-Content "TestDrive:\sources\tools\chocoInstall.ps1" -Value "Content choco install altered" -Force
    Compress-Archive -Path "TestDrive:\sources\*" -DestinationPath "TestDrive:\nupkg\package.zip" -Force
    Rename-Item -Path "TestDrive:\nupkg\package.zip" -NewName "package.nupkg" -Force
    $newhash = Get-NupkgHash $nupkgPath $packageFolder
    $hash | Should -Not -BeExactly $newhash
  }

  It "tests hash for changes to file in \legal directory" {
    $hash = Get-NupkgHash $nupkgPath $packageFolder
    Remove-Item "TestDrive:\nupkg\package.nupkg" -Recurse -Force
    Set-Content "TestDrive:\sources\legal\verification.txt" -Value "Content verification altered" -Force
    Compress-Archive -Path "TestDrive:\sources\*" -DestinationPath "TestDrive:\nupkg\package.zip" -Force
    Rename-Item -Path "TestDrive:\nupkg\package.zip" -NewName "package.nupkg" -Force
    $newhash = Get-NupkgHash $nupkgPath $packageFolder
    $hash | Should -Not -BeExactly $newhash
  }
}