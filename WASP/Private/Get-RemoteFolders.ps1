function Get-RemoteFolders {
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
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $BranchName
    )

    begin {
        $config = Read-ConfigFile
    }

    process {
        # https://git.its.unibas.ch/rest/api/1.0/projects/csswcs/repos/package-gallery/browse?at=test
        $folders = New-Object System.Collections.ArrayList
        $url = ("{0}/rest/api/1.0/projects/{1}/repos/{2}/browse?at={3}" -f $config.Application.GitBaseURL, $config.Application.GitProject, $Repository, $BranchName)
        try {
            $r = Invoke-GetRequest $url
            $JSONbranches = $r.values
            $JSONbranches | ForEach-Object { $null = $folders.Add($_.path.components[0]) }
            # Check if file type is DIRECTORY

            <# Example output
                path
                components	[]
                name	""
                toString	""
                revision	"test"
                children
                size	3
                limit	500
                isLastPage	true
                values
                0
                path
                components
                0	".gitignore"
                parent	""
                name	".gitignore"
                extension	"gitignore"
                toString	".gitignore"
                contentId	"765203e9746758313f15dbabcf8de3e7ca646899"
                type	"FILE"
                size	408
                1
                path
                components
                0	"googlechrome"
                1	"77.0.3865.90"
                parent	"googlechrome"
                name	"77.0.3865.90"
                extension	"90"
                toString	"googlechrome/77.0.3865.90"
                node	"a7073949a50fcc27428994f54f0005a18dc5201f"
                type	"DIRECTORY"
                2
                path
                components
                0	"sourcetree"
                1	"3.2.6"
                parent	"sourcetree"
                name	"3.2.6"
                extension	"6"
                toString	"sourcetree/3.2.6"
                node	"34682eb5648a8df3bc5c3056f1af0a8ae9d9f722"
                type	"DIRECTORY"
                start	0
            #>
        }
        catch {
            Write-Log "Get request failed for $url" -Severity 3
        }

        Write-Log "Found remote folders: $folders"

        return $folders
    }

    end {

    }
}