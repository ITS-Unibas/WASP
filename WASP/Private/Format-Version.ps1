

$NewPackages.GetEnumerator() | ForEach-Object {
    $versionCorrected = ""
    $packageVersion = $_.version

    if ($package -eq $unstablePackage) {
      # TBD
    }

    try {
        [version]$version = $packageVersion
    } catch {
        Write-Log "Version $version could not be parsed as a version-variable. Please check version and correct manually!"
        # Remove package from $newPackages and contine
        Continue
    }

    # Version numbers that have fewer than three parts will have missing parts added, as 0 (for example, 1.2 will be normalized to 1.2.0).
    if ($version.Build -eq "-1"){
        if ($version.Minor -eq "-1"){
            $versionCorrected = "$($version.Major)" + ".0.0"    
        } else {
            $versionCorrected = $version.ToString() + ".0"
        }

        $_.version = $versionCorrected
    }

    # Version numbers that have four parts, will have the fourth part removed if it is 0 (for example, 1.0.0.0 will be normalized to 1.0.0, but 1.0.0.1 will not).
    [version]$version = $_.version # override $version because it could be corrected beforehand

    if (($version.Revision -ne "-1") -and ($version.Revision -eq "0")){
        $versionCorrected = "$($version.Major).$($version.Minor).$($version.Build)"
        $_.version = $versionCorrected
    }

    # Version numbers that have leading zeroes in any part will have those leading zeroes removed (for example, 1.001.2 will be normalized to 1.1.2).
    [String]$version = $_.version # override $version because it could be corrected beforehand

    $splitVersionString  = ""
    $splitVersionString = $version.Split('.') | ForEach-Object {
            $($_ -replace '^0+(?=\d)','')        
    }

    $versionCorrected = ""
    $splitVersionString | ForEach-Object {$versionCorrected += "$($_)."}
    $versionCorrected = $versionCorrected -replace "\.$", ""

    $_.version = $versionCorrected
}

    Write-Host "NEW:"
    $newPackages.version
