function Start-ChocoLogWatcher {
    <#
    .SYNOPSIS
        Watch the choco log in the console
    .DESCRIPTION
        Use this cmdlet to watch the choco log live in the command line
    .EXAMPLE
        PS>
    .LINK
    #>

    [cmdletbinding()]
    param(
    )

    $Config = Read-ConfigFile
    $LogPath = Join-Path -Path $Config.Application.BaseDirectory -ChildPath $Config.Logger.LogSubFilePath
    $LogFile = Get-ChildItem $LogPath | Select-Object -Last 1 | Select-Object -ExpandProperty FullName
    Get-Content $LogFile -Tail 1 -Wait | Where-Object {
        if ($_ -match "Debug") { Write-Host $_ -ForegroundColor Cyan }
        elseif ($_ -match "Information") { Write-Host $_ -ForegroundColor Magenta }
        elseif ($_ -match "Warning") { Write-Host $_ -ForegroundColor Yellow }
        elseif ($_ -match "Error") { Write-Host $_ -ForegroundColor Red }
        else { Write-Host $_ -ForegroundColor White }
    }
}