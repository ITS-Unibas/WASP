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

        Write-Log "Get last commit message for $SourceBranch from $SourceUrl"
        $GetRequest = Invoke-GetRequest $SourceUrl -ErrorAction Stop
        $LastCommitMessage = $GetRequest.values[0].message.replace('Adds ', '')

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
                    "slug"    = $DestinationRepo
                    "project" = @{
                        "key" = $Config.Application.GitProject
                    }
                }
            };
            "reviewers"           = $ReviewersJson
        } | ConvertTo-Json -Depth 3


        $null = Invoke-PostRequest -Url $DestUrl -Body $json -ErrorAction Stop
    }

    end {
    }
}