function Start-Workflow {
    <#
    .SYNOPSIS
        This function initiates the workflow of automated packaging
    .DESCRIPTION
    #>
    [CmdletBinding()]
    param (
        [switch] $ForcedDownload = $false
    )

    begin {
        Write-Log "Starting Workflow" -Severity 1
        $StartTime = Get-Date

        $config = Read-ConfigFile

        $GitRepo = $config.Application.PackagesInbox
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesInboxPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $GitRepo = $config.Application.PackagesManual
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesManualPath = Join-Path -Path $PackagesInboxPath -ChildPath $GitFolderName

        $GitRepo = $config.Application.PackagesWishlist
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesWishlistPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        # Load Helper Function from chocolatey in current session
        Initialize-Prerequisites
    }

    process {
        Remove-HandledBranches

        # Update the added submodules in the package-inbox-automatic repository
        Write-Log ([string](git -C $PackagesInboxPath pull 2>&1))
        Write-Log ([string](git -C $PackagesInboxPath submodule init 2>&1))
        Write-Log ([string](git -C $PackagesInboxPath submodule update --remote --recursive 2>&1))

        # Commit and push changes to wishlist located in the path
        Switch-GitBranch $PackagesWishlistPath 'master'

        # Get all the packages which are to accept and further processed
        $newPackages = New-Object System.Collections.ArrayList

        # Manual updated packages
        $packagesManual = @(Get-ChildItem $PackagesManualPath)
        $newPackages = Search-NewPackages -NewPackagesList $newPackages -Packages $packagesManual -Manual

        # Automatic updated packages
        $externalRepositories = @(Get-ChildItem $PackagesInboxPath)
        foreach ($repository in $externalRepositories) {
            if ($repository.Name -eq '.gitmodules' -or $repository.Name -like '*manual*') {
                continue
            }

            $automatic = $false
            $manual = $false
            $packages = @(Get-ChildItem $repository.FullName | Where-Object { $_.PSIsContainer })
            foreach ($package in $packages) {
                if ($package.Name -like '*automatic*') {
                    $automatic = $true
                } elseif ($package.Name -like "*manual*") {
                    $manual = $true
                }
            }

            if ($automatic) {
                $automaticPath = Join-Path -Path $repository.FullName -ChildPath 'automatic'
                $automaticPackages = @(Get-ChildItem $automaticPath | Where-Object { $_.PSIsContainer })
                $newPackages = Search-NewPackages -NewPackagesList $newPackages -Packages $automaticPackages
            }

            if ($manual) {
                $manualPath = Join-Path -Path $repository.FullName -ChildPath 'manual'
                $manualPackages = @(Get-ChildItem $manualPath | Where-Object { $_.PSIsContainer })
                $newPackages = Search-NewPackages -NewPackagesList $newPackages -Packages $manualPackages
            }

            if(-not $manual -and -not $automatic) {
                $newPackages = Search-NewPackages -NewPackagesList $newPackages -Packages $packages
            }
        }

        # Commit and push changes to wishlist located in the path
        if ($newPackages) {
            Write-Log "Found new packages: $($newPackages.ForEach({$_.name}))" -Severity 1
            # Initialize branches for each new package
            try {
                Update-PackageInboxFiltered $newPackages
                Update-Wishlist $PackagesWishlistPath 'master'
            }
            catch {
                Write-Log "Error in Update-PackageInboxFiltered workflow or while updating wishlist:`n$($_.Exception.Message)." -Severity 3
            }
        }

        <#
        Start distributing packages to choco servers and promote packages based on package issue position
        on assicuated atlassian jira kanban board
        #>
        Start-PackageDistribution -ForcedDownload $ForcedDownload

        # Project current deployment status of packages to jira board
        Invoke-JiraObserver
    }

    end {
        $Duration = New-TimeSpan -Start $StartTime -End (Get-Date)
        Write-Log "The process took $Duration" -Severity 1
    }
}