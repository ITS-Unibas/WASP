function Get-ChecksumFromVerificationFile() {
    <#
    .SYNOPSIS
        This helper function will try to find the correct checksum in a VERIFICATION.txt file.

    .DESCRIPTION
        If this function is called and the VERIFICATION.txt file exists there will be searched for the checksum in the file by using different regex.
        Depending on the parameter input there will be searched for 32 bit checksums or 64 bit checksums.
        If there is no checksum found $Null will be returned.

    .PARAMETER searchFor32BitChecksum
        A mandatory boolean which describes if there should be searched for a 32 bit checksum if it is set to true.
        Has to be set to false if searchFor64BitChecksum is set to true!

    .PARAMETER searchFor64BitChecksum
        A mandatory boolean which describes if there should be searched for a 64 bit checksum if it is set to true.
        Has to be set to false if searchFor32BitChecksum is set to true!

    .OUTPUTS
        The checksum will be returned as a string.
    #>
    param(
        [parameter(Mandatory = $True)][bool] $searchFor32BitChecksum,
        [parameter(Mandatory = $True)][bool] $searchFor64BitChecksum
    )

    $verificationPath = "..\legal\VERIFICATION.txt"
    # Now search for a given checksum with one of the follwing patterns:
    # "(checksum32:\s[\w]+)", "(checksum64:\s[\w]+)"
    $regexChecksum32 = '(checksum32:\s[\w]+|checksum:\s[\w]+)'
    $regexChecksum64 = '(checksum64:\s[\w]+)'
    if (Test-Path $verificationPath) {
        if ($searchFor32BitChecksum) {
            Write-Log "$($packageName): Searching for 32 bit Checksum"
            $checksumMatches32 = (Select-String -Path $verificationPath -Pattern $regexChecksum32).Matches
            if ($checksumMatches32) {
                $checksum32 = $checksumMatches32 -Replace '[\s]*checksum[32]*:[\s]*', ''
                return $checksum32
            }
        }
        elseif ($searchFor64BitChecksum) {
            Write-Log "$($packageName): Searching for 64 bit Checksum"
            $checksumMatches64 = (Select-String -Path $verificationPath -Pattern $regexChecksum64).Matches
            if ($checksumMatches64) {
                $checksum64 = $checksumMatches64 -Replace '[\s]*checksum64:[\s]*', ''
                return $checksum64
            }
        }
    }
    return
}