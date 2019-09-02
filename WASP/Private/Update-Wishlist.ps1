function Update-Wishlist {
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

    )

    begin {
    }

    process {
        Set-Location $PSScriptRoot
        Write-Log ([string] (git checkout master 2>&1))
        Write-Log ([string] (git pull 2>&1))
    }

    end {
    }
}