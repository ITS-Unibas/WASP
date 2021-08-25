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

        $GitRepo = $config.Application.PackagesWishlist
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $WishlistFolderName = $GitFile.Replace(".git", "")
        $PackagesWishlistPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $WishlistFolderName
        $wishlistPath = Join-Path -Path  $PackagesWishlistPath -ChildPath "wishlist.txt"

        $tmpdir = $env:TEMP
    }

    process {
        Write-Log "--- Starting package distribution ---" -Severity 1

        Switch-GitBranch $PackageGalleryPath $config.Application.GitBranchPROD

        $remoteBranches = Get-RemoteBranches $GitFolderName
        $repackagingBranches = $remoteBranches | Where-Object { ($_ -split '@').Length -eq 3 }

        Write-Log "Remote branches found: $remoteBranches"

        $wishlist = Get-Content -Path $wishlistPath | Where-Object { $_ -notlike "#*" }

        $nameAndVersionSeparator = '@'
        foreach ($branch in $remoteBranches) {
            if (-Not($branch -eq $config.Application.GitBranchPROD) -and -Not ($branch -eq $config.Application.GitBranchTEST)) {
                # Check for new packages on remote branches, that contain 'dev/' in their names
                Switch-GitBranch $PackageGalleryPath $branch

                $packageName, $packageVersion, $re = $branch.split($nameAndVersionSeparator)
                $packageName = $packageName -Replace $config.Application.GitBranchDEV, ''

                Write-Log "--- Start $packageName $packageVersion ---" -Severity 1

                $foundInWishlist = $false
                foreach ($line in $wishlist) {
                    if ($line -match $packageName) {
                        $foundInWishlist = $true
                    }
                }
                if (!$foundInWishlist) {
                    Write-Log "Skip $packageName@$PackageVersion : deactivated in wishlist." -Severity 1
                    continue
                }
                $packageRootPath = Join-Path $PackageGalleryPath (Join-Path $packageName $packageVersion)
                if (-Not (Test-Path $packageRootPath)) {
                    Write-Log "Skip $packageName@$PackageVersion : PR was not yet merged." -Severity 1
                    continue
                }
                $toolsPath = Join-Path -Path $packageRootPath -ChildPath "tools"
                if (-Not (Test-Path $toolsPath)) {
                    Write-Log ("Skip $packageName@$PackageVersion : No tools/ folder.") -Severity 3
                    continue
                }
                # Call Override Function with the wanted package to override
                try {
                    Set-Location "$PackageGalleryPath\$packageName\$packageVersion"
                    $nuspecFile = (Get-ChildItem -Path $packageRootPath -Recurse -Filter *.nuspec).FullName
                    if (-Not $nuspecFile) {
                        Write-Log "Skip $packageName@$PackageVersion : No nuspec file found." -Severity 3
                        continue
                    }
                    $env:ChocolateyPackageName = ([xml](Get-Content -Path $nuspecFile)).Package.metadata.id
                    $env:ChocolateyPackageVersion = ([xml](Get-Content -Path $nuspecFile)).Package.metadata.version
                    Start-PackageInstallFilesDownload ( Join-Path $toolsPath "chocolateyInstall.ps1") $ForcedDownload
                    if ($LASTEXITCODE -eq 1) {
                        Write-Log "Skip $packageName@$PackageVersion : Override-Function terminated with an error." -Severity 3
                        continue
                    }
                    Write-Log "Check if nupkg exists."
                    # Check if a nupkg already exists
                    $nupkg = (Get-ChildItem -Path $packageRootPath -Recurse -Filter *.nupkg).FullName
                    if ($nupkg) {
                        Write-Log "$packageName@$PackageVersion nupkg exists. Check for changes."
                        # Nupkg exists already, now we have to check if anything has changed and if yes we have to add a release version into the nuspec
                        # Get hash of the newest existing nupkg and save the version of the existing nupkg
                        $hashOldNupkg = Get-NupkgHash $nupkg $packageRootPath
                        # Build the package to compare it to the previous one
                        # To not overwrite the old package, move the previous package to a tmp directory
                        Write-Log "Move package to $tmpdir."
                        Move-Item -Path $nupkg -Destination "$tmpdir\$env:ChocolateyPackageName.$env:ChocolateyPackageVersion.nupkg"
                        $InvokeMessage = Invoke-Expression -Command ("choco pack $nuspecFile -s . -r")
                        $InvokeMessage | ForEach-Object {
                            $Severity = 0
                            if ($_ -match "cannot be empty") {
                                $Severity = 3
                            }
                            Write-Log $_ -Severity $Severity
                        }
                        $nupkgNew = (Get-ChildItem -Path $packageRootPath -Recurse -Filter *.nupkg).FullName
                        if (-Not $nupkgNew) {
                            Write-Log "Choco pack process of $packageName@$PackageVersion failed." -Severity 3
                            continue
                        }
                        Write-Log "Calculate hash for nupkg: $nupkgNew."
                        $hashNewNupkg = Get-NupkgHash $nupkgNew $packageRootPath
                        if ($hashNewNupkg -eq $hashOldNupkg) {
                            Write-Log "No changes detected."
                            Remove-Item -Path "$packageRootPath\*.nupkg"
                            Write-Log "Move $packageName from $tmpdir to $packageRootPath."
                            Move-Item -Path  "$tmpdir\$env:ChocolateyPackageName.$env:ChocolateyPackageVersion.nupkg" -Destination $packageRootPath
                            continue
                        }
                        else {
                            Write-Log "Hashes do not match, remove $packageName from $tmpdir and push new package to server." -Severity 1
                            Remove-Item "$tmpdir\$env:ChocolateyPackageName.$env:ChocolateyPackageVersion.nupkg"
                        }
                    }
                    else {
                        Write-Log "No nupkg exists. Pack package." -Severity 1
                        $InvokeMessage = Invoke-Expression -Command ("choco pack $nuspecFile -s . -r")
                        $InvokeMessage | ForEach-Object {
                            $Severity = 0
                            if ($_ -match "cannot be empty") {
                                $Severity = 3
                            }
                            Write-Log $_ -Severity $Severity
                        }
                    }
                    Send-NupkgToServer $packageRootPath $config.Application.ChocoServerDEV
                    Set-Location $OldWorkingDir
                    Write-Log ([string] (git -C $packageRootPath add . 2>&1))
                    Write-Log ([string] (git -C $packageRootPath commit -m "Edits install script of $packageName $packageVersion" 2>&1))
                    Write-Log ([string] (git -C $packageRootPath push 2>&1))
                    # Remove all uncommited files, so no left over files will be moved to prod branch. Or else it will be pushed from choco to all instances
                    # TODO: Remove build files only when package is moved to prod branch
                    Remove-BuildFiles $packageRootPath
                }
                catch [Exception] {
                    $ChocolateyPackageName = ([xml](Get-Content -Path $nuspecFile)).Package.metadata.id
                    Write-Log ("Package " + $ChocolateyPackageName + " process crashed at line: $($_.InvocationInfo.ScriptLineNumber). Skip.") -Severity 3
                    Write-Log ($_.Exception | Format-List -force | Out-String) -Severity 3
                    Remove-Item -Path "$packageRootPath\unzipedNupkg" -ErrorAction SilentlyContinue
                    git -C $packageRootPath checkout -- *
                    git -C $packageRootPath clean -f
                }
            }
            elseif (($branch -eq $config.Application.GitBranchPROD) -or ($branch -eq $config.Application.GitBranchTEST)) {
                # if packages are moved to prod and testing, push them to the appropriate nuget repository servers
                if ($branch -eq $config.Application.GitBranchPROD) {
                    $chocolateyDestinationServer = $config.Application.ChocoServerPROD
                    $Repo = "Prod"
                }
                elseif ($branch -eq $config.Application.GitBranchTEST) {
                    $chocolateyDestinationServer = $config.Application.ChocoServerTEST
                    $Repo = "Test"
                }

                Switch-GitBranch $PackageGalleryPath $branch

                $packagesList = Get-ChildItem $PackageGalleryPath -Directory

                foreach ($package in $packagesList) {
                    $packagePath = Join-Path $PackageGalleryPath $package
                    $versionsList = Get-ChildItem $packagePath -Directory
                    # TODO: Add changes to version history here
                    $versionsList | Sort-Object -Property { $_.Name -as [version] } | Select-Object -Last 5
                    foreach ($version in $versionsList) {
                        if (Test-ExistPackageVersion $GitFolderName $package $version $branch) {
                            $packageRootPath = Join-Path $packagePath $version
                            $FullVersion = ([xml](Get-Content -Path (Join-Path $packageRootPath "$package.nuspec"))).Package.metadata.version
                            $FullID = ([xml](Get-Content -Path (Join-Path $packageRootPath "$package.nuspec"))).Package.metadata.id
                            $FileDate = (Get-ChildItem -Path $packageRootPath | Where-Object { $_.FullName -match "\.nupkg" }).LastWriteTime

                            # check if package is being repackaged
                            if ($repackagingBranches -match "$package@$FullVersion") {
                                # only push it to test if the jira issue is in test
                                if ($chocolateyDestinationServer -eq $config.Application.ChocoServerTEST) {
                                    if (Test-IssueStatus $package $version 'Testing') {
                                        if (-Not (Test-ExistsOnRepo -PackageName $FullID -PackageVersion $FullVersion -Repository $Repo -FileCreationDate $FileDate)) {
                                            Write-Log "Push $FullID@$FullVersion to $chocolateyDestinationServer." -Severity 1
                                            Send-NupkgToServer $packageRootPath $chocolateyDestinationServer
                                        }
                                        else {
                                            Write-Log "$FullID@$FullVersion exists on $chocolateyDestinationServer."
                                        }
                                        continue
                                    }
                                    else {
                                        Write-Log "$package is being repackaged and its jira task is not in test." -Severity 3
                                        continue
                                    }
                                }
                            }
                            # if package is in PROD, check if it exists in DEV as well --> make sure that if a nupkg is faulty on dev and gets deleted on dev server, it is pushed there again
                            # goal is to be sure that the same nupkg exists on all three servers
                            if ($Repo -eq "Prod") {
                                $tmpChocolateyDestinationServer = $config.Application.ChocoServerDEV
                                if (-Not (Test-ExistsOnRepo -PackageName $FullID -PackageVersion $FullVersion -Repository "Dev" -FileCreationDate $FileDate)) {
                                    Write-Log "Pushing $FullID@$FullVersion to $tmpChocolateyDestinationServer." -Severity 1
                                    Send-NupkgToServer $packageRootPath $tmpchocolateyDestinationServer
                                }
                                else {
                                    Write-Log "$FullID@$FullVersion exists on $tmpChocolateyDestinationServer."
                                }
                            }
                            if (-Not (Test-ExistsOnRepo -PackageName $FullID -PackageVersion $FullVersion -Repository $Repo -FileCreationDate $FileDate)) {
                                Write-Log "Push $FullID@$FullVersion to $chocolateyDestinationServer." -Severity 1
                                Send-NupkgToServer $packageRootPath $chocolateyDestinationServer
                            }
                            else {
                                Write-Log "$FullID@$FullVersion exists on $chocolateyDestinationServer."
                            }
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