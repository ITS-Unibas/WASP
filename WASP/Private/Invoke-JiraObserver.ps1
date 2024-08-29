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
        $jiraStateFile = Read-JiraStateFile

        # PHS: Branch in der Package Gallery auf prod setzen (checkout prod) + Git pull + Get-RemoteBranches 

        # Vergleich Latest Jira State-File mit Branches (PR muss angenommen sein) → Liste Branches ohne Ticket 
        $branches = Get-RemoteBranches -Repo $packageGalleryRepo -User $gitHubOrganization

        # Go through all branches and check if there is a ticket for it (jiraStateFile)
        $newTickets = New-Object System.Collections.ArrayList

        foreach ($branch in $branches) { 
            # Check if a branch is a repackaging branch or the test-/prod-branch: If so, skip it
            if ((($branch -split "@").Count -ne 2) -or ($branch -eq "test") -or ($branch -eq "prod")) {
                continue
            }
            
            $cleanBranch = $branch -replace "dev/", ""
        
            # Check if branch is in the Jira state file
            if (!($jiraStateFile.ContainsKey($cleanBranch))) {
                # Check if PR was accepted for branch
                $latestPullRequest = Test-PullRequest -Branch $branch

                $state  = $latestPullRequest.Details.state # open, closed
                $merged = $latestPullRequest.Details.merged_at # null, timestamp

                if (($state -ne "open") -and ($null -ne $merged)) {
                    $null = $newTickets.Add($cleanBranch)
                } else {
                    continue
                }
            }
        }

        # Erstelle Tickets für neue Branches, wenn der Pull Request angenommen wurde	
        foreach ($ticket in $newTickets) {
            $null = New-JiraTicket -summary $ticket
        }

        # aktueller Stand Tickets von Jira holen (Get Request)
        $currentJiraStates	
        
        <# Vergleich Status Tickets mit Stand im neusten Jira-State File:

            Unterschied in neuer Liste abspeichern
            Unterscheidung
            dev → test: PR nach test, wenn nicht schon exisitiert
            test → prod: PR nach prod, wenn nicht schon exisitiert
            prod → dev: kein PR, neuer branch mit @ + random hash 
            test → dev: keine Action
            Wenn ein PR erstellt wird immer 4 Sekunden Timeout. 

        #>
        # $jiraStateFile <> $currentJiraStates

        # PHS: Branch in der Package Gallery auf prod setzen (checkout prod)

        # Aktueller Stand Jira Tickets als neues Jira state file schreiben (Stand wurde schon aktualisiert, kein neuer Request)

    }

    end {
    }
}
