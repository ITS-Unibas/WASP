function Compare-JiraState () {
    <#
    .Synopsis 
    Compare the newest jira state to the jira state log file 
    .Description 
    Compare the newest jira state to the jira state log file and create a new list with the differences. New issues are not added to the list to compare.
    .Notes 
    FileName: Compare-JiraState.ps1
    Author: Tim Keller 
    Contact: tim.keller@unibas.ch
    Created: 2024-11-26
    Updated: 2024-11-26
    Version: 1.0.0
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$IssuesCurrentState,
        [Parameter(Mandatory = $true)]
        [hashtable]$jiraStateFileContent
    )

    begin {

    } process {
        try {
            # Create a new hashtable for the Issues that show differences when compared
            $IssuesCompareState =  @{}
            # Go through the list of new states and look if the state file has an entry with the same key
            foreach($key in $IssuesCurrentState.keys) { 
                if ($jiraStateFileContent.ContainsKey($key)) { 
                    # check if entries with the same key have different states
                    if ($jiraStateFileContent[$key].Status -ne $IssuesCurrentState[$key].Status) {
                        # create a new entry with old an new status for the Object
                        $IssuesCompareState[$key] = [PSCustomObject]@{
                            Assignee = $IssuesCurrentState[$key].Assignee
                            Status = $IssuesCurrentState[$key].Status
                            StatusOld = $jiraStateFileContent[$key].Status
                        }
                    }
                }
            }
        }
        catch {
            <#Do this if a terminating exception happens#>
            Write-Host $_.Exception -Severity 3
        }

    } end {
        Write-Log -Message "Comparison of Jira States completed." -Severity 0
        return $IssuesCompareState
    }
}
