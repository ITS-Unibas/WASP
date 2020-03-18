$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}

Describe "Building path to verification file" {
    $test = '{
        "Application": {
            "PackageGallery": "git.its.unibas.ch/scm/csswcs/package-gallery.git",
            "GitBranchDEV": "dev/",
            "BaseDirectory": "TestDrive:\\"
        }
    }'

    Mock Read-ConfigFile { return ConvertFrom-Json $test }
    Mock Get-CurrentBranchName { return 'dev/fancyPackage@1.0.0' }

    It "returns a path to verification file" {
        $path = Get-VerificationFilePath
        $path | Should -Be "TestDrive:\package-gallery\fancyPackage@1.0.0\legal\VERIFICATION.txt"
    }
}