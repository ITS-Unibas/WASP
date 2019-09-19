function New-PullRequest {
    <#
    .SYNOPSIS
        Create a pull request
    .DESCRIPTION
        Creates a pull request for given repository
    .PARAMETER SourceRepo
        Define the originated repository
    .PARAMETER SourceBranch
        Define the originated branchname
    .PARAMETER DestinationRepo
        Define the destination repository
    .PARAMETER DestinationBranch
        Define the destination branchname
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceRepo,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceBranch,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationRepo,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationBranch

    )

    begin {
        $Config = Read-ConfigFile
        $Reviewers = $Config.Application.Reviewers
        $ReviewersJson = New-Object System.Collections.ArrayList
    }

    process {
        if ($Reviewers.Count -le 0) {
            Write-Log "There are no reviewers configured in the applications configfile. Please ensure to have a valid configfile and all settings are filled in." -Severity 3
            return
        }

        foreach ($Reviewer in $Reviewers) {
            $ReviewerObject = @{
                "user" = @{
                    "name" = $Reviewer
                }
            }
            $null = $ReviewersJson.Add($ReviewerObject)
        }

        New-RemoteBranch -Repository $DestinationRepo -BranchName $DestinationBranch
        $DestUrl = ("{0}/rest/api/1.0/projects/{1}/repos/{2}/pull-requests" -f $Config.Application.GitBaseUrl, $Config.Application.GitProject, $DestinationRepo)
        $SourceUrl = ("{0}/rest/api/1.0/projects/{1}/repos/{2}/commits?until=refs%2Fheads%2F$SourceBranch" -f $Config.Application.GitBaseUrl, $Config.Application.GitProject, $SourceRepo)
        # Integrated GetLastCommitMessage directly in this Cmdlet, because this needed just in here
        try {
            $GetRequest = Invoke-GetRequest $SourceUrl
            $LastCommitMessage = $GetRequest.values[0].replace('Automated commit: Added ', '')
        }
        catch {
            Write-Log "We were not able to fetch the last commit message for repository $SourceRepo and branch $SourceBranch" -Severity 3
            # Should exit function here. Not sure if correct
            # https://social.technet.microsoft.com/Forums/windowsserver/en-US/7d9f4a00-ff20-4517-8e87-8b93218d93a7/powershell-return-function-after-an-error-question?forum=winserverpowershell
            continue
        }
        $json = @{
            "title"               = $LastCommitMessage
            "state"               = "OPEN";
            # Boolean Values: https://blogs.msdn.microsoft.com/powershell/2006/12/24/boolean-values-and-operators/
            "open"                = $true;
            "close_source_branch" = $false;
            "fromRef"             = @{
                "id"         = ("refs/heads/{0}" -f $SourceBranch)
                "repository" = @{
                    "slug"    = $SourceRepo
                    "project" = @{
                        "key" = $Config.Application.GitProject
                    }
                }
            };
            "toRef"               = @{
                "id"         = "refs/heads/$DestinationBranch"
                "repository" = @{
                    "slug"    = $DestinationRepository
                    "project" = @{
                        "key" = $Config.Application.GitProject
                    }
                }
            };
            "reviewers"           = $ReviewersJson
        } | ConvertTo-Json -Depth 3

        try {
            Invoke-PullRequest -Url $DestUrl -Body $json
        }
        catch {
            Write-Log "The error '$_.Exception.Message' occurred while creating a pull request for $DestinationRepo from $SourceRepo `
                (Sourcebranch: $SourceBranch, Destinationbranch: $DestinationBranch)" -Severity 3
        }
    }

    end {
    }
}