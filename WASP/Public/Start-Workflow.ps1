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

        $GitRepo = $config.Application.$PackagesInboxManual
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesManualPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $GitRepo = $config.Application.$PackagesInboxAutomatic
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesAutomaticPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
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
        $packagesManual = @(Get-ChildItem $PackagesManualPath)
        foreach ($package in $packagesManual) {
            # Use the latest created package as reference
            $latest = Get-ChildItem -Path $package.FullName | Sort-Object CreationTime -Descending | Select-Object -First 1
            $version = (ExtractXMLValue $latest.FullName "version")

            $newPackages += Search-Whitelist $package.Name $version
        }

        # Automatic updated packages
        $automaticRepositories = @(Get-ChildItem $PackagesAutomaticPath)
        foreach ($repository in $automaticRepositories) {
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