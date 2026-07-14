function Format-Version () {
    <#
    .Synopsis 
        This script makes sure every version of a new package is correctly formatted.    
    .Description 
        This script makes sure every version of a new package is correctly formatted according to the Chocolatey format. Details see: https://docs.chocolatey.org/en-us/choco/features/version-number-normalization/
        This script formats the version and also corrects the corresponing nuspec-file and the folder-names if necessary.
    .Notes 
        FileName: Format-Version.ps1
        Author: Uwe Molnar
        Contact: uwe.molnar@unibas.ch
        Created: 2026-07-07
        Updated: 2026-07-09
        Version: 1.1.0
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$packages
    )
    
    begin {
    } 
    
    process {
        $packages.GetEnumerator() | ForEach-Object {
            
            $correctionNeeded = $false
            $versionCorrected = ""
            $packageName = $_.name
            $packageVersion = $_.version
            $packageInboxPath = $_.path
        
            try {
                [version]$version = $packageVersion
            } catch {
                Write-Log -Message "Version '$packageVersion' for package '$packageName' could not be parsed as a version-variable. Please check version and correct manually!" -Severity 2
                Continue
            }
        
            # Version numbers that have fewer than three parts will have missing parts added, as 0 (for example, 1.2 will be normalized to 1.2.0).
            if ($version.Build -eq "-1"){
                $correctionNeeded = $true

                if ($version.Minor -eq "-1"){
                    $versionCorrected = "$($version.Major)" + ".0.0"    
                } else {
                    $versionCorrected = $version.ToString() + ".0"
                }
                
                Write-Log -Message "Correction for version '$packageVersion' for package '$packageName' needed. Corrected version is set to: '$versionCorrected'" -Severity 0
                $_.version = $versionCorrected
            }
        
            # Version numbers that have four parts, will have the fourth part removed if it is 0 (for example, 1.0.0.0 will be normalized to 1.0.0, but 1.0.0.1 will not).
            [version]$version = $_.version # override $version because it could be corrected beforehand
        
            if (($version.Revision -ne "-1") -and ($version.Revision -eq "0")){
                $correctionNeeded = $true

                $versionCorrected = "$($version.Major).$($version.Minor).$($version.Build)"
                Write-Log -Message "Correction for version '$packageVersion' for package '$packageName' needed. Corrected version is set to: '$versionCorrected'" -Severity 0
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

            if (!($packageVersion.ToString() -eq $versionCorrected.ToString())){
                $correctionNeeded = $true
                Write-Log -Message "Correction for version '$packageVersion' for package '$packageName' needed. Corrected version is set to: '$versionCorrected'" -Severity 0
                $_.version = $versionCorrected
            }
        
            # Correct the corresponing nuspec-file and foldernames if necessary
            if ($correctionNeeded){
                # Correct the foldername
                $oldVersion = $packageInboxPath.Split("\")[-1]
                Rename-Item -Path $packageInboxPath -NewName $($_.version)
                $_.path = $packageInboxPath -replace "$oldVersion", "$($_.version)"

                # Correct the nuspec-file
                $nuspecFilePath = (Get-ChildItem -Path $($_.path) -Recurse -Filter *.nuspec).FullName
                $nuspecContentRaw = Get-Content -Path $nuspecFilePath -Raw -ErrorAction Stop
                $newContent = $_.version
                $nuspecContentRaw = $nuspecContentRaw | ForEach-Object { $_ -replace '<version>.*</version>', "<version>$newContent</version>" }
				Set-Content -Path $nuspecFilePath -Value $nuspecContentRaw
            }

        }
    }
    
    end {
        return $packages
    }
}
