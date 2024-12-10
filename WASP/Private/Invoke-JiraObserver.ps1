function Invoke-JiraObserver {
    <#
    .SYNOPSIS
        Invokes Jira Observer
    .DESCRIPTION
        Updates the Jira board to represent the current package deployment status
    .NOTES
        FileName: Invoke-JiraObserver.ps1
        Author: Kevin Schaefer, Maximilian Burgert
        Contact: its-wcs-ma@unibas.ch
        Created: 2020-27-05
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
    )

    begin {
        $Config = Read-ConfigFile
        $packageGallery = $config.Application.PackageGallery
        $packageGalleryRepo = ($packageGallery.Split("/")[-1]).Replace(".git", "")
        $gitHubOrganization = $Config.Application.GitHubOrganisation
        
        $GitRepo = $config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $PackageGalleryRepositoryName = $GitFile.Replace(".git", "")
        $PackagesGalleryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $PackageGalleryRepositoryName
    }

    process {
        # Die neueste Jira State file wird eingelesen als Hashtable
        Write-Log -Message "Reading latest Jira state file" -Severity 0
        $jiraStateFileContent, $JiraStateFile = Read-JiraStateFile

        if ($jiraStateFileContent){
            Write-Log -Message "Jira state file '$JiraStateFile' read successfully" -Severity 0
        } else {
            Write-Log -Message "Jira state file '$JiraStateFile' could not be read. Exit now!" -Severity 3
            return
        }

        # Branch in der Package Gallery auf prod setzen (checkout prod) + Git pull + Get-RemoteBranches 
        Write-Log -Message "Checkout prod branch in Package Gallery" -Severity 0
        Switch-GitBranch -path $PackagesGalleryPath -branch 'prod'

        # Vergleich der neusten Jira State-File mit Branches (PR muss angenommen sein) → Liste Branches ohne Ticket 
        Write-Log -Message "Get all remote branches" -Severity 0
        $branches = Get-RemoteBranches -Repo $packageGalleryRepo -User $gitHubOrganization

        Write-Log -Message "Found the following branches:" -Severity 0

        foreach ($branch in $branches) {
            Write-Log -Message "  $branch" -Severity 0
        } 
        # Alle Branches durchgehen und prüfen, ob es ein Ticket dafür gibt (jiraStateFileContent)
        $newTickets = New-Object System.Collections.ArrayList

        Write-Log -Message "Check all branches and if new tickets for JIRA need to be created" -Severity 0

        foreach ($branch in $branches) { 
            # Überprüfen, ob ein Branch ein Repackaging-Branch oder der Test-/Prod-Branch ist: Wenn ja, überspringen
            if ((($branch -split "@").Count -ne 2) -or ($branch -eq "test") -or ($branch -eq "prod")) {
                continue
            }
            
            $cleanBranch = $branch -replace "dev/", ""
        
            # Check, ob der Branch im Jira State File vorhanden ist
            if (!($jiraStateFileContent.ContainsKey($cleanBranch))) {
                # Wenn der Branch nicht im Jira State File ist, wird gecheckt ob der Pull Request angenommen wurde
                $latestPullRequest = Test-PullRequest -Branch $branch

                $state  = $latestPullRequest.Details.state # open, closed
                $merged = $latestPullRequest.Details.merged_at # null, timestamp

                # Wenn der Pull Request angenommen wurde, dann soll ein neues Ticket auf dem WASP Jira Board erstellt werden
                if (($state -ne "open") -and ($null -ne $merged)) { 
                    $null = $newTickets.Add($cleanBranch)
                } else {
                    continue
                }
            }
        }

        # Falls notwendig werden neue Jira Tickets erstellt
        if ($newTickets.Count -ne 0){
            Write-Log -Message "These new ticket(s) need to be created:" -Severity 0

            foreach ($ticket in $newTickets) {
                Write-Log -Message "$ticket" -Severity 1
            }
    
        } else {
            Write-Log -Message "No new tickets need to be created" -Severity 0
        }
        
        # Erstelle neue JIRA-Tickets für alle neuen Branches mit einem gemergten PR
        foreach ($ticket in $newTickets) {
            $null = New-JiraTicket -summary $ticket
        }

        # aktueller Stand Tickets von Jira holen (Get Request)
        $IssueResults = Get-JiraIssues

        # Filtere die Informationen, um den aktuellen Jira-Status mit dem aus der Datei gelesenen Status vergleichen zu können
        $IssuesCurrentState = @{}
        $IssueResults | ForEach-Object {
            $IssuesCurrentState[$_.fields.summary] = [PSCustomObject]@{
                Assignee = $_.fields.assignee.name
                Status = $_.fields.status.name
            }
        }
        
        <# Vergleich Status Tickets mit Stand im neusten Jira-State File:

            Unterschied in neuer Liste abspeichern
            Unterscheidung
            dev → test: PR nach test, wenn nicht schon exisitiert
            test → prod: PR nach prod, wenn nicht schon exisitiert
            prod → dev: kein PR, neuer branch mit @ + random hash 
            test → dev: keine Action
            Wenn ein PR erstellt wird immer 4 Sekunden Timeout. 

        #>
        # $jiraStateFileContent <> $currentJiraStates: Vergleiche den aktuellen Stand der Tickets mit dem Jira State File und speichere die Unterschiede in einer Liste
        $IssuesCompareState = Compare-JiraState $IssuesCurrentState $jiraStateFileContent

         # Funktion um einen neuen PullRequest von einem Branch zum anderen zu erstellen 
         function Update-PullRequest {
            param (
                $SourceBranch,
                $DestinationBranch,
                $Software,
                $DestinationName
            )
            $PullRequestTitle = "$Software to $DestinationName" 
            New-PullRequest -SourceRepo $packageGalleryRepo -SourceUser $gitHubOrganization -SourceBranch $SourceBranch -DestinationRepo $packageGalleryRepo -DestinationUser $gitHubOrganization -DestinationBranch $DestinationBranch -PullRequestTitle $PullRequestTitle -ErrorAction Stop
            Start-Sleep -Seconds 4
            Write-Log -Message "New Pull Request $PullRequestTitle created" -Severity 0  
        }

        # Funktion um den passenden Branch für jede Software auszuwählen
        function Get-DevBranch {
            param (
                $RemoteBranches,
                $DevBranchPrefix
            )
            $RemoteBranches.GetEnumerator() | foreach { 
                if ($_.startswith($DevBranchPrefix)) {
                    return $_
                }
            }
        }

        # Die verfügbaren Branches werden aus der Package Gallery abgerufen
        $RemoteBranches = Get-RemoteBranches -Repo $packageGalleryRepo -User $gitHubOrganization
        
        # jedes Issue, welches vom Stand im neusten JiraState-File abweicht wird einzeln durchgegangen
        foreach($key in $IssuesCompareState.keys) { 
            # Ermittlung des Dev-Branches anhand des Software Namens (mit Eventualität des Repackaging branches)
            $DevBranchPrefix = "dev/$key"
            $DevBranch = Get-DevBranch -RemoteBranches $RemoteBranches -DevBranchPrefix $DevBranchPrefix
            # der neuste Pull Request für den jeweiligen Branch wird ermittelt.
            $latestPullRequest = Test-PullRequest -Branch $DevBranch
            $state  = $latestPullRequest.Details.state # open, closed
            $merged = $latestPullRequest.Details.merged_at # null, timestamp
            $toBranch = $latestPullRequest.Details.base.ref
            # dev → test: PR nach test, wenn nicht schon exisitiert
            if ($IssuesCompareState[$key].StatusOld -eq "Development" -and $IssuesCompareState[$key].Status -eq "Testing") {
                # Es wird gecheckt ob ein offener oder gemergter Pull Request nach test existiert, falls nicht wird ein neuer PR erstellt
                if (($toBranch -ne "test") -or (($state -ne "open") -and ($null -eq  $merged))) { 
                    Update-PullRequest -SourceBranch $DevBranch -DestinationBranch "test" -Software $key -DestinationName "Testing"              
                } else {
                    continue
                } 
            # test → prod: PR nach prod, wenn nicht schon exisitiert
            } elseif ($IssuesCompareState[$key].StatusOld -eq "Testing" -and $IssuesCompareState[$key].Status -eq "Production") {
                # Es wird gecheckt ob ein offener oder gemergter Pull Request nach prod existiert, falls nicht wird ein neuer PR erstellt
                if (($toBranch -ne "prod") -or (($state -ne "open") -and ($null -eq  $merged))) { 
                    Update-PullRequest -SourceBranch $DevBranch -DestinationBranch "test" -Software $key -DestinationName "Testing"                              
                } else {
                    continue
                } 
            # prod → dev: kein PR, neuer branch mit @ + random hash 
            } elseif ($IssuesCompareState[$key].StatusOld -eq "Production" -and $IssuesCompareState[$key].Status -eq "Development") {
                # Falls kein DevBranch für die Software existiert (weil die Software schon nach Prod gemerged wurde), wird ein repackaging branch mit einer uuid erstellt
                if ($DevBranch -notin $RemoteBranches) {
                    $guid = New-Guid
                    $RepackagingString = [convert]::ToString($guid).Replace("-","")
                    $RepackagingBranch = "$DevBranch@$RepackagingString"
                    Write-Host $RepackagingBranch
                    New-RemoteBranch -Repository $packageGalleryRepo -User $gitHubOrganization -BranchName $RepackagingBranch
                    Write-Log -Message "New Repackaging Branch $RepackagingBranch created" -Severity 0  
                }
            } else {
                continue
            }
        }

        # PHS: Branch in der Package Gallery auf prod setzen (checkout prod)
        Write-Log -Message "Checkout prod branch in Package Gallery" -Severity 0
        Switch-GitBranch -path $PackagesGalleryPath -branch 'prod'
        
        # Aktueller Stand Jira Tickets als neues Jira state file schreiben (Stand wurde schon aktualisiert, kein neuer Request)
        Write-JiraStateFile $IssuesCurrentState

    }

    end {
    }
}
