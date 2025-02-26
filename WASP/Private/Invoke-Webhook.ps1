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
        Created: 2024-09-02
        Version: 1.1.0
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
        
        # Function to add a new table row
        function Add-TableRow {
            param (
                [string]$packageName,
                [string]$version
            )
        
            return @{
                type = "TableRow"
                cells = @(
                    @{
                        type = "TableCell"
                        items = @(
                            @{
                                type = "TextBlock"
                                text = "$packageName"
                                wrap = $true
                            }
                        )
                    },
                    @{
                        type = "TableCell"
                        items = @(
                            @{
                                type = "TextBlock"
                                text = "$version"
                                wrap = $true
                            }
                        )
                    }
                )
            }
        }
        
    }

    process {        
        $JSONBody = Get-Content $WebHookTemplate -Raw | ConvertFrom-Json
        $table = $JSONBody.attachments[0].content.body | Where-Object {$_.type -eq 'Table'}

        foreach ($Package in $Packages) {
            $PackageName = $Package.name
            $PackageVersion = $Package.version

            $addRow = Add-TableRow -packageName $PackageName -version $PackageVersion

            $table[0].rows += $addRow
        }

        $updatedJsonContent = $JSONBody | ConvertTo-Json -Depth 12

        # Update the JSONBody with the correct System and Style
        $systemRegEx = 'Insert system here'
        $styleRegEx = 'Insert style here'
        $style = ''

        switch ($system) {
            "Test-System" {
                $style = "attention" # orange
            }
            "Prod-System" {
                $style = "good" # green
            }
        }

        $updatedJsonContent = $updatedJsonContent -replace $systemRegEx, $system -replace $styleRegEx, $style

        $parameters = @{
            "URI"           = $WebhookURL
            "Method"        = 'POST'
            "Body"          = $updatedJsonContent
            "ContentType"   = 'application/json'
        }
        
        try {
            Invoke-Webrequest @parameters
			Write-Log "Info-Message successfully send via Webhook to Microsoft Teams." -Severity 1
        }
        catch {
            Write-Log "Error sending Info-Message via Webhook to Microsoft Teams: $($_.Exception)" -Severity 3
        }
    }

    end {
    }
}
