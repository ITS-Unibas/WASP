function Invoke-DeleteRequest {
    <#
    .SYNOPSIS
        Invokes an REST Api DELETE request onto a given resource with a given body
    .DESCRIPTION
        Invokes an REST Api DELETE request onto a given resource by addtionally using a Bearer authorization token. Contents of the request are send in the body.
        Return is in json format.
    #>
    [CmdletBinding()]
    param (
        [string]
        $Url
    )

    begin {
        $config = Read-ConfigFile
    }

    process {
        $Splat = @{
            Method      = 'DELETE'
            Uri         = $Url
            Headers     = @{Authorization = "Token {0}" -f $config.Application.GitHubAPITokenITSUnibasChocoUser}
        }
        return Invoke-RestMethod @Splat -ErrorAction Stop
    }
}