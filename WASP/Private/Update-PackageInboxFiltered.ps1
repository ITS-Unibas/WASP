function Update-PackageInboxFiltered {
    <#
    .SYNOPSIS
        Updates the filtered inbox repo
    .DESCRIPTION
        Updates the filtered inbox repo and creates a pull request for the package gallery
    .PARAMETER NewPackages
        Define all new packages which should be packaged
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.ArrayList]
        $NewPackages
    )

    begin {
        $Config = Read-ConfigFile
        $GitRepo = $Config.Application.PackagesInboxFiltered
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolder = $GitFile.Replace(".git", "")
        $PackagesInboxRepoPath = Join-Path -Path $Config.Application.BaseDirectory -ChildPath $GitFolder
    }
    process {

        if (-Not (Test-Path $PackagesInboxRepoPath)) {
            Write-Log -Message "PacakgeInboxFiltered was not cloned yet. You probably have not run 'Register-ChocolateyPackagingServer' yet. Please ensure the server is set up correctly" -Severity 3
            return
        }

        foreach ($Package in $NewPackages) {
            $PackagePath = $Package.path
            $PackageName = $Package.name
            $PackageVersion = $Package.version

            Write-Log "Starting update routine for package $PackageName"
            $DevBranch = "$($Config.Application.GitBranchDEV)$($PackageName)@$PackageVersion"
            $GitRepo = $Config.Application.PackageGallery
            $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
            $Repo = $GitFile.Replace(".git", "")
            $RemoteBranches = Get-RemoteBranches -repo $Repo

            if (-Not $RemoteBranches.Contains($DevBranch)) {
                Write-Log ([string](git -C $PackagesInboxRepoPath add $PackagePath 2>&1))
                # Create new branch
                Write-Log ([string](git -C $PackagesInboxRepoPath checkout -b $DevBranch 2>&1))

                if ((Get-CurrentBranchName -Path $PackagesInboxRepoPath) -ne $DevBranch) {
                    Write-Log -Message "The dev branch for this package could not be created" -Severity 3
                    continue
                }

                Write-Log ([string](git -C $PackagesInboxRepoPath commit -m "Automated commit: Added $DevBranch" 2>&1))
                Write-Log ([string](git -C $PackagesInboxRepoPath push -u origin $info 2>&1))
                # Is this necessary?
                Write-Log ([string](git -C $PackagesInboxRepoPath checkout master 2>&1))

                New-PullRequest -SourceRepo $Config.Application.PackagesIncomingFiltered -SourceBranch $DevBranch -DestinationRepo $Config.Application.WindowsSoftware -DestinationBranch $DevBranch

            }
        }
    }
}