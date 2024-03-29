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
        $GitRepo = $config.Application.JiraObserver
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $JiraObserverPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }

    process {
        # Check if path exists and that pyhton is in path variables
        try {
            $filePath = Join-Path $JiraObserverPath "JiraObserver.py"
            $results = ([string] (python $filePath 2>&1))
            $results = $results -replace "Debug:| Debug:", "`nDebug:" -replace " Error:", "`nError:" -replace " Information:", "`nInformation:" -replace " INFO:root", "`nINFO:root" -replace " Warning:", "`nWarning:"
            # Next two lines remove the CYGWIN-Error, because it is no error but occuring in the Log --> Python-Module "git" needs update?!
			$results = $results -replace "DEBUG:git.util:Failed checking if running in CYGWIN due to:.*", ""
			$results = $results.Trim()
			Write-Log ($results) -Severity 1
        }
        catch {
            Write-Log "$($_.Exception)" -Severity 3
        }
    }

    end {
    }
}
