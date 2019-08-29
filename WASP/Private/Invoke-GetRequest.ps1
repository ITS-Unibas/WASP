function Invoke-GetRequest {
    <#
    .SYNOPSIS
        Invokes an REST Api GET request onto a given resource
    .DESCRIPTION
        Invokes an REST Api GET request onto a given resource by addtionally using a Bearer authorization token. Return is in json format.
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
            Method      = 'GET'
            Uri         = $url
            ContentType = "application/json"
            Headers     = @{Authorization = "Bearer {0}"-f$config.Application.BitBucketAPIToken}
        }
        return Invoke-RestMethod @Splat -ErrorAction Stop
    }
}