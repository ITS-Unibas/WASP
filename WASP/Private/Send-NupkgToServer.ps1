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
        try {
            $nupkg = (Get-ChildItem -Path $nuspecFolder | Where-Object { $_.FullName -match ".nupkg" }).FullName
            if (-Not (Test-Path ($nupkg)) -or -Not ($nupkg -match ".nupkg")) {
                Write-Log ("No nupkg to push, skipping package " + $_.FullName)
                return
            }
            # Try to push the package to the dev choco server
            Invoke-Expression -Command ("choco push " + $nupkg + " -s " + $url + " -f --api-key=chocolateyrocks")
            Write-Log ("Pushed package " + $_.FullName + " successfully to server.") -Severity 1
        }
        catch {
            Write-Log ("Package " + $nupkg + " could not be pushed.") -Severity 3
        }
    }
}