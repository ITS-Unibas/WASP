function Get-CurrentBranchName() {
    <#
    .SYNOPSIS
        Get the current checked out branchname
    .DESCRIPTION
        This cmdlet retrieves the current checked out branch for a given git folder
    .PARAMETER Path
        Path to a valid git folder
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    process {
        # Should we check the path here again or assume it was tested before? We could check with $LastExitCode
        return &git -C $Path rev-parse --abbrev-ref HEAD
    }

}