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
    Updated: 2024-07-16
    Version: 1.0.0
    #>
    param(
    )

    begin {
        $Config = Read-ConfigFile
        $LogPath = Join-Path -Path $Config.Application.BaseDirectory -ChildPath $Config.Logger.LogSubFilePath
        $JiraStateFolder = Join-Path -Path $LogPath -ChildPath $Config.Logger.LogSubFilePathJiraStates
    } process {
        try {
            <#Create a ordered hashtable to find the newest jira state file in the jira state folder#>
            $AvailableFiles = [Ordered]@{}
            $Prefix = $Config.Logger.LogFileNamePrefixJiraStates
            $Suffix = ".json"
            <#Extract the date from the jira state logs and add them to the AvailabeFiles hashtable#>
            Get-ChildItem -Path $JiraStateFolder | ForEach-Object {$AvailableFiles[$_.Name] = $([datetime]::parseexact($($_.Name -replace  "$Prefix(.+)$Suffix", '$1'), 'yyyy-MM-dd_HH-mm-ss', $null))} 
            foreach($item in $date_array)
            {
                $item -replace  "$Prefix(.+)$Suffix", '$1'
            }
            <#Get the full file path of the newest jira state file and convert it from json#>
            $FilePath= Join-Path -Path (Get-Item -Path $JiraStateFolder).FullName -ChildPath $($AvailableFiles.Keys | Select-Object -Last 1)
            $JiraState = Get-Content -Path $FilePath -Raw | ConvertFrom-Json -ErrorAction Stop
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
        return $IssuesState
    }
}




