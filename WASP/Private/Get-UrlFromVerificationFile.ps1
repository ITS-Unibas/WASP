function Get-UrlFromVerificationFile() {
    <#
    .SYNOPSIS
        This helper function will try to find the correct url in a VERIFICATION.txt file.

    .DESCRIPTION
        If this function is called and the VERIFICATION.txt file exists there will be searched for the url in the file by using different regex.
        Depending on the parameter input there will be searched for a 32 bit url or a 64 bit url. If for the specified url type a url cannot be found,
        a more generic regex is used to check if there is any url in the document with an executable file ending.
        If there is no url found $Null will be returned.

    .PARAMETER searchFor32BitUrl
        A mandatory boolean which describes if there should be searched for a 32 bit url if it is set to true.
        Has to be set to false if searchFor64Url is set to true!

    .PARAMETER searchFor64BitUrl
        A mandatory boolean which describes if there should be searched for a 64 bit url if it is set to true.
        Has to be set to false if searchFor32BitUrl is set to true!

    .OUTPUTS
        The first found url will be returned as a string if found, $none is returned otherwise.
    #>
    param(
        [parameter(Mandatory = $true)][bool] $searchFor32BitUrl,
        [parameter(Mandatory = $true)][bool] $searchFor64BitUrl

    )

    $verificationPath = Get-VerificationFilePath

    # Now search for a given url with one of the follwing patterns:
    # "x32: http...", "x86: http...", "32-bit: <http...>", "64-bit: <http...>"
    $regex32 = '(x32:\s.*|32-Bit:\s<.*>|x86:\s.*|32-Bit software:\s<.*>)'
    $regex64 = '(x64:\s.*|64-Bit:\s<.*>|64-Bit software:\s<.*>)'
    $regexLink = '(http[:/\w\d.~?&%^$=#\-@+\*]*)'

    if (Test-Path $verificationPath) {
        if ($searchFor32BitUrl) {
            # We only want to search for 32bit urls in our verification text
            Write-Log "$($packageName): Searching for 32bit urls"
            $matches32 = (Select-String -Path $verificationPath -Pattern $regex32).Matches
            if ($matches32) {
                $url32Matches = ($matches32[0] | Select-String -Pattern $regexLink).Matches
                if ($url32Matches) {
                    Write-Log "$($packageName): Returning 32bit url"
                    return $url32Matches[0].Value
                }
            }
            # We couldn't find an url for 32bit so we search for an independent url
            # We handle the found architecture independent url as a 32bit file (default)
            Write-Log "$($packageName): Searching for any urls with file endings (.msi|.exe|.zip|.tar.gz|.msu)..."
            $regexLinkWithFileExtension = '(http[:/\w\d.&%^$=#\-@+\*]*(\.msi|\.exe|\.zip|\.tar\.gz|\.msu))'
            $urlMatches = (Select-String -Path $verificationPath -Pattern $regexLinkWithFileExtension).Matches
            if ($urlMatches) {
                Write-Log "$($packageName): Returning architecture independent url"
                return $urlMatches[0].Value
            }
        }
        elseif ($searchFor64BitUrl) {
            # We only want to search for 64bit urls in our verification text
            Write-Log "$($packageName): Searching for 64bit urls"
            $matches64 = (Select-String -Path $verificationPath -Pattern $regex64).Matches
            if ($matches64) {
                $url64Matches = ($matches64[0] | Select-String -Pattern $regexLink).Matches
                if ($url64Matches) {
                    Write-Log "$($packageName): Returning 64bit url"
                    return $url64Matches[0].Value
                }
            }
        }
    }
    return
}