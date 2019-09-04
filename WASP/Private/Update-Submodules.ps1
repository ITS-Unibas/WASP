function Update-Submodules {
    <#
    .SYNOPSIS
        Update submodules in a given repository path
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
        [string]
        $RepositoryPath
    )

    begin {
        # TODO: Remove repository paths
        $GitRepo = $config.Application.$PackagesIncomingFiltered
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesIncomingFilteredPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $GitRepo = $config.Application.$PackagesInboxAutomatic
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesInboxAutomaticPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }

    process {
        # TODO: Find a better location for the reset elsewhere if necessary
        if (Test-Path $PackagesIncomingFilteredPath) {
            Set-Location $PathPackagesIncomingFilteredPath
            Write-Log ([string](git reset origin/HEAD --hard 2>&1))
        }
        if (Test-Path $PackagesInboxAutomaticPath) {
            Set-Location $PackagesInboxAutomaticPath
            # use update-git-for-windows instead of just update, since it is deprecated
            #Write-Log ([string](git submodule foreach 'git update-git-for-windows --yes' 2>&1))
            #This seems to work better?
            Write-Log ([string](git submodule update --remote --recursive 2>&1))
        }
        else {
            Write-Log "$PackagesInboxAutomaticPath does not exist. Make sure to clone $PackagesInboxAutomaticPath" -Severity 3
            exit 1
        }
    }

    end {
    }
}