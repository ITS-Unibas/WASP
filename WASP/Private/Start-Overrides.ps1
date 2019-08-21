function Start-Overrides() {
    <#
    .SYNOPSIS
        Checks out all branches in the windows software repo and iterates over each package to override it if necessary, build it and push it to the matching choco server.

    .DESCRIPTION
        All dev and test remote branches as well as the prod branch will be checked out. On each branch each package will be checked.
        At each package first it will be overwritten. Afterwards the nupkg if existing will be checked and a hash is created. Then a new nupkg is created and the hash of it is compared to the one of the old nupkg.
        If they differ the release version of the nupkg will be iterated because there was a change in this package. If not the release version won't be changed.
        After building these packages they will be pushed to the right choco server depending on their location on the remote branches (dev/test/prod).

    #>
    begin {
        $config = Read-ConfigFile
        
        $GitRepo = $config.Application.WindowsSoftware
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $SoftwareRepositoryPath = Join-Path -Path $config.Application.BaseDirectory-ChildPath $GitFolderName
    }

    process { 
        Set-Location $SoftwareRepositoryPath

        # Checkout prod if we are not already on it
        Write-Log ([string] (git checkout "prod" 2>&1))
        Write-Log ([string] (git pull 2>&1))
  
        $remoteBranches = Get-RemoteBranches $SoftwareRepositoryPath
  
        $nameAndVersionSeparator = '@'
        foreach ($branch in $remoteBranches) {
            # Reset the Location to the root of our windows software repo
            if (-Not($branch -eq 'prod') -and -Not ($branch -eq 'testing')) {
                $packageName, $packageVersion = $branch.split($nameAndVersionSeparator)
                $packageName = $packageName -Replace 'dev/', ''
                Write-Log ([string] (git checkout $branch 2>&1))

                # Check if we could checkout the correct branch
                if ((Get-CurrentBranchName) -ne $branch) {
                    Write-Log "Couldn't checkout $branch. Exiting now!" -Severity 3
                    exit 1
                }

                Write-Log ([string] (git pull 2>&1))

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
            elseif (($branch -eq 'prod') -or ($branch -eq 'testing')) {
                if ($branch -eq 'prod') {
                    $chocolateyDestinationServer = $config.Application.ChocoServerPROD
                }
                elseif ($branch -eq 'testing') {
                    $chocolateyDestinationServer = $config.Application.ChocoServerTEST
                }
                Write-Log ([string] (git checkout $branch 2>&1))

                # Check if we could checkout the correct branch
                if ((Get-CurrentBranchName) -ne $branch) {
                    Write-Log "Couldn't checkout $branch. Exiting now!" -Severity 3
                    exit 1
                }

                # Pull to get any get changes on the branch
                Write-Log ([string] (git pull 2>&1))

                $packagesList = Get-ChildItem $PathWindowsSoftwareRepo -Directory

                foreach ($package in $packagesList) {
                    $packagePath = Join-Path $PathWindowsSoftwareRepo $package
                    $versionsList = Get-ChildItem $packagePath -Directory
                    foreach ($version in $versionsList) {
                        Set-Location (Join-Path $packagePath $version)

                        # TODO: define nuspecFolder
                        Send-NupkgToServer $nuspecFolder $chocolateyDestinationServer

                        try {
                            $nupkg = Get-ChildItem '.\' | Where-Object { $_.FullName -match ".nupkg" }
                            if (-Not (Test-Path $nupkg) -or -Not ($nupkg -match ".nupkg")) {
                                Write-Log ("No nupkg to push, skipping package $package $version")
                                return
                            }
                            $nuspec = Get-ChildItem ".\" | Where-Object { $_.FullName -match ".nuspec" }
                            if ($nuspec) {
                                Send-NupkgToServer $nuspecFolder $chocolateyDestinationServer
                            }
                        }
                        catch {
                            Write-Log ("Package " + $nupkg + " could not be pushed.") -Severity 3
                        }
                        Set-Location $packagePath
                    }
                    Set-Location $PathWindowsSoftwareRepo
                }
            }
        }
    }
    
}