function Get-NuspecXMLValue {
    <#
    .SYNOPSIS
        This function gets the path to a package with an nuspec file inside and extracts the value of a specific tag.
    .DESCRIPTION
        Inside the given package this function is looking for a nuspec file. In each package there should always be
        only one .nuspec file.
        Any wanted tag can be given and the value inside this tag will be returned as a string.
    .NOTES
        FileName: Get-NuspecXMLValue.ps1
        Author: Kevin Schaefer, Maximilian Burgert, Tim Koenigl
        Contact: its-wcs-ma@unibas.ch
        Created: 2019-08-06
        Updated: 2019-08-06
        Version: 1.0.0
    .PARAMETER NuspecFile
        Path to the nuspec file
        .PARAMETER Tag
        Tag which the value should be extracted from
    .EXAMPLE
        PS>
    .LINK
    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NuspecFile,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Tag
    )
    begin {
        $Value = $null
    }
    process {
        $TagLine = (Get-Content $NuspecFile | Where-Object { $_ -like "*<$Tag>*" })
        $Value = $TagLine -Replace "<$Tag>", ""
        $Value = $Value -Replace "</$Tag>", ""
    } end {
        try {
            return $Value.Trim()
        }
        catch {
            Write-Log "The tag was not found in the specified file: $NuspecFile. Please provide a valid nuspec file." -Severity 3
        }
    }

}
