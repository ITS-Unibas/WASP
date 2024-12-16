function Update-PullRequest {
    <#
    .Synopsis 
    Prüfe die Branches und schau ob eine Aktion notwendig ist. 
    .Description 
    Falls es einen offenen Pull Request vom Source Branch zu Destination Branch gibt, wird es keine Aktion geben. 
    In allen anderen Fällen wird ein Versuch gemacht einen neuen PR zu erstellen.
    Anhand der return Message wird das weitere Vorgehen abgeleitet: 
    - Erfolgreich: Jira State File wird noch nicht geupdatet, da PR noch offen
    - No commits between*: Jira State File wird geupdatet, da die Branches gleich sind 
    - Andrere Message: Error Message ins Log, Jira State File wird nicht geupdatet.
    .Notes 
    FileName: Update-PullRequest.ps1
    Author: Tim Keller 
    Contact: tim.keller@unibas.ch
    Created: 2024-12-13
    Updated: 2024-12-13
    Version: 1.0.0
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceBranch,
        [Parameter(Mandatory = $true)]
        [string]$DestinationBranch,
        [Parameter(Mandatory = $true)]
        [string]$Software,
        [Parameter(Mandatory = $true)]
        [string]$DestinationName
    )

    begin {
        $Config = Read-ConfigFile
        $packageGallery = $config.Application.PackageGallery
        $packageGalleryRepo = ($packageGallery.Split("/")[-1]).Replace(".git", "")
        $gitHubOrganization = $Config.Application.GitHubOrganisation
    }

    process {
        # der neuste Pull Request für den jeweiligen Branch wird ermittelt.
        $latestPullRequest = Test-PullRequest -Branch $SourceBranch
        $state  = $latestPullRequest.Details.state # open, closed
        $fromBranch = $latestPullRequest.Details.head.ref
        $toBranch = $latestPullRequest.Details.base.ref

        if (($fromBranch -eq $SourceBranch) -and ($toBranch -eq $DestinationBranch) -and ($state -eq "open")) { 
            Write-Log "No action needed. Pull Request from $SourceBranch to $DestinationBranch already exists" -Severity 1
            return $false
        } else {
            $PullRequestTitle = "$Software to $DestinationName"
            $response = New-PullRequest -SourceRepo $packageGalleryRepo -SourceUser $gitHubOrganization -SourceBranch $SourceBranch -DestinationRepo $packageGalleryRepo -DestinationUser $gitHubOrganization -DestinationBranch $DestinationBranch -PullRequestTitle $PullRequestTitle -ErrorAction Stop
            Start-Sleep -Seconds 4
            if ($response.GetType().Name -ne "ErrorRecord") {
                Write-Log -Message "New Pull Request $PullRequestTitle from $SourceBranch to $DestinationBranch created" -Severity 1 
                return $false
            } else {
                $ErrorDetails = ConvertFrom-Json $response.ErrorDetails
                $ErrorDetailsMessage = $ErrorDetails.Message
                $ErrorMessage = $ErrorDetails.errors.message
                if ($ErrorMessage -like "No commits between*") {
                    return $true
                } else {
                    Write-Log -Message "Error creating Pull Request: $ErrorDetailsMessage" -Severity 3
                    return $false
                }
            }
        }
    }
}