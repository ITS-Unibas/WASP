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
        [Parameter(Mandatory=$true)]
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
        foreach($Line in $GitIgnoreContent) {
            Remove-Item -Path (Join-Path $PackagePath $Line)
        }
    }

    end {
    }
}