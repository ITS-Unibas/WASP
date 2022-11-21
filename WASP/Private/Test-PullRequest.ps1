function Test-PullRequest {
    <#
    .SYNOPSIS
        Tests if a pull-request exists and if it was declined or merged for a given source/base branch.
    .DESCRIPTION
        Tests if a pull-request exists and if it was declined or merged (on GitHub) for a given source/base branch. The reason is to delete the source/base branch afterwards automatically.
        Needed for pull-requests that are declined or pull-requests, that are merged into prod (considering repackaging-Branches).
    .NOTES
        FileName: Test-PullRequest.ps1
        Author: Uwe Molnar
        Contact: its-wcs-ma@unibas.ch
        Created: 2022-13-07
        Version: 1.0.1

        GitHub: Head: Zielbranch
                Base: Quellbranch
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $User,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Branch,

        [Parameter(Mandatory = $false)]
        [Switch]$Repackaging

    )

    begin {
        $config = Read-ConfigFile
        $prodBranch = $config.Application.GitBranchPROD

        if ($Repackaging){
            $body = @{
                "state"               = "closed"
                "head"                = "{0}:{1}" -f $User, $Branch
                "sort"                = "created"
                "direction"           = "desc"
                "per_page"            = "1"
            }
        } else {
            $body = @{
                "state"               = "closed"
                "base"                = $Branch
                "sort"                = "created"
                "direction"           = "desc"
                "per_page"            = "1"
            }
        }
    }

    process {
        $url = ("{0}/repos/{1}/{2}/pulls" -f $config.Application.GitHubBaseUrl, $User, $Repository)
        try {
            $Splat = @{
                Method      = 'GET'
                Uri         = $url
                Headers     = @{Authorization = "Token {0}" -f $config.Application.GitHubAPITokenITSUnibasChocoUser}
                Body        = $body
            }
            
            $results = Invoke-RestMethod @Splat -ErrorAction Stop

            # Empty $results means no pulls found!
            $state  = $results.state
            $merged = $results.merged_at
            $base  = $results.base.label
            
            if ($Repackaging){
                if (($state -eq "closed") -and ($null -ne $merged) -and ($base -match ("{0}:{1}" -f $User, $prodBranch))){
                    return $true         
                } else {
                    return $false
                }                
            } else {
                if (($state -eq "closed") -and ($null -eq $merged)){
                    return $true         
                } else {
                    return $false
                }            
                
            }
        }
        catch {
            # Get request failed for the given url, this means that either the version or the package does not yet exist in that branch
            Write-Log "Get request for $url failed!"
            return $null
        }
    }

    end {

    }
}