function Get-ChecksumTypeFromVerificationFile() {
    <#
    .SYNOPSIS
        This helper function will try to find the correct checksum type in a VERIFICATION.txt file.

    .DESCRIPTION
        If this function is called and the VERIFICATION.txt file exists there will be searched for the checksumType in the file by using a regex.
        If there is no match with the regex the default "sha256" will be returned.

    .OUTPUTS
        The checksumType will be returned as a string.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $packageName
    )

    $Config = Read-ConfigFile
    $GitRepo = $config.Application.PackageGallery
    $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
    $GitFolderName = $GitFile.Replace(".git", "")
    $PackageGalleryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

    $verificationPath = Join-Path -Path $PackageGalleryPath -ChildPath (Join-Path -Path $packageName -ChildPath "legal\VERIFICATION.txt")
    # Now search for a given url with one of the follwing patterns:
    # "x32: http...", "x86: http...", "32-bit: <http...>", "64-bit: <http...>"
    $regexChecksumType = '(checksum\stype:[\s]*[\w]+)'
    if (Test-Path $verificationPath) {
        $checksumTypeMatches = (Select-String -Path $verificationPath -Pattern $regexChecksumType).Matches
        if ($checksumTypeMatches) {
            $checksumType = $checksumTypeMatches -Replace 'checksum\stype:[\s]*', ''
            return $checksumType
        }
    }
    return 'md5'
}