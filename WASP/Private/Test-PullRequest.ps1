function Test-PullRequest {
    <#
    .SYNOPSIS
        Tests a branch for its latest pull-request and returns the results of the pull-request.
    .DESCRIPTION
        Tests a branch for its latest pull-request and returns the results of the pull-request: PR declined or merged into test/prod branch or from ITS-Unibas-Choco to Unibasel-SWD repository.
    .NOTES
        FileName: Test-PullRequest.ps1
        Author: Uwe Molnar
        Contact: its-wcs-ma@unibas.ch
        Created: 2024-28-08
        Version: 1.0.2

        GitHub: Head: source branch
                Base: target branch
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $branch
    )

    begin {
        $config = Read-ConfigFile

        $GitBaseURL = $config.Application.GitHubBaseUrl
        $GitHubOrganisation =  $config.Application.GitHubOrganisation
        $GitHubUser = $config.Application.GitHubUser

        $GitRepo = $config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $PackageGalleryRepositoryName = $GitFile.Replace(".git", "")

        $dev  = $config.Application.GitBranchDEV -replace "/", ""
        $test = $config.Application.GitBranchTEST
        $prod = $config.Application.GitBranchPROD

        $GitHubAPITokenITSUnibasChocoUser = $config.Application.GitHubAPITokenITSUnibasChocoUser

        function Get-PullRequest {
            param (
                [string]$branch,
                [string]$repository, # "ITS-Unibas-Choco" or "UniBasel-SWD"
                [string]$base # $branch, "test" or "prod"
            )
            
            $url = ("{0}/repos/{1}/{2}/pulls" -f $GitBaseURL, $GitHubOrganisation, $PackageGalleryRepositoryName)

            $body = @{
                "state"     = "all"
                "head"      = "{0}:{1}" -f $repository, $branch
                "base"      = $base
                "sort"      = "created"
                "direction" = "desc"
                "per_page"  = "1" 
            }

            $Splat = @{
                Method      = 'GET'
                Uri         = $url
                Headers     = @{Authorization = "Token {0}" -f $GitHubAPITokenITSUnibasChocoUser}
                Body        = $body
            }

            try {
                $results = Invoke-RestMethod @Splat -ErrorAction Stop
            } catch {
                Write-Log -Message "Get request for '$url' failed!" -Severity 3
                return $null
            }

            return $results
        }

        function Add-PullRequestToList {
            param (
                [PSObject]$results,
                [string]$scope # "dev", "test" or "prod"
            )

            if ($results){
                $res = [PSCustomObject]@{
                    Branch      = $scope
                    TimeStamp   = [datetime]::ParseExact($results.created_at, 'yyyy-MM-ddTHH:mm:ssZ', $null)
                    Details     = $results
                }

                return $res

            } else {
                return $null
            }
        }
    }

    process {
        # Array to all PR results
        $PRResults = @()

        # Get the latest PR from ITS-Unibas-Choco to UniBasel-SWD for branch $branch
        $resultsFromChoco = Get-PullRequest -branch $branch -repository $GitHubUser -base $branch
        $PRResults += Add-PullRequestToList -results $resultsFromChoco -scope $dev
        
        # Get the latest PR from dev -> test for branch $branch
        $resultsSWDToTest = Get-PullRequest -branch $branch -repository $GitHubOrganisation -base $test
        $PRResults += Add-PullRequestToList -results $resultsSWDToTest -scope $test

        # Get the latest PR from dev -> prod for branch $branch
        $resultsSWDToProd = Get-PullRequest -branch $branch -repository $GitHubOrganisation -base $prod
        $PRResults += Add-PullRequestToList -results $resultsSWDToProd -scope $prod

        # comapre all PRs returned and get the latest PR for branch $branch
        $latestPRresults = $PRresults.GetEnumerator() | Sort-Object -Property $_.TimeStamp -Descending | Select-Object -First 1
    }

    end {
        return $latestPRresults
    }
}