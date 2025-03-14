function Send-NupkgToServer {
    <#
    .SYNOPSIS
        Perform choco push for nupkg in given folder to given choco server url
    .DESCRIPTION
        Long description
    .NOTES
        FileName: Send-NupkgToServer.ps1
        Author: Kevin Schaefer, Maximilian Burgert, Tim Koenigl
        Contact: its-wcs-ma@unibas.ch
        Created: 2019-08-07
        Updated: 2020-02-20
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $nuspecFolder,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $url
    )
    begin {
        $Config = Read-ConfigFile
    }
    process {
        $nupkg = (Get-ChildItem -Path $nuspecFolder | Where-Object { $_.FullName -match "\.nupkg" }).FullName
        $nuspecFile = (Get-ChildItem -Path $nuspecFolder | Where-Object { $_.FullName -match "\.nuspec" }).FullName
        # Test-Path on a null valued path will always result in an error, so just test if there was found anything
        if (-Not $nuspecFile -or -Not $nupkg) {
            Write-Log ("No nupkg or nuspec found in " + $nuspecFolder)
            return
        }
        try {
            # Try to push the package to the dev choco server
            $NuGetExecutable = Join-Path $Config.Application.BaseDirectory "NuGet\nuget.exe"
            $InvokeMessage = Invoke-Expression -Command ("$NugetExecutable push " + $nupkg + " -Source " + $url + " -ApiKey $($Config.Application.RepositoryManagerAPIKey) -Timeout 10800")
            $InvokeMessage | ForEach-Object { Write-Log $_ }
            Write-Log ("Pushed package " + $nupkg + " successfully to server.") -Severity 1
        }
        catch {
            Write-Log "$($_.Exception.Message)" -Severity 3
            Write-Log ("Package " + $nupkg + " could not be pushed.") -Severity 3
        }
    }
}