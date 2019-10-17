function Start-PackageDistribution() {
    <#
    .SYNOPSIS
        This function distributes nupkg packages to the choco server.

    .DESCRIPTION
        This function iteares over all development branches and builds a new package or a package which was build previously, but modified, and pushes it to the development server.
        If a package has been approved for testing or production, the packages on the appropriate git branches will be pushed to their corresponding choco servers.
    #>

    [CmdletBinding()]
    param (
        [bool]
        $ForcedDownload
    )

    begin {
        $config = Read-ConfigFile

        $GitRepo = $config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackageGalleryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
        $OldWorkingDir = $PWD.Path
    }

    process {
        Write-Log "--- Starting package distribution ---"

        Switch-GitBranch $PackageGalleryPath $config.Application.GitBranchPROD

        $remoteBranches = Get-RemoteBranches $GitFolderName

        Write-Log "The following remote branches were found: $remoteBranches"

        $nameAndVersionSeparator = '@'
        foreach ($branch in $remoteBranches) {
            if (-Not($branch -eq $config.Application.GitBranchPROD) -and -Not ($branch -eq $config.Application.GitBranchTEST)) {
                # Check for new packages on remote branches, that contain 'dev/' in their names
                Switch-GitBranch $PackageGalleryPath $branch

                $packageName, $packageVersion = $branch.split($nameAndVersionSeparator)
                $packageName = $packageName -Replace $config.Application.GitBranchDEV, ''
                $packageRootPath = Join-Path $PackageGalleryPath (Join-Path $packageName $packageVersion)
                if (-Not (Test-Path $packageRootPath)) {
                    Write-Log "PR for $packageName was not yet merged. Continuing .." -Severity 1
                    continue
                }

                $toolsPath = Join-Path -Path $packageRootPath -ChildPath "tools"

                if (-Not (Test-Path $toolsPath)) {
                    Write-Log ("No tools folder, skipping package $packageName $packageVersion") -Severity 2
                    return
                }

                # Call Override Function with the wanted package to override
                try {
                    Set-Location "$PackageGalleryPath\$packageName\$packageVersion"
                    $nuspecFile = (Get-ChildItem -Path $packageRootPath -Recurse | Where-Object { $_.FullName -match ".nuspec" }).FullName
                    $pkgNameNuspec = Get-NuspecXMLValue $nuspecFile "id"
                    $pkgVersionNuspec = Get-NuspecXMLValue $nuspecFile "version"
                    $env:ChocolateyPackageName = $pkgNameNuspec
                    $env:ChocolateyPackageVersion = $pkgVersionNuspec
                    Start-OverrideFunctionForPackage ( Join-Path $toolsPath "chocolateyInstall.ps1") $ForcedDownload
                    if ($LASTEXITCODE -eq 1) {
                        Write-Log "Override-Function terminated with an error. Exiting.." -Severity 3
                        return
                    }
                    # Check if a nupkg already exists
                    $nupkg = (Get-ChildItem -Path $packageRootPath -Recurse | Where-Object { $_.FullName -match ".nupkg" }).FullName

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
                            Remove-Item -Path "$packageRootPath\*.nupkg"
                        }
                        else {
                            Write-Log "No changes detected for package $packageName."
                            continue
                        }
                    }
                    else {
                        # No new package has been build yet, append the release version 000 in the nuspec
                        Set-NewReleaseVersion $true $nuspecFile
                    }
                    #Build the package
                    Invoke-Expression -Command ("choco pack $nuspecFile -s $packageRootPath")
                    Send-NupkgToServer $packageRootPath $config.Application.ChocoServerDEV
                    Set-Location $OldWorkingDir
                    # Remove all uncommited files, so no left over files will be moved to prod branch. Or else it will be pushed from choco to all instances
                    Write-Log ([string] (git -C $packageRootPath add . 2>&1))
                    Write-Log ([string] (git -C $packageRootPath commit -m "Created override for $packageName $packageVersion" 2>&1))
                    Write-Log ([string] (git -C $packageRootPath push 2>&1))
                    Remove-BuildFiles $packageRootPath

                }
                catch [Exception] {
                    $ChocolateyPackageName = Get-NuspecXMLValue $nuspecFile "id"
                    Write-Log ("Package " + $ChocolateyPackageName + " override process crashed. Skipping it.") -Severity 3
                    Write-Log ($_.Exception | Format-List -force | Out-String) -Severity 3
                    git -C $packageRootPath checkout -- *
                    git -C $packageRootPath clean -f
                }
            }
            elseif (($branch -eq $config.Application.GitBranchPROD) -or ($branch -eq $config.Application.GitBranchTEST)) {
                # if packages are moved to prod and testing, push them to the appropriate choco servers
                if ($branch -eq $config.Application.GitBranchPROD) {
                    $chocolateyDestinationServer = $config.Application.ChocoServerPROD
                }
                elseif ($branch -eq $config.Application.GitBranchTEST) {
                    $chocolateyDestinationServer = $config.Application.ChocoServerTEST
                }

                Switch-GitBranch $PackageGalleryPath $branch

                $packagesList = Get-ChildItem $PackageGalleryPath -Directory
                $remotePackageList = Get-RemoteFolders $GitFolderName $branch

                foreach ($package in $packagesList) {
                    if ($remotePackageList.contains($package)) {
                        $packagePath = Join-Path $PackageGalleryPath $package
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
    end {
        Set-Location $OldWorkingDir
    }
}