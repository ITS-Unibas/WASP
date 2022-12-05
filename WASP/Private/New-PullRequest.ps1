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
	.PARAMETER DestinationRepo
        Define the destination User of the repository
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
		$SourceUser,

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
		$DestinationUser,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationBranch

    )

    begin {
        $Config = Read-ConfigFile
    }

    process {
        New-RemoteBranch -Repository $DestinationRepo -User $DestinationUser -BranchName $DestinationBranch
        $Url = ("{0}/repos/{1}/{2}/pulls" -f $Config.Application.GitHubBaseUrl, $DestinationUser, $DestinationRepo)

        $json = @{
            "title"               = "* New * $SourceBranch"
            "body"                = "Accept this PR to merge into $DestinationRepo"
            "head"                = "{0}:{1}" -f $SourceUser, $SourceBranch
            "base"                = "$DestinationBranch"
        } | ConvertTo-Json

        $null = Invoke-PostRequest -Url $Url -Body $json -ErrorAction Stop
    }

    end {
    }
}