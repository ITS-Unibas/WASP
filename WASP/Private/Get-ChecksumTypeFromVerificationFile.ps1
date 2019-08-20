<#
  .SYNOPSIS
    This helper function will try to find the correct checksum type in a VERIFICATION.txt file.

  .DESCRIPTION
    If this function is called and the VERIFICATION.txt file exists there will be searched for the checksumType in the file by using a regex.
    If there is no match with the regex the default "sha256" will be returned.

  .OUTPUTS
    The checksumType will be returned as a string.
#>
function Get-ChecksumTypeFromVerificationFile() {
    $verificationPath = "..\legal\VERIFICATION.txt"
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