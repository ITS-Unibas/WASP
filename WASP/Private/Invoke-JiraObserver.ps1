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
        $packageGallery = $Config.Application.PackageGallery
        $packageGalleryRepo = ($packageGallery.Split("/")[-1]).Replace(".git", "")
        $gitHubOrganization = $Config.Application.GitHubOrganisation
    }

    process {
        # Latest Jira State File einlesen. Returns a hashtable with the Jira state	
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
        Switch-GitBranch -path $packageGallery -branch 'prod'

        # Vergleich Latest Jira State-File mit Branches (PR muss angenommen sein) → Liste Branches ohne Ticket 
        Write-Log -Message "Get all remote branches" -Severity 0
        $branches = Get-RemoteBranches -Repo $packageGalleryRepo -User $gitHubOrganization

        Write-Log -Message "Found the following branches:" -Severity 0

        foreach ($branch in $branches) {
            Write-Log -Message "  $branch" -Severity 0
        } 
        # Go through all branches and check if there is a ticket for it (jiraStateFileContent)
        $newTickets = New-Object System.Collections.ArrayList

        Write-Log -Message "Check all branches and if new tickets for JIRA need to be created" -Severity 0

        foreach ($branch in $branches) { 
            # Check if a branch is a repackaging branch or the test-/prod-branch: If so, skip it
            if ((($branch -split "@").Count -ne 2) -or ($branch -eq "test") -or ($branch -eq "prod")) {
                continue
            }
            
            $cleanBranch = $branch -replace "dev/", ""
        
            # Check if branch is in the Jira state file
            if (!($jiraStateFileContent.ContainsKey($cleanBranch))) {
                # Check if PR was accepted for branch
                $latestPullRequest = Test-PullRequest -Branch $branch

                $state  = $latestPullRequest.Details.state # open, closed
                $merged = $latestPullRequest.Details.merged_at # null, timestamp

                if (($state -ne "open") -and ($null -ne $merged)) { # Maybe check if the ticket is not already in the Jira available? Is double check but maybe okay
                    $null = $newTickets.Add($cleanBranch)
                } else {
                    continue
                }
            }
        }

        if ($newTickets.Count -ne 0){
            Write-Log -Message "These new ticket(s) need to be created:" -Severity 0

            foreach ($ticket in $newTickets) {
                Write-Log -Message "$ticket" -Severity 1
            }
    
        } else {
            Write-Log -Message "No new tickets need to be created" -Severity 0
        }
        
        # Create new JIRA tickets for all new branches with a merged PR
        foreach ($ticket in $newTickets) {
            $null = New-JiraTicket -summary $ticket
        }

        # aktueller Stand Tickets von Jira holen (Get Request)
        $IssueResults = Get-JiraIssues

        # Filter the information to be able to compare the current jira state to the state read from the file
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
        # $jiraStateFileContent <> $currentJiraStates

        # PHS: Branch in der Package Gallery auf prod setzen (checkout prod)
        Write-Log -Message "Checkout prod branch in Package Gallery" -Severity 0
        Switch-GitBranch -path $packageGallery -branch 'prod'
        
        # Aktueller Stand Jira Tickets als neues Jira state file schreiben (Stand wurde schon aktualisiert, kein neuer Request)
        Write-JiraStateFile $IssuesCurrentState

    }

    end {
    }
}
