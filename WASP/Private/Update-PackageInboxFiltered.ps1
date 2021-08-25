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
        $GitRepoInbox = $GitFile.Replace(".git", "")
        $PackagesInboxRepoPath = Join-Path -Path $Config.Application.BaseDirectory -ChildPath $GitRepoInbox

        $GitRepo = $Config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitRepoPackageGallery = $GitFile.Replace(".git", "")

        $GitRepo = $config.Application.PackagesWishlist
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesWishlistPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
        $wishlistPath = Join-Path -Path  $PackagesWishlistPath -ChildPath "wishlist.txt"

        $NameAndVersionSeparator = $config.Application.WishlistSeperatorChar

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

            Write-Log "Start update routine for $PackageName $PackageVersion"
            $DevBranch = "$($Config.Application.GitBranchDEV)$($PackageName)@$PackageVersion"
            $RemoteBranches = Get-RemoteBranches -repo $GitRepoPackageGallery

            if (-Not $RemoteBranches.Contains($DevBranch)) {
                Write-Log ([string](git -C $PackagesInboxRepoPath add $PackagePath 2>&1))
                # Create new branch
                New-LocalBranch $PackagesInboxRepoPath $DevBranch

                if ((Get-CurrentBranchName -Path $PackagesInboxRepoPath) -ne $DevBranch) {
                    Write-Log -Message "Dev branch for this package could not be created" -Severity 3
                    continue
                }

                Write-Log ([string](git -C $PackagesInboxRepoPath commit -m "Adds $DevBranch" 2>&1))
                Write-Log ([string](git -C $PackagesInboxRepoPath push -u origin $DevBranch 2>&1))
                # Is this necessary?
                Write-Log ([string](git -C $PackagesInboxRepoPath checkout master 2>&1))

                New-PullRequest -SourceRepo $GitRepoInbox -SourceBranch $DevBranch -DestinationRepo $GitRepoPackageGallery -DestinationBranch $DevBranch -ErrorAction Stop

                $wishlist = Get-Content -Path $wishlistPath | Where-Object { $_ -notlike "#*" }

                Foreach ($line in $wishlist) {
                    $origLine = $line
                    if ($line -match "@") {
                        $packageNameWhishlist, $previousVersion = $line.split($NameAndVersionSeparator)
                    }
                    else {
                        $previousVersion = "0.0.0.0"
                        $packageNameWhishlist = $line.Trim()
                    }

                    if ($PackageName -like $packageNameWhishlist.Trim()) {
                        $SetContentComm = (Get-Content -Path $wishlistPath) -replace $origLine, ($PackageName + $NameAndVersionSeparator + $PackageVersion) | Set-Content $wishlistPath
                    }
                }


            }
        }
    }
}