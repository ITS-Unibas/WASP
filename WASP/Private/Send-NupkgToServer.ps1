function Send-NupkgToServer {
    <#
    .SYNOPSIS
        Short description
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        [string]
        $nuspecFolder,

        [String]
        $url
    )

    process {
        $nupkg = (Get-ChildItem -Path $nuspecFolder | Where-Object { $_.FullName -match ".nupkg" }).FullName
        $nuspecFile = (Get-ChildItem -Path $nuspecFolder | Where-Object { $_.FullName -match ".nuspec" }).FullName
        # Test-Path on a null valued path will always result in an error, so just test if there was found anything
        if (-Not $nuspecFile -or -Not $nupkg) {
            Write-Log ("No nupkg or nuspec found in " + $nuspecFolder)
            return
        }
        try {
            # Try to push the package to the dev choco server
            Invoke-Expression -Command ("choco push " + $nupkg + " -s " + $url + " -f --api-key=chocolateyrocks")
            Write-Log ("Pushed package " + $nupkg + " successfully to server.") -Severity 1
        }
        catch {
            Write-Log ("Package " + $nupkg + " could not be pushed.") -Severity 3
        }
    }
}