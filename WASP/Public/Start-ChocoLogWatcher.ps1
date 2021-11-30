function Start-ChocoLogWatcher {
    <#
    .SYNOPSIS
        Watch the choco log in the console
    .DESCRIPTION
        Use this cmdlet to watch the choco log live in the command line
    .PARAMETER LineCount
        Define how much previous lines you want to load. Defaults to 1.
    .EXAMPLE
        PS> Start-ChocoLogWatcher
        PS> Start-ChocoLogWatcher -LineCount 100
    .LINK
    #>

    [cmdletbinding()]
    param(
        [Parameter()]
        [int]
        $LineCount = 1,

        # Sets the log level. Default 0 (Debug). Possible values: 0 (Debug), 1 (Information), 2 (Warning), 3 (Error)
        [Parameter()]
        [ValidateSet(0, 1, 2, 3)]
        [int]
        $LogLevel = 0
    )

    $Config = Read-ConfigFile
    $LogPath = Join-Path -Path $Config.Application.BaseDirectory -ChildPath $Config.Logger.LogSubFilePath
    $LogFile = Get-ChildItem $LogPath | Select-Object -Last 1 | Select-Object -ExpandProperty FullName
    Get-Content $LogFile -Tail $LineCount -Wait | Where-Object {
        if ($_ -match "Debug" -and $LogLevel -eq 0) { Write-Host $_ -ForegroundColor Cyan }
        elseif ($_ -match "Information" -and $LogLevel -le 1) { Write-Host $_ -ForegroundColor Magenta }
        elseif ($_ -match "Warning" -and $LogLevel -le 2) { Write-Host $_ -ForegroundColor Yellow }
        elseif ($_ -match "Error" -and $LogLevel -le 3) { Write-Host $_ -ForegroundColor Red }
        elseif ($LogLevel -eq 0) { Write-Host $_ -ForegroundColor White }
    }
}