function Copy-PreviousInstallerFile {

    [CmdletBinding()]
    param (
        [Parameter()]
        [TypeName]
        $InstallerFilePath
    )

    begin {

    }

    process {
        # Replace version by generic $env:ChocolateyPackageVersion

        # check if msi or exe package:
        $InstallerContent = Get-Content -Path $InstallerFilePath -ErrorAction Stop
        # If content contains exe or msi, adapt the filter

        # Replace file with $file = Get-ChildItem . -Filter "*.msi" | Select-Object -ExpandProperty FullName
        $file = Get-ChildItem $toolsPath -Filter "*.msi" | Select-Object -ExpandProperty FullName
        if (-Not $file) {
            $file = Get-ChildItem $toolsPath -Filter "*.exe" | Select-Object -ExpandProperty FullName
        }

    }

    end {

    }
}