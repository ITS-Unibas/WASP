function Start-NupkgDistribution() {
    <#
    .SYNOPSIS
        This function distributes nupkg packages to the choco server.

    .DESCRIPTION
        This function iteares over all development branches and builds a new package or a package which was build previously, but modified, and pushes it to the development server.
        If a package has been approved for testing or production, the packages on the appropriate git branches will be pushed to their corresponding choco servers.
    #>
    begin {
        $config = Read-ConfigFile
        
        $GitRepo = $config.Application.WindowsSoftware
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $SoftwareRepositoryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }

    process { 
        Set-Location $SoftwareRepositoryPath

        Switch-GitBranch "prod"

        $remoteBranches = Get-RemoteBranches $SoftwareRepositoryPath
  
        $nameAndVersionSeparator = '@'
        foreach ($branch in $remoteBranches) {
            if (-Not($branch -eq 'prod') -and -Not ($branch -eq 'testing')) {
                # Check for new packages on remote branches, that contain 'dev/' in their names
                Switch-GitBranch $branch

                $packageName, $packageVersion = $branch.split($nameAndVersionSeparator)
                $packageName = $packageName -Replace 'dev/', ''
                $packageRootPath = (Join-Path $packageName $packageVersion)
                if (-Not (Test-Path $packageRootPath)) {
                    Write-Log "PR for $packageName was not yet merged. Continuing .." -Severity 1
                    continue
                }

                Set-Location $packageRootPath

                if (-Not (Test-Path ".\tools")) {
                    Write-Log ("No tools folder, skipping package $packageName $packageVersion") -Severity 2
                    return
                }
                # Have to be in tools folder s.t. override works
                Set-Location (".\tools")

                # Call Override Function with the wanted package to override
                try {
                    Start-OverrideFunctionForPackage ($packageRootPath + "\tools\chocolateyInstall.ps1")
                    if ($LASTEXITCODE -eq 1) {
                        Write-Log "Override-Function terminated with an error. Exiting.." -Severity 3
                        exit 1
                    }
                    Set-Location $packageRootPath
                    # Check if a nupkg already exists
                    $nupkg = (Get-ChildItem -Path $packageRootPath | Where-Object { $_.FullName -match ".nupkg" }).FullName
                    $nuspecFile = (Get-ChildItem -Path $packageRootPath | Where-Object { $_.FullName -match ".nuspec" }).FullName

                    if (-Not $nuspecFile) {
                        Write-Log "No nuspec file in package $packageName $packageVersion. Continuing with next package" -Severity 2
                        continue
                    }

                    if ($nupkg) {
                        # Nupkg exists already, now we have to check if anything has changed and if yes we have to add a release version into the nuspec
                        # Get hash of the existing nupkg and save the version of the existing nupkg
                        $hashOldNupkg = Get-NupkgHash $nupkg $packageRootPath
                        # Build the package to compare it to the old one
                        Invoke-Expression -Command ("choco pack " + $nuspecFile + " -s .")
                        $nupkgNew = (Get-ChildItem -Path $packageRootPath | Where-Object { $_.FullName -match ".nupkg" }).FullName
                        if (-Not $nupkgNew) {
                            Write-Log "Choco pack process of package $packageName $packageVersion failed. Continuing with next package." -Severity 3
                            continue
                        }
                        $hashNewNupkg = Get-NupkgHash $nupkgNew $packageRootPath
                        if (-Not ($hashNewNupkg -eq $hashOldNupkg)) {
                            # There were changes in the package, so iterate the version of the nuspec.
                            Set-NewReleaseVersion $false $nuspecFile
                            # Because the later new build package has a different version and therefore a new nupkg will be created we have to remove the old not anymore used nupkg
                            Remove-Item -Path ".\*.nupkg"
                        }
                    }
                    else {
                        # No new package has been build yet, append the release version 000 in the nuspec
                        Set-NewReleaseVersion $true $nuspecFile
                    }
                    #Build the package
                    Invoke-Expression -Command ("choco pack " + $nuspecFile + " -s .")
                    Write-Log ([string] (git add . 2>&1))
                    Write-Log ([string] (git commit -m "Created override for $packageName $packageVersion" 2>&1))
                    Write-Log ([string] (git push 2>&1))

                    Send-NupkgToServer $packageRootPath $config.Application.ChocoServerDEV
                }
                catch [Exception] {
                    $ChocolateyPackageName = Get-NuspecXMLValue $packageRootPath "id"
                    Write-Log ("Package " + $ChocolateyPackageName + " override process crashed. Skipping it.") -Severity 3
                    Write-Log ($_.Exception | Format-List -force | Out-String) -Severity 3

                }
            }
            elseif (($branch -eq 'prod') -or ($branch -eq 'test')) {
                # if packages are moved to prod and testing, push them to the appropriate choco servers
                if ($branch -eq 'prod') {
                    $chocolateyDestinationServer = $config.Application.ChocoServerPROD
                }
                elseif ($branch -eq 'test') {
                    $chocolateyDestinationServer = $config.Application.ChocoServerTEST
                }
                Switch-GitBranch $branch

                $packagesList = Get-ChildItem $PathWindowsSoftwareRepo -Directory

                foreach ($package in $packagesList) {
                    $packagePath = Join-Path $PathWindowsSoftwareRepo $package
                    $versionsList = Get-ChildItem $packagePath -Directory
                    foreach ($version in $versionsList) {
                        $packageRootPath = Join-Path $packagePath $version
                        # TODO: Only send nupkg to server when it does not exist there yet
                        Send-NupkgToServer $packageRootPath $chocolateyDestinationServer
                    }
                }
            }
        }
    }
    
}