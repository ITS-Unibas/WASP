function Start-Workflow {
    <#
    .SYNOPSIS
        This function initiates the workflow of automated packaging
    .DESCRIPTION
    #>
    [CmdletBinding()]
    param (
    )

    begin {
        $config = Read-ConfigFile

        $GitRepo = $config.Application.PackagesInbox
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesInboxPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $GitRepo = $config.Application.PackagesManual
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesManualPath = Join-Path -Path $PackagesInboxPath -ChildPath $GitFolderName

        $GitRepo = $config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackageGalleryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $GitRepo = $config.Application.PackagesWishlist
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesWishlistPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }

    process {
        Remove-HandledBranches

        # Update the added submodules in the package-inbox-automatic repository
        Write-Log ([string](git -C $PackagesInboxPath submodule update --remote --recursive 2>&1))

        # Get all the packages which are to accept and further processed
        $newPackages = @()

        # Manual updated packages
        $packagesManual = @(Get-ChildItem $PackagesManualPath)
        foreach ($package in $packagesManual) {
            # Use the latest created package as reference
            $latest = Get-ChildItem -Path $package.FullName | Sort-Object CreationTime -Descending | Select-Object -First 1
            $version = (Get-NuspecXMLValue $latest.FullName "version")

            $newPackages += Search-Wishlist $package.Name $version
        }

        # Automatic updated packages
        $externalRepositories = @(Get-ChildItem $PackagesInboxPath)
        foreach ($repository in $externalRepositories) {
            if ($repository.Name -eq '.gitmodules' -or $repository.Name -like '*manual*') {
                continue
            }

            $automatic = $false
            $packages = @(Get-ChildItem $repository.FullName)
            foreach ($package in $packages) {
                if ($package.Name -like '*automatic*') {
                    $automatic = $true
                }
            }

            if ($automatic) {
                $automaticPath = Join-Path -Path $repository.FullName -ChildPath 'automatic'
                $automaticPackages = @(Get-ChildItem $automaticPath)
                foreach ($package in $automaticPackages) {
                    $string = "Looking at package: $package in " + $package.FullName
                    Write-Log $string -Severity 0
                    $nuspec = Get-ChildItem -Path $package.FullName -recurse | Where-Object { $_.Extension -like "*nuspec*" }
                    $version = (Get-NuspecXMLValue $nuspec.FullName "version")
                    $newPackages += Search-Wishlist $package $version
                }
            }
            else {
                foreach ($package in $packages) {
                    $string = "Looking at package: $package in " + $package.FullName
                    Write-Log $string -Severity 0
                    $nuspec = Get-ChildItem -Path $package.FullName -recurse | Where-Object { $_.Extension -like "*nuspec*" }
                    $version = (Get-NuspecXMLValue $nuspec.FullName "version")
                    $newPackages += Search-Wishlist $package $version
                }
            }
        }

        # Commit and push changes to wishlist located in the path
        Update-Wishlist $PackagesWishlistPath 'master'
        Write-Log "Found the following new packages: $newPackages" -Severity 3
        if ($newPackages) {
            # Initialize branches for each new package
            Update-PackageInboxFiltered $newPackages
        }

        <#
        Start distributing packages to choco servers and promote packages based on package issue position
        on assicuated atlassian jira kanban board
        #>
        Start-PackageDistribution
    }

    end {
    }
}