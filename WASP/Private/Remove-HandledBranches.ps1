function Remove-HandledBranches {
    <#
    .SYNOPSIS
        Removes branches which already have been handled
    .DESCRIPTION
        Remove remote and local development branches of a package if the pull request has been declined or accepted and moved to the prod branch
    #>
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        $config = Read-ConfigFile

        $GitRepo = $config.Application.$PackagesIncomingFiltered
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesIncomingFilteredPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }
    
    process {
        Set-Location $PackagesIncomingFilteredPath
    
        # Get updates and changes from remote
        Write-Log ([string](git pull 2>&1))
    
        Write-Log "Getting branches with status: Open"
        $pullrequestsOpen = Get-RemoteBranchesByStatus $WinSoftwareRepoName 'Open'
        $PackagesIncomingFilteredBranches = Get-RemoteBranches $PackagesFilteredRepoName
        $nameAndVersionSeparator = '@'
    
        ForEach ($remoteBranch in $PackagesIncomingFilteredBranches) {
            if ((-Not ($remoteBranch -eq 'master')) -and ((-Not $pullrequestsOpen.contains($remoteBranch)) -or $pullrequestsOpen.length -eq 0)) {
                Write-Log "PR for $remoteBranch is not Open anymore. Deleting from our filtered packages, because it was merged or declined..."
                $repo.DeleteBranch($PackagesFilteredRepoName, $remoteBranch)
                Switch-GitBranch 'master'

                Write-Log ([string](git branch -D $remoteBranch 2>&1))
            }
    
            Set-Location $PathPackagesWindowsSoftware
    
            if (-Not ($remoteBranch -eq "master") -and ((-Not $pullrequestsOpen.contains($remoteBranch)) -or $pullrequestsOpen.length -eq 0)) {
                $packageName, $packageVersion = $remoteBranch.split($nameAndVersionSeparator)
                $packageName = $packageName -replace $config.Application.GitBranchDEV, ""

                # TODO: Test which branch should be switched to

                Switch-GitBranch $config.Application.GitBranchPROD
                
                Switch-GitBranch $remoteBranch
                
                if (-Not (Test-Path ('.\' + $packageName + '\' + $packageVersion))) {
                    # The branch on windows software was not merged, because there is no package folder, so we have to delete it.
                    Write-Log "Deleting branch $remoteBranch in Windows software because the PR was declined."
                    $repo.DeleteBranch($WinSoftwareRepoName, $remoteBranch)
                    # Checkout prod and delete the local branch
                    Switch-GitBranch $config.Application.GitBranchPROD

                    Write-Log ([string](git branch -D $remoteBranch 2>&1))
                }
            }
        }
        Set-Location ..
    }
    
    end {
    }
}