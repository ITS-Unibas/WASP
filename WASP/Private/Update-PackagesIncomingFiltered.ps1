function Update-PackagesIncomingFiltered {
    <#
    .SYNOPSIS
        Short description
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        [array]
        $newPackages
    )

    begin {
        if ($newPackages) {
            $devBranchPrefix = 'dev/'
            ForEach ($pkg in $newPackages) {
                # commit and push to packages-incoming-filtered repo
                $path = $pkg.path
                $packageName = $pkg.name
                $packageVersion = $pkg.version
                if (Test-Path $PathPackagesIncomingFiltered) {
                    Write-Log "Starting Release Management Routine"
                    Set-Location $PathPackagesIncomingFiltered

                    $repo = [GitRepository]::new()
                    $repo.BaseURL = $env:RepoBaseUrl
                    $repo.ProjectName = $env:RepoProjectName
                    $repo.RepositoryName = $env:PackagesFilteredRepoName
                    $repo.DefaultBranch = $env:WinSoftwareDefaultBranchName
                    $remoteBranches = $repo.GetRemoteBranches($WinSoftwareRepoName)

                    $info = ($devBranchPrefix + $packageName + '@' + $packageVersion)

                    if (-Not $remoteBranches.Contains($info)) {
                        Write-Log ([string](git add $path 2>&1))
                        # Create new branch
                        Write-Log ([string](git checkout -b $info 2>&1))

                        # Check if we could checkout the correct branch
                        if ((Get-CurrentBranchName) -ne $info) {
                            Write-Log "Couldn't checkout $info. Trying to change to already existing branch now!" -Severity 2
                            Write-Log ([string](git checkout $info 2>&1))

                            if ((Get-CurrentBranchName) -ne $info) {
                                Write-Log "Couldn't checkout $info. Exiting now!" -Severity 2
                                exit 1
                            }

                            Write-Log "Successfully checkout $info on second try." -Severity 2
                        }
                        Write-Log ([string](git commit -m "Automated commit: Added $info" 2>&1))
                        Write-Log ([string](git push -u origin $info 2>&1))
                        Write-Log ([string](git checkout master 2>&1))

                        # Create pull request from this branch
                        $repo.CreatePullRequest($PackagesFilteredRepoName, $info, $WinSoftwareRepoName, $info)

                    }
                    else {
                        # Branch with the same name already exists
                        Write-Log "Remote branch $info already exists, nothing will be commited."
                    }

                    Set-Location ..
                }
                else {
                    Write-Log "$PathPackagesIncomingFiltered does not exist. Make sure to clone $PathPackagesIncomingFiltered" -Severity 3
                    exit 1
                }
            }
        }
    }

    process {
    }

    end {
    }
}