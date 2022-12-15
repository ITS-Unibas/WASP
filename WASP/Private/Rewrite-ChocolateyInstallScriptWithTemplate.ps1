function Rewrite-ChocolateyInstallScriptWithTemplate {
    <#
    .SYNOPSIS
        TBD

    .DESCRIPTION
        TBD
    #>

    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $package,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $packToolInstallPath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $templateFilePath
    )

    begin {
    }

    process {
        Write-Log -Message "Reading the template-File for '$package' and try to process it..." -Severity 1
        $successProcessingTemplate = $true

        # Load 'chocolateyInstall.ps1' (= $oldScript) and template-File (JSON)
        $oldScript = Get-Content -Path $packToolInstallPath
        $templateFileName = $templateFilePath.split("\")[-1]
        
        try {
            $templateFile = Get-Content -Path $templateFilePath | ConvertFrom-Json
        } catch {
            Write-Log -Message "An error occured while reading '$templateFileName': $($error[0].exception.message)" -Severity 3
            # Exit here to avoid further mistakes
            return
        }

        try {
            # Edit old-script: Insert a * after '$packageArgs = @{ [...] }' in ChocolateyInstall.ps1 to avoid deletion of the closing '}'
            $pattern = '$packageArgs = @{'

            if ($oldScript -like $pattern){
                $patternLine = $oldScript.IndexOf($pattern)
                $endFound = $false
                $i = 1
                do {
                    if ($oldScript[($patternLine + $i)] -eq "}"){
                        $oldScript[($patternLine + $i)] = "}*"
                        $endFound = $true
                    } else {
                        $i++
                    }
                } while ($endFound -eq $false) 
            }

            $removeLines        = $templateFile.remove
            $editLinesNonRegex  = $templateFile.edit.'non-regex'
            $editLinesRegex     = $templateFile.edit.regex
            $insertLines        = $templateFile.insert

            # Create a new ArrayList ($newScript) that will be the base for the new choclateyInstall.ps1
            [System.Collections.ArrayList]$newScript = @() 
            foreach ($oldScriptLine in $oldScript){
                $null = $newScript.Add($oldScriptLine)
            }

            # Remove all lines from $newScript which are listed in "remove" of the JSON-template-File
            foreach ($removeLine in $removeLines){
                if ($removeLine -in $newScript){
                    $newScript.Remove($removeLine)   
                }
            }

            # Remove the * after '$packageArgs = @{ [...] }' in old-Script of ChocolateyInstall.ps1
            $index = $newScript.IndexOf("}*")
            $newScript[$index] = "}"

            # Edit lines according to JSON-File
            # First create a temporary newScript ($tmpNewScript) to avoid overring $newScript while looping
            $tmpNewScript = $newScript

            # Edit RegEx-contents
            foreach ($editLineRegex in $editLinesRegex){  
                $editLineSearch  = $editLineRegex.psobject.properties.name
                $editLineReplace = $editLineRegex.psobject.properties.value

                # check $newScript for matching editLineSearch
                if ($tmpNewScript -match $editLineSearch){
                    # check if the replace-string contains "$env:ChocolateyPackageVersion" or "$env:ChocolateyPackageName" and replace it with the correct content
                    if ($editLineReplace.contains('$env:ChocolateyPackageVersion')){
                        $editLineReplace = $editLineReplace.replace('$env:ChocolateyPackageVersion', $env:ChocolateyPackageVersion)
                    } elseif ($editLineReplace.contains('$env:ChocolateyPackageName')) {
                        $editLineReplace = $editLineReplace.replace('$env:ChocolateyPackageName', $package)
                    }     
                    $newScript = $newScript -replace $editLineSearch, $editLineReplace
                }
            }

            # Edit non-RegEx-contents
            foreach ($editLineNonRegex in $editLinesNonRegex){    
                $editLineSearch  = $editLineNonRegex.psobject.properties.name
                $editLineReplace = $editLineNonRegex.psobject.properties.value

                # check $newScript for matching editLineSearch
                if ($editLineSearch -in $tmpNewScript){
                    $newScript = $newScript.replace($editLineSearch, $editLineReplace)
                }
            }

            # Insert new lines according to template
            foreach ($insertLine in $insertLines){  
                $insertLineContent  = $insertLine.psobject.properties.name
                $insertLineNumber = [int]($insertLine.psobject.properties.value)

                # Check insertLineNumer: Should not be negativ or larger than the $newScript.Count
                if (($insertLineNumber -gt 0) -and ($insertLineNumber -lt ($newScript.Count))){
                    $newScript.Insert($insertLineNumber, $insertLineContent)
                } else {
                    Write-Log -Message "The line-number '$insertLineNumber' for the insertion of '$insertLineContent' is not allowed. It's either negative or larger than '$($newScript.Count)'. Skip this insertion!" -Severity 2
                }
            }
            
            Write-Log -Message "Template-File for $package succesfully processed! Start rewriting of ChocolateyInstall-Script..." -Severity 1
            
        } catch {
            $successProcessingTemplate = $false
            Write-Log -Message "Template-File for $package NOT succesfully processed! No rewrite of ChocolateyInstall-Script! Error: $($Error[0])" -Severity 3
            return
        }

        # Override ChocolateyInstall.ps1 if processing of the template was correct
        if ($successProcessingTemplate){
            try {
                Set-Content -Path $packToolInstallPath -Value $newScript
                Write-Log -Message "ChocolateyInstall-Script for $package successfully rewritten!" -Severity 1
            } catch {
                Write-Log -Message "Rewriting of the chocolateyInstall-Script for $package failed! Error: $($Error[0])" -Severity 3
            }
        }
        
        # Add and commit changes to allow a checkout to other branches, if the rewrite did not succed or if it succeded and the newly written chocolateyInstall.ps1 is though buggy
        Write-Log "Commiting and pushing changed chocolateyInstall.ps1 file." -Severity 1
        Write-Log ([string] (git -C $packageRootPath add "tools/chocolateyInstall.ps1" 2>&1))
        Write-Log ([string] (git -C $packageRootPath commit -m "Override because of choco-template for $packageName" 2>&1))
        Write-Log ([string] (git -C $packageRootPath push 2>&1))
    }
}
