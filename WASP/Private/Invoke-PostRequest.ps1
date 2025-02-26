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
        try {
            $Splat = @{
                Method      = 'POST'
                Uri         = $Url
                Headers     = @{Authorization = "Token {0}" -f $config.Application.GitHubAPITokenITSUnibasChocoUser}
                Body        = $Body
            }
            # Github Success Response ist unterschiedlich zur Error Response
            $res = Invoke-WebRequest @Splat
            $response = [PSCustomObject]@{ Status = $res.StatusCode }
            return $response
        }
        catch {
            $response = $_.ErrorDetails.message | ConvertFrom-Json
            return $response
        }

    }
}