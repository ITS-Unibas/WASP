function Invoke-PostRequest {
    <#
    .SYNOPSIS
        Invokes an REST Api POST request onto a given resource with a given body
    .DESCRIPTION
        Invokes an REST Api POST request onto a given resource by addtionally using a Bearer authorization token. Contents of the request are send in the body.
        Return is in json format.
    #>
    [CmdletBinding()]
    param (
        [string]
        $Url,

        [string]
        $Body
    )

    begin {
        $config = Read-ConfigFile
    }

    process {
        $Splat = @{
            Method      = 'POST'
            Uri         = $Url
            Headers     = @{Authorization = "Token {0}" -f $config.Application.GitHubAPITokenITSUnibasChocoUser}
            Body        = $Body
        }
        return Invoke-RestMethod @Splat -ErrorAction Stop
    }
}