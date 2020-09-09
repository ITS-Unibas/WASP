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
        $LineCount = 1
    )

    $Config = Read-ConfigFile
    $LogPath = Join-Path -Path $Config.Application.BaseDirectory -ChildPath $Config.Logger.LogSubFilePath
    $LogFile = Get-ChildItem $LogPath | Select-Object -Last 1 | Select-Object -ExpandProperty FullName
    Get-Content $LogFile -Tail $LineCount -Wait | Where-Object {
        if ($_ -match "Debug") { Write-Host $_ -ForegroundColor Cyan }
        elseif ($_ -match "Information") { Write-Host $_ -ForegroundColor Magenta }
        elseif ($_ -match "Warning") { Write-Host $_ -ForegroundColor Yellow }
        elseif ($_ -match "Error") { Write-Host $_ -ForegroundColor Red }
        else { Write-Host $_ -ForegroundColor White }
    }
}