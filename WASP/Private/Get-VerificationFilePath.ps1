function Get-VerificationFilePath {
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

    )

    begin {
        $Config = Read-ConfigFile
        $GitRepo = $config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackageGalleryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }

    process {
        $branch = Get-CurrentBranchName -$PackageGalleryPath
        $packageName, $packageVersion = $branch.split($nameAndVersionSeparator)
        $packageName = $packageName -Replace $config.Application.GitBranchDEV, ''
        $PackagePath = Join-Path -Path $PackageGalleryPath -ChildPath $packageName
        $PackageVersionPath = Join-Path -Path $PackagePath -ChildPath $packageVersion
        $verificationPath = Join-Path -Path $PackageVersionPath -ChildPath "legal\VERIFICATION.txt"
    }

    end {
        return $verificationPath
    }
}