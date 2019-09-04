function Start-Workflow {
    <#
    .SYNOPSIS
        This function initiates the workflow of automated packaging
    .DESCRIPTION
        TODO: Update description
        The update of the git repositories first removes all local and remote branches which have been handled.
        Then, it updates the whishlist by inserting the current package versions. To get the latest changes from
        the package source repositories, the submodules of the package inbox will be updated and then determined,
        which package will be moved to which of the git branches of the package gallery. The filtered package inbox
        is then updated.
    #>
    [CmdletBinding()]
    param (
    )

    begin {
        $config = Read-ConfigFile


    }

    process {
        Remove-LocalBranch
        Remove-HandledBranches
        # TODO: Rename repository
        # Update windows software repository
        Set-Location $PSScriptRoot
        Write-Log ([string] (git checkout master 2>&1))
        Write-Log ([string] (git pull 2>&1))

        # TODO: implement function
        Update-Submodules

        # Get all the packages which are to accept and further processed
        $newPackages = @()

        # Manual updated packages
        $packagesManual = @(Get-ChildItem $manualSoftwareFolder)
        foreach ($package in $packagesManual) {
            # Use the latest created package as reference
            $latest = Get-ChildItem -Path $package.FullName | Sort-Object CreationTime -Descending | Select-Object -First 1
            $version = (ExtractXMLValue $latest.FullName "version")

            $newPackages += Search-Whitelist $package.Name $version
        }

        # Automatic updated packages
        foreach ($repository in $config.Application.AutomaticPackageRepositories) {
            # TODO: Add path to cloned repository
            $packages = @(Get-ChildItem $repository)
            foreach ($package in $packages) {
                $newPackages += Search-Whitelist $package.Name $version
            }
        }

        # Commit and push the changes made to the wishlist
        Update-Wishlist

        # Initialize branches for each new package
        Update-PackageInboxFiltered($newPackages)

        # Create pull request from each new package branch to package-gallery

        # Update windows software repository
        Set-Location $PSScriptRoot
        Write-Log ([string] (git checkout master 2>&1))
        Write-Log ([string] (git pull 2>&1))

        <#
        Start distributing packages to choco servers and promote packages based on package issue position
        on assicuated atlassian jira kanban board
        #>
        Start-PackageDistribution
    }

    end {
    }
}