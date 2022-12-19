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
        $system = $config.Application.System
        $WebHookTemplate = $config.Application.WebhookTemplate
    }

    process {        
        [System.Collections.ArrayList]$NewPackages = @()
        
        foreach ($Package in $Packages) {
            $PackageName = $Package.name
            $PackageVersion = $Package.version
            $null = $NewPackages.Add("$PackageName $PackageVersion")
        }

        # Formatting for a nicer look in MS Teams
        $pacakgesEdited = foreach ($Package in $NewPackages){$Package.Insert($Package.Length, "`n`n")}

        # Get the Webhook-Template and add the necessary fields: system, color and packages
        $systemRegEx = 'Insert system here'
        $colorRegEx = 'Insert color here'
        $packagesRegEx = 'Insert packages here'
        $color = ''

        switch ($system) {
            "Test-System" {
                $color = "attention" # red
            }
            "Prod-System" {
                $color = "good" # green
            }
        }

        $JSONBody = Get-Content $WebHookTemplate
        $JSONBodyNew = $JSONBody
        $JSONBodyNew = $JSONBodyNew -replace $systemRegEx, $system -replace $packagesRegEx, $pacakgesEdited -replace $colorRegEx, $color

        $parameters = @{
            "URI" = $WebhookURL
            "Method" = 'POST'
            "Body" = $JSONBodyNew
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
