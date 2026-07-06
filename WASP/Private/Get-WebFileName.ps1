function Get-WebFileName {
    <#
    .SYNOPSIS
        Gets the original file name from a url. Used by Get-WebFile to determine the original file name for a file.

    .DESCRIPTION
        Uses several techniques to determine the original file name of the file based on the url for the file. Extends the original "Get-WebFileName.ps1"-script with new header-functionalities

    .OUTPUTS
        None
    #>
    param(
        [parameter(Mandatory = $false, Position = 0)][string] $url = '',
        [parameter(Mandatory = $true, Position = 1)][string] $defaultName,
        [parameter(Mandatory = $false)][string] $userAgent = 'chocolatey command line',
        [parameter(ValueFromRemainingArguments = $true)][Object[]] $ignoredArguments
    )

    Write-FunctionCallLogMessage -Invocation $MyInvocation -Parameters $PSBoundParameters

    $originalFileName = $defaultName
    $fileName = $null

    if ($url -eq $null -or $url -eq '') {
        Write-Debug "Url was null, using default name."
        return $originalFileName
    }

    try {
        $uri = [System.Uri]$url
        if ($uri.IsFile()) {
            $fileName = [System.IO.Path]::GetFileName($uri.LocalPath)
            Write-Debug "Url is local file, returning fileName"

            return $fileName
        }
    }
    catch {
        #continue on
    }

    if ($url.StartsWith('ftp')) {
        Write-Debug "Url is FTP, using default name."
        return $originalFileName
    }

    $request = [System.Net.HttpWebRequest]::Create($url)
    if ($request -eq $null) {
        Write-Debug "Request was null, using default name."
        return $originalFileName
    }

    $defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
    if ($defaultCreds -ne $null) {
        $request.Credentials = $defaultCreds
    }

    $client = New-Object System.Net.WebClient
    if ($defaultCreds -ne $null) {
        $client.Credentials = $defaultCreds
    }

    # check if a proxy is required
    $explicitProxy = $env:chocolateyProxyLocation
    $explicitProxyUser = $env:chocolateyProxyUser
    $explicitProxyPassword = $env:chocolateyProxyPassword
    $explicitProxyBypassList = $env:chocolateyProxyBypassList
    $explicitProxyBypassOnLocal = $env:chocolateyProxyBypassOnLocal
    if ($explicitProxy -ne $null) {
        # explicit proxy
        $proxy = New-Object System.Net.WebProxy($explicitProxy, $true)
        if ($explicitProxyPassword -ne $null) {
            $passwd = ConvertTo-SecureString $explicitProxyPassword -AsPlainText -Force
            $proxy.Credentials = New-Object System.Management.Automation.PSCredential ($explicitProxyUser, $passwd)
        }

        if ($explicitProxyBypassList -ne $null -and $explicitProxyBypassList -ne '') {
            $proxy.BypassList = $explicitProxyBypassList.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)
        }
        if ($explicitProxyBypassOnLocal -eq 'true') {
            $proxy.BypassProxyOnLocal = $true;
        }

        Write-Debug "Using explicit proxy server '$explicitProxy'."
        $request.Proxy = $proxy
    }
    elseif ($client.Proxy -and !$client.Proxy.IsBypassed($url)) {
        # system proxy (pass through)
        $creds = [Net.CredentialCache]::DefaultCredentials
        if ($creds -eq $null) {
            Write-Debug "Default credentials were null. Attempting backup method"
            $cred = Get-Credential
            $creds = $cred.GetNetworkCredential();
        }
        $proxyAddress = $client.Proxy.GetProxy($url).Authority
        Write-Debug "Using system proxy server '$proxyaddress'."
        $proxy = New-Object System.Net.WebProxy($proxyAddress)
        $proxy.Credentials = $creds
        $proxy.BypassProxyOnLocal = $true
        $request.Proxy = $proxy
    }

    $request.Method = "GET"
    $request.Accept = '*/*'
    $request.AllowAutoRedirect = $true
    $request.MaximumAutomaticRedirections = 20
    #$request.KeepAlive = $true
    $request.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
    $request.Timeout = 30000
    if ($env:chocolateyRequestTimeout -ne $null -and $env:chocolateyRequestTimeout -ne '') {
        $request.Timeout = $env:chocolateyRequestTimeout
    }
    if ($env:chocolateyResponseTimeout -ne $null -and $env:chocolateyResponseTimeout -ne '') {
        $request.ReadWriteTimeout = $env:chocolateyResponseTimeout
    }

    #http://stackoverflow.com/questions/518181/too-many-automatic-redirections-were-attempted-error-message-when-using-a-httpw
    $request.CookieContainer = New-Object System.Net.CookieContainer
    $request.UserAgent = $userAgent

    [System.Text.RegularExpressions.Regex]$containsABadCharacter = New-Object Regex("[" + [System.Text.RegularExpressions.Regex]::Escape([System.IO.Path]::GetInvalidFileNameChars() -join '') + "\=\;]");

    try {
        [System.Net.HttpWebResponse]$response = $request.GetResponse()
        if ($response -eq $null) {
            Write-Debug "Response was null, using default name."
            return $originalFileName
        }

        [string]$header = $response.Headers['Content-Disposition']
        [string]$headerLocation = $response.Headers['Location']

        # start with content-disposition header
        if ($header -ne '') {
            $fileHeaderName = 'filename='
            $index = $header.LastIndexOf($fileHeaderName, [StringComparison]::OrdinalIgnoreCase)
            if ($index -gt -1) {
                Write-Debug "Using header 'Content-Disposition' to determine file name."
                $fileName = $header.Substring($index + $fileHeaderName.Length).Replace('"', '')
            }
        }
        if ($containsABadCharacter.IsMatch($fileName)) {
            $fileName = $null
        }

        # If empty, check location header next
        if ($fileName -eq $null -or $fileName -eq '') {
            if ($headerLocation -ne '') {
                Write-Debug "Using header 'Location' to determine file name."
                $fileName = [System.IO.Path]::GetFileName($headerLocation)
            }
        }
        if ($containsABadCharacter.IsMatch($fileName)) {
            $fileName = $null
        }

        # Next comes using the response url value
        if ($fileName -eq $null -or $fileName -eq '') {
            $responseUrl = $response.ResponseUri.ToString()
            if (!$responseUrl.Contains('?')) {
                Write-Debug "Using response url to determine file name. '$responseUrl'"
                $fileName = [System.IO.Path]::GetFileName($responseUrl)
            }
        }
        if ($containsABadCharacter.IsMatch($fileName)) {
            $fileName = $null
        }

        # Next comes using the request url value
        if ($fileName -eq $null -or $fileName -eq '') {
            $requestUrl = $url
            $extension = [System.IO.Path]::GetExtension($requestUrl)
            if (!$requestUrl.Contains('?') -and $extension -ne $null -and $extension -ne '') {
                Write-Debug "Using request url to determine file name. ' $requestUrl'"
                $fileName = [System.IO.Path]::GetFileName($requestUrl)
            }
        }

        # when all else fails, default the name
        if ($fileName -eq $null -or $fileName -eq '' -or $containsABadCharacter.IsMatch($fileName)) {
            Write-Debug "File name is null or illegal. Using $originalFileName instead."
            $fileName = $originalFileName
        }

        Write-Debug "File name determined from url is '$fileName'"

        return $fileName
    }
    catch {
        if ($request -ne $null) {
            $request.ServicePoint.MaxIdleTime = 0
            $request.Abort();
            # ruthlessly remove $request to ensure it isn't reused
            Remove-Variable request
            Start-Sleep 1
            [GC]::Collect()
        }

        Write-Debug "Url request/response failed - file name will be '$originalFileName':  $($_)"

        return $originalFileName
    }
    finally {
        if ($response -ne $null) {
            $response.Close();
        }
    }
}
