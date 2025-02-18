function Read-JiraStateFile () {
    <#
    .Synopsis 
    Read the latest jira state file
    .Description 
    Read the lates jira state file 
    .Notes 
    FileName: Read-JiraStateFile.ps1
    Author: Tim Keller 
    Contact: tim.keller@unibas.ch
    Created: 2024-07-04
    Updated: 2024-08-08
    Version: 1.0.0
    #>
    param(
    )

    begin {
        $Config = Read-ConfigFile
        $LogPath = Join-Path -Path $Config.Application.BaseDirectory -ChildPath $Config.Logger.LogSubFilePath
        $JiraStateFolder = Join-Path -Path $LogPath -ChildPath $Config.Logger.LogSubFilePathJiraStates
        $MaxLogFiles = $Config.Logger.MaxLogFiles
    } process {
        try {
            <#Create a hashtable to find the newest jira state file in the jira state folder#>
            $Prefix = $Config.Logger.LogFileNamePrefixJiraStates
            $Suffix = ".json"
            $JiraStateFiles = Get-ChildItem -Path $JiraStateFolder -Filter "$Prefix*$Suffix"
            <#Check if the number of maximum log files is surpass and delete the oldest log files when necessary#>
            $numJiraStateFiles = ($JiraStateFiles | Measure-Object).Count
            if ($numJiraStateFiles -eq $MaxLogFiles) {
                $JiraStateFiles | Sort-Object CreationTime | Select-Object -First 1 | Remove-Item
            }
            elseif ($numJiraStateFiles -gt $MaxLogFiles) {
                $JiraStateFiles | Sort-Object CreationTime | Select-Object -First ($numJiraStateFiles - $MaxLogFiles + 1) | Remove-Item
            }
            <#Select the last created file as the newest jira state file.#>
            $JiraFile = = $($JiraStateFiles | Sort-Object CreationTime | Select-Object -Last 1).FullName
            $JiraState = Get-Content -Path $JiraFile -Raw | ConvertFrom-Json -ErrorAction Stop
            <#Put the the information of the jira state log into the format that the name@version is the key of the hashtable and the status and assignee are the values#>
            $IssuesState = @{}
            $JiraState.Issues.psobject.properties | ForEach-Object { 
                $IssuesState[$_.Name] = $_.Value
            }
        }
        catch {
            <#Do this if a terminating exception happens#>
            Write-Host $_.Exception -Severity 3
        }

    } end {
        return $IssuesState, $JiraFile
    }
}
