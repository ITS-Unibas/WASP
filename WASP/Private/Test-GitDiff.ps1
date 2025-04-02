function Test-GitDiff {
    <#
    .SYNOPSIS
        Invokes a REST API call to add a comment to a specific issue
    .DESCRIPTION
        Invokes a REST API call to add a comment to a specific issue
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,
        [Parameter(Mandatory = $true)]
        [string]$SourceBranch,
        [Parameter(Mandatory = $true)]
        [string]$DestinationBranch
    )


    begin {
        $Config = Read-ConfigFile
        $GitBranchDEV = $Config.Application.GitBranchDEV
        $ticket = $SourceBranch -replace "$GitBranchDEV", ""
        $package, $version = $ticket -split "@"
    }

    process { 
        # Compare the changed files between the two branches
        $paths = git -C $RepoPath diff --name-only "$SourceBranch..$DestinationBranch"

        # Extract the Version and Software that are changed on the branch.
        $results = @()
        $paths | ForEach-Object {
            $parts = ($_ -split '/')[0..1] # Split the path and get the first two parts
            $customObject = [PSCustomObject]@{
                Software = $parts[0]
                Version  = $parts[1]
            }
            $results += $customObject # Add the custom object to the results array
        }

        # Check if the software corresponding to the branch was changed on the branch.
        $matches = $results | Where-Object { $_.Software -eq $package -and $_.Version -eq $version }
    }

        
    end {
        if ($matches) {
            # If the software and version match, return true and the results
            return $true
        } else {
            # If the software and version do not match, return false and the results
            return $false
        }
    }
}