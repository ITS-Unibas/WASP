function Write-JiraStateFile () {
    <#
    .Synopsis 
    Read the latest jira state file
    .Description 
    Read the lates jira state file 
    .Notes 
    FileName: Write-JiraStateFile.ps1
    Author: Tim Keller 
    Contact: tim.keller@unibas.ch
    Created: 2024-07-04
    Updated: 2024-07-16
    Version: 1.0.0
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.SortedList]$IssuesCurrentState
    )

    begin {
        $Config = Read-ConfigFile
        $LogPath = Join-Path -Path $Config.Application.BaseDirectory -ChildPath $Config.Logger.LogSubFilePath
        $JiraStateFolder = Join-Path -Path $LogPath -ChildPath $Config.Logger.LogSubFilePathJiraStates
    } process {
        try {
            $NewJiraState = @{}
            $NewJiraState["Issues"] = $IssuesCurrentState
            $CurrentDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $NewJiraState["Date"] = $CurrentDate
            $OutFile = Join-Path -Path $JiraStateFolder -ChildPath "jira_state$CurrentDate.json"
            $NewJiraState | ConvertTo-Json | Out-File $OutFile
        }
        catch {
            <#Do this if a terminating exception happens#>
            Write-Host $_.Exception -Severity 3
        }

    } end {
        Write-Log -Message "Succesfully stored JiraState File jira_state$CurrentDate.json to $JiraStateFolder" -Severity 0
    }
}

