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
        [string[]]
        $Checksums
    )

    $verificationPath = Get-VerificationFilePath
    # Now search for a given url with one of the follwing patterns:
    # "x32: http...", "x86: http...", "32-bit: <http...>", "64-bit: <http...>"
    $regexChecksumType = '(checksum\stype:[\s]*[\w]+)'
    if (Test-Path $verificationPath) {
        $checksumTypeMatches = (Select-String -Path $verificationPath -Pattern $regexChecksumType).Matches
        if ($checksumTypeMatches) {
            $checksumType = $checksumTypeMatches -Replace 'checksum\stype:[\s]*', ''
            return $checksumType
        } else {
            foreach($Checksum in $Checksums) {
                if ($Checksum.Length -eq 64) {
                    return "SHA256"
                } elseif($Checksum.Length -eq 128) {
                    return "SHA512"
                } elseif ($Checksum.Length -eq 40) {
                    return "SHA1"
                }
            }
        }
    }
    return 'md5'
}