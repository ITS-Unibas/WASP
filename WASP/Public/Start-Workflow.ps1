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

        $GitRepo = $config.Application.PackagesInboxManual
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesInboxManualPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $GitRepo = $config.Application.PackagesInboxAutomatic
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesInboxAutomaticPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $GitRepo = $config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackageGalleryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }

    process {
        Remove-HandledBranches

        # Update the added submodules in the package-inbox-automatic repository
        Write-Log ([string](git -C $PackagesInboxAutomaticPath submodule update --remote --recursive 2>&1))

        # Get all the packages which are to accept and further processed
        $newPackages = @()

        # Manual updated packages
        $packagesManual = @(Get-ChildItem $PackagesInboxManualPath)
        foreach ($package in $packagesManual) {
            # Use the latest created package as reference
            $latest = Get-ChildItem -Path $package.FullName | Sort-Object CreationTime -Descending | Select-Object -First 1
            $version = (ExtractXMLValue $latest.FullName "version")

            $newPackages += Search-Whitelist $package.Name $version
        }

        # Automatic updated packages
        $automaticRepositories = @(Get-ChildItem $PackagesInboxAutomaticPath)
        foreach ($repository in $automaticRepositories) {
            $packages = @(Get-ChildItem $repository)
            foreach ($package in $packages) {
                $newPackages += Search-Whitelist $package.Name $version
            }
        }

        # Commit and push changes to wishlist located in the path
        Update-Wishlist $PackageGalleryPath $config.Application.GitBranchPROD

        # Initialize branches for each new package
        Update-PackageInboxFiltered $newPackages

        <#
        Start distributing packages to choco servers and promote packages based on package issue position
        on assicuated atlassian jira kanban board
        #>
        Start-PackageDistribution
    }

    end {
    }
}