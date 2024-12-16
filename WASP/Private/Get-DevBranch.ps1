function Get-DevBranch {
    <#
    .Synopsis 
    Leitet den Namen des Git-Branches in der Package Gallery vom Namen des Tickets ab
    .Description 
    Notwendig, um Repackaging Branches zu identifizieren. 
    Falls der Repackaging Branch noch nicht exisitert, wird $null zurückgegeben, damit der Branch später erstellt werden kann
    .Notes 
    FileName: Get-DevBranch.ps1
    Author: Tim Keller 
    Contact: tim.keller@unibas.ch
    Created: 2024-12-13
    Updated: 2024-12-13
    Version: 1.0.0
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$RemoteBranches,
        [Parameter(Mandatory = $true)]
        [string]$DevBranchPrefix
    )
    foreach ($branch in $RemoteBranches) {
        if ($branch.StartsWith($DevBranchPrefix)) {
            return $branch
        }
    }
    return $null
}