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

        $GitBranchDEV = $Config.Application.GitBranchDEV
        $GitBranchTEST = $Config.Application.GitBranchTEST
        $GitBranchPROD = $Config.Application.GitBranchPROD
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
            
            $cleanBranch = $branch -replace "$GitBranchDEV", ""
        
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

        # $jiraStateFileContent <> $currentJiraStates: Vergleiche den aktuellen Stand der Tickets mit dem Jira State File und speichere die Unterschiede in einer Liste
        $IssuesCompareState, $NewIssues = Compare-JiraState $IssuesCurrentState $jiraStateFileContent

        # Der alte Stand des Jira State Files wird geupdated, zuallererst wird der alte Stand kopiert und die neuen Tickets werden angehängt
        $UpdatedJiraState = $jiraStateFileContent.Clone()
        $UpdatedJiraState += $NewIssues


        # Die verfügbaren Branches werden aus der Package Gallery abgerufen
        $RemoteBranches = Get-RemoteBranches -Repo $packageGalleryRepo -User $gitHubOrganization
        
        # jedes Issue, welches vom Stand im neusten JiraState-File abweicht wird einzeln durchgegangen
        foreach($key in $IssuesCompareState.keys) { 
            # Ermittlung des Dev-Branches anhand des Software Namens (mit Eventualität des Repackaging branches)
            $DevBranchPrefix = "$GitBranchDEV$key"
            $DevBranch = Get-DevBranch -RemoteBranches $RemoteBranches -DevBranchPrefix $DevBranchPrefix
            # dev → test: PR nach test, wenn nicht offen. Falls der PR schon gemerged wurde, wird der Jira State aktualisiert
            if ($IssuesCompareState[$key].StatusOld -eq "Development" -and $IssuesCompareState[$key].Status -eq "Testing") {
                # Es wird gecheckt ob ein offener oder gemergedter Pull Request nach test existiert, falls nicht wird ein neuer PR erstellt
                $UpdateJiraStateFile = Update-PullRequest -SourceBranch $DevBranch -DestinationBranch $GitBranchTEST -Software $key -DestinationName "Testing"              

            # test → prod: PR nach prod, wenn nicht offen.Falls der PR schon gemerged wurde, wird der Jira State aktualisiert.
            } elseif ($IssuesCompareState[$key].StatusOld -eq "Testing" -and $IssuesCompareState[$key].Status -eq "Production") {
                # Es wird gecheckt ob ein offener oder gemergedter Pull Request nach prod existiert, falls nicht wird ein neuer PR erstellt
                $UpdateJiraStateFile = Update-PullRequest -SourceBranch $DevBranch -DestinationBranch $GitBranchPROD -Software $key -DestinationName "Production"                              

            # prod → dev: kein PR, neuer branch mit @ + random hash 
            } elseif ($IssuesCompareState[$key].StatusOld -eq "Production" -and $IssuesCompareState[$key].Status -eq "Development") {
                # Falls kein DevBranch für die Software existiert (weil die Software schon nach Prod gemerged wurde), wird ein repackaging branch mit einer uuid erstellt
                if ($DevBranch -notin $RemoteBranches) {
                    $guid = New-Guid
                    $RepackagingString = [convert]::ToString($guid).Replace("-","")
                    $RepackagingBranch = "$DevBranchPrefix@$RepackagingString"
                    New-RemoteBranch -Repository $packageGalleryRepo -User $gitHubOrganization -BranchName $RepackagingBranch
                    Write-Log -Message "New Repackaging Branch $RepackagingBranch created" -Severity 0  
                }
                $UpdateJiraStateFile = $true
            # test -> dev: änderung wird im Jira State File geschrieben
            } elseif ($IssuesCompareState[$key].StatusOld -eq "Testing" -and $IssuesCompareState[$key].Status -eq "Development") {
                $UpdateJiraStateFile = $true
            # dev → prod: Error Message, da Testing übersprungen wurde
            } elseif (($IssuesCompareState[$key].StatusOld -eq "Development"  -and $IssuesCompareState[$key].Status -eq "Production")) {
                Write-Log -Message "The status of the issue $key has changed from Development to Production without going through Testing. This Action is not allowed." -Severity 3
                $UpdateJiraStateFile = $false
            }
            else {
                $UpdateJiraStateFile = $false
            }
            if ($UpdateJiraStateFile -eq $true) {
                # Der Jira State File wird aktualisiert für den entsprechenden Branch
                $UpdatedJiraState[$key] = [PSCustomObject]@{
                    Assignee = $IssuesCompareState[$key].Assignee
                    Status = $IssuesCompareState[$key].Status
                }
            }
        }

        # PHS: Branch in der Package Gallery auf prod setzen (checkout prod)
        Write-Log -Message "Checkout prod branch in Package Gallery" -Severity 0
        Switch-GitBranch -path $PackagesGalleryPath -branch 'prod'
    }

    end {
        # Aktueller Stand Jira Tickets als neues Jira state file schreiben (Stand wurde schon aktualisiert, kein neuer Request)
        Write-JiraStateFile $UpdatedJiraState
    }
}
 