function Test-ExistsOnRepo {
    <#
    .SYNOPSIS
        Tests if a given choco package exists on a given repostiory and compares the 
        PublishDate with the FileCreationDate to check if it is current
    .DESCRIPTION
        Invokes the REST API of the Repository Manager to check if the
        choco package with a given name and version a specified version already exists
        on the given repository and if it is current or not
    .NOTES
        FileName: Test-ExistsOnRepo.ps1
        Author: Uwe Molnar
        Contact: its-wcs-ma@unibas.ch
        Created: 2024-09-04
        Updated: 2026-05-12
        Version: 1.0.1
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
        $RepositoryManagerAPIKey = $config.Application.RepositoryManagerAPIKey
        
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
        $Uri = $RepositoryUrl + "Packages(Id='$PackageName',Version='$PackageVersion')"
        try {
            $Response = Invoke-WebRequest -Uri $Uri -Headers @{"X-NuGet-ApiKey" = $RepositoryManagerAPIKey} -UseBasicParsing
            [xml]$XMLContent = $Response | Select-Object -ExpandProperty Content
            [datetime]$PublishDate = $XMLContent.entry.properties.Published.'#text'
            Write-Log "Package $PackageName with version $PackageVersion on repo server ($Repository) is current: $($PublishDate -ge $FileCreationDate)"
            return ($PublishDate -ge $FileCreationDate)
        }
        catch {
            Write-Log "Package $PackageName with version $PackageVersion not found on repo server ($Repository)." -Severity 1
        }
        return $false
    }
}
