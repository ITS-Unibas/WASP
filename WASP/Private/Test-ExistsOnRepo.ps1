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
        $Repository,

        [Parameter(Mandatory)]
        [datetime]
        $FileCreationDate
    )

    begin {
        $Config = Read-ConfigFile
        # TODO: Maybe store Repo names in config?
        switch ($Repository) {
            "Dev" {
                $RepositoryUrl = $config.Application.ChocoServerDEV
            }
            "Test" {
                $RepositoryUrl = $config.Application.ChocoServerTEST
            }
            "Prod" {
                $RepositoryUrl = $config.Application.ChocoServerPROD
            }
            default {
                $RepositoryUrl = $config.Application.ChocoServerPROD
            }
        }
    }

    process {
        $Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Config.Application.RepositoryManagerAPIUser, $Config.Application.RepostoryManagerAPIPassword)))
        $Uri = $RepositoryUrl + "/Packages(Id='$PackageName',Version='$PackageVersion')"
        Write-Log "We are checking at the following location if the publish date is current: $Uri"
        try {
            $Response = Invoke-WebRequest -Uri $Uri -Headers @{Authorization = "Basic $Base64Auth" }
            [xml]$XMLContent = $Response | Select-Object -ExpandProperty Content
            [datetime]$PublishDate = $XMLContent.entry.properties.Published.'#text'
            Write-Log "Repository publish date is $PublishDate and file creation date is $FileCreationDate. File on repo server is current: $($PublishDate -ge $FileCreationDate)"
            return ($PublishDate -ge $FileCreationDate)
        }
        catch {
            Write-Log "Get request failed. Going to assume it doesn't exist on the target repository." -Severity 2
        }
        return $false
    }
}