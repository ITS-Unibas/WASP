function Test-ExistsOnRepo {
    <#
    .SYNOPSIS
        Tests if a given choco package exists on a given repostiory
    .DESCRIPTION
        Invokes the REST API of the Repository Manager to check if the
        choco package with a given name and version a specified version already exists
        on the given repository
    #>

    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageVersion,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Dev", "Test", "Prod")]
        [String]
        $Repository
    )

    begin {
        $Config = Read-ConfigFile
        # TODO: Maybe store Repo names in config?
        switch ($Repository) {
            "Dev" {
                $RepositoryName = "choco-dev"
            }
            "Test" {
                $RepositoryName = "choco-test"
            }
            "Prod" {
                $RepositoryName = "choco-prod"
            }
            default {
                $RepositoryName = "choco-prod"
            }
        }
    }

    process {
        $Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Config.Application.RepositoryManagerAPIUser, $Config.Application.RepostoryManagerAPIPassword)))
        $Uri = $Config.Application.RepositoryManagerAPIBaseUrl + "v1/search?repository=$RepositoryName&name=$PackageName&version=$PackageVersion"
        try {
            $Response = Invoke-RestMethod -Method Get -Uri $Uri -ContentType "application/json" -Headers @{Authorization = "Basic $Base64Auth" }
            return ($Response.items.Count -gt 0)
        }
        catch {
            Write-Log "Get request failed. Going to assume it doesn't exist on the target repository." -Severity 2
        }
        return $false
    }
}