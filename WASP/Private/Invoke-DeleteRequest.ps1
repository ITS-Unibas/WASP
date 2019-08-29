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
        $Url,

        [string]
        $Body
    )

    begin {
        $config = Read-ConfigFile
    }

    process {
        $Splat = @{
            Method      = 'DELETE'
            Uri         = $Url
            ContentType = "application/json"
            Headers     = @{Authorization = "Bearer {0}" -f $config.Application.BitBucketAPIToken }
            Body        = $Body
        }
        return Invoke-RestMethod @Splat -ErrorAction Stop
    }
}