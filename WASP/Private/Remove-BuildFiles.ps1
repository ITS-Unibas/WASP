function Remove-BuildFiles {
    <#
    .SYNOPSIS
        Short description
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $PackagePath
    )

    begin {
        $Config = Read-ConfigFile
        $GitRepo = $config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackageGalleryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
        $GitIgnorePath = Join-Path -Path $PackageGalleryPath -ChildPath ".gitignore"
    }

    process {
        $GitIgnoreContent = Get-Content $GitIgnorePath
        foreach ($Line in $GitIgnoreContent) {
            # .nupkg files will be left over, so we can move the nupkg onto the next instance on the repo server.
            # TODO: maybe there is a better solution for this.
            if ($Line -notlike "*nupkg*") {
                $path = Join-Path $PackagePath $Line
                Write-Log "Removing $path"
                Remove-Item -Path $path -ErrorAction SilentlyContinue
            }
        }
    }

    end {
    }
}