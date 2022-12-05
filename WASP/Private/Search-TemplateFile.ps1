function Search-TemplateFile {
    <#
    .SYNOPSIS
        TBD
    .DESCRIPTION
        TBD
    .NOTES
        FileName: Search-TemplateFile.ps1
        Author: Uwe Molnar
        Contact: its-wcs-ma@unibas.ch
        Created: 2022-04-10
        Version: 1.0.0
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Object]
        $package
    )

    begin {
        $config = Read-ConfigFile
        $GitRepo = $config.Application.ChocoTemplates
        $chocoTemplatesFolder = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $chocoTemplatesFolder = $chocoTemplatesFolder.Replace(".git", "")
        $chocoTemplatesFolderPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $chocoTemplatesFolder
        
        $template = New-Object -TypeName psobject
        $template | Add-Member -MemberType NoteProperty -Name available -Value $false
        $template | Add-Member -MemberType NoteProperty -Name templateFilePath -Value ''
    }

    process {
        $templatePackage = "$package.json"
        $chocoTemplatePath = Join-Path -Path $chocoTemplatesFolderPath $templatePackage

        if (Test-Path -Path $chocoTemplatePath){
            $template.available = $true
            $template.templateFilePath = $chocoTemplatePath
            Write-Log -Message "Found a template to rewrite the chocolateyInstall.ps1 for '$package'" -Severity 1
        }
    }
    
    end {
        return $template
    }
}