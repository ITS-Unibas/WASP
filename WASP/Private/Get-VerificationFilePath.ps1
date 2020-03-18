function Get-VerificationFilePath {
    <#
    .SYNOPSIS
        Builds path to "legal\VERIFICATION.txt" of a package
    .DESCRIPTION
        Uses package path and version on development branch to build path to verification file.
    .EXAMPLE
        PS C:\> Get-VerificationFilePath
    .OUTPUTS
        Path to file
    .NOTES
        CAUTION: this method only builds the path, the existence check is performed when reading from the file
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
        $branch = Get-CurrentBranchName $PackageGalleryPath
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