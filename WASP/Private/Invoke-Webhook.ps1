function Invoke-Webhook {
    <#
    .SYNOPSIS
        Invokes a Teams-webhook
    .DESCRIPTION
        Invokes a Teams-webhook to infrom Software-packagers about new packages
    .NOTES
        FileName: Invoke-Webhook.ps1
        Author: Uwe Molnar
        Contact: its-wcs-ma@unibas.ch
        Created: 2022-06-07
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [System.Collections.ArrayList] $Packages
    )

    begin {
        $Config = Read-ConfigFile
        $WebhookURL = $config.Application.TeamsWebhook
        $PackagesInbox = $config.Application.PackagesInbox
        $system = $config.Application.System
        $date = Get-Date -Format "yyyy-MM-dd HH:mm"
    }

    process {        
        [System.Collections.ArrayList]$NewPackages = @()
        
        foreach ($Package in $Packages) {
            $PackageName = $Package.name
            $PackageVersion = $Package.version
            $null = $NewPackages.Add("$PackageName $PackageVersion")
        }

        # Formatting for a nicer look in MS Teams
        $messageText = foreach ($Package in $NewPackages){$Package.Insert($Package.Length, "`n`n")}

        $JSONBody = @{
            "@type" = "MessageCard"
            "@context" = "<http://schema.org/extensions>"
            "summary" = "New Software-Packages available"
            "themeColor" = 'FFCC00'
            "title" = "[$date] New Software-Package(s) [$system]"
            "text" = "The following new packages are now available and can be merged into the package gallery:`n`n`n`n$messageText"
        }

        $TeamMessageBody = ConvertTo-Json $JSONBody

        $parameters = @{
            "URI" = $WebhookURL
            "Method" = 'POST'
            "Body" = $TeamMessageBody
            "ContentType" = 'application/json'
        }
        
        try {
            Invoke-RestMethod @parameters
			Write-Log "Info-Message successfully send via Webhook to Microsoft Teams." -Severity 1
        }
        catch {
            Write-Log "Error sending Info-Message via Webhook to Microsoft Teams: $($_.Exception)" -Severity 3
        }
    }

    end {
    }
}
