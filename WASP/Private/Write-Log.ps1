function Write-Log {
    <#
    .SYNOPSIS
        Writes a message in a log file.

    .DESCRIPTION
        If the Write-Log function is called the given string is logged into a log file. The log file folder is created if non-existing and there will be a maximum number of log files.DESCRIPTION
        If the max number of log files is reached the oldest one gets removed.
    .NOTES
        FileName:    Write-Log.ps1
        Author:      Maximilian Burgert, Tim Koenigl, Kevin Schaefer
        Contact:     its-wcs-ma@unibas.ch
        Created:     2019-07-30
        Updated:     2019-07-31
        Version:     1.0.0

    .PARAMETER Message
        The message which gets logged as a string.

    .PARAMETER Severity
        The log level. There are 3 log levels (1,2,3) where 0 is the lowest and 3 the highest log level.

    .EXAMPLE
        PS> Write-Log -Message "TestLog" -Severity 2
    #>
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter()]
        [ValidateSet('0', '1', '2', '3')]
        [ValidateNotNull()]
        [int]$Severity = 0 # Default to a low severity. Otherwise, override
    )
    begin {
        # Always get current configfile
        $Config = Read-ConfigFile

        $LogPath = Join-Path -Path $Config.Application.BaseDirectory -ChildPath $Config.Logger.LogSubFilePath
        $MaxLogFiles = $Config.Logger.MaxLogFiles
        $LogLevel = $Config.Logger.LogLevel
        $LogFilePath = Join-Path -Path $LogPath -ChildPath "$($Config.Logger.LogFileNamePrefix)_$(Get-Date -Format yyyyMMdd).log"
        $LogToHost = $Config.Logger.LogToHost
        $EventLogName = $Config.Logger.EventLogName
        $EventId = $Config.Logger.EventID

    } process {

        if ($Message -eq "") {
            return
        }

        switch ($Severity) {
            0 {
                $EntryType = "Debug"
                $ForegroundColor = "Cyan"
            }
            1 {
                $EntryType = "Information"
                $ForegroundColor = "Magenta"
            }
            2 {
                $EntryType = "Warning"
                $ForegroundColor = "Yellow"
            }
            3 {
                $EntryType = "Error"
                $ForegroundColor = "Red"
            }
            Default {
                $ForegroundColor = "White"
            }
        }

        $line = "$(Get-Date -Format 'dd/MM/yyyy HH:mm') $($EntryType) $((Get-PSCallStack)[1].Command): $($Message)"

        # Ensure that $LogFilePath is set to a global variable at the top of script
        # Only log when severity level is greater or equal log level
        if ($Severity -ge $LogLevel) {
            if (-Not (Test-Path $LogPath -ErrorAction SilentlyContinue)) {
                $null = New-Item -ItemType directory -Path $LogPath
            }
            if (-Not (Test-Path $LogFilePath -ErrorAction SilentlyContinue)) {
                $LogFiles = Get-ChildItem -Path $LogPath -Filter '*.log'
                $numLogFiles = ($LogFiles | Measure-Object).Count
                if ($numLogFiles -eq $MaxLogFiles) {
                    $LogFiles | Sort-Object CreationTime | Select-Object -First 1 | Remove-Item
                }
                elseif ($numLogFiles -gt $MaxLogFiles) {
                    Get-ChildItem $LogPath | Sort-Object CreationTime | Select-Object -First ($numLogFiles - $MaxLogFiles + 1) | Remove-Item
                }
                $null = New-Item $LogFilePath -type file
            }

            $line | Out-File $LogFilePath -Append

            if (-Not ($Severity -eq 0) -and ($PSVersionTable.PSVersion -lt [version]'6.0.0')) {
                # Need to catch this, because there is no way to silence it
                try {
                    $SourceExists = [System.Diagnostics.EventLog]::SourceExists($EventLogName)
                }
                catch {
                    $SourceExists = $false
                }
                if (-Not $SourceExists) {
                    New-EventLog -LogName "Application" -Source $EventLogName
                }
                Write-EventLog -Logname "Application" -Source $EventLogName -EventID $EventId -EntryType $EntryType -Message $Message
            }

            if ($LogToHost) {
                Write-Host $line -ForegroundColor $ForegroundColor
            }
        }
    }
}
