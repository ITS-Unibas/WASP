function Use-BinaryFiles {
    <#
    .SYNOPSIS
    Function handles binary files. 
    
    .DESCRIPTION
    First, create folder for package and subfolder for version, then copy file of given filepath 
    to version subfolder. Push the folder structure containing the file to the remote server.
    After pushing, delete local binary and folder structure.
    The path on the remote server of the binary file from the filePath param is returned.
    Upon failure, local folder structure is removed.

    .PARAMETER FilePath
    Path to binary file that should be pushed to remote server.
    
    .OUTPUTS
    Path of binary file on remote server
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, Position = 0)][string] $FilePath
    )

    begin {
        # Always get current configfile
        $Config = Read-ConfigFile
        $sshConfig = $Config.Application.PathToSSHKey
        $remoteServer = $Config.Application.BinaryServerUrlSSH
        $remoteServerURL = $Config.Application.BinaryServerUrl
    }

    process {
        Write-Log "Move Binary for $FilePath"

        $packageName = (Get-Item $FilePath).Directory.Parent.Parent.Name

        try {
            # create packageName folder
            $tmp = New-Item -Path $packageName -ItemType Directory
            Write-Log "Created folder $packageName"

            # create version sub folder
            $packageVersion = (Join-Path $packageName (Get-Item $FilePath).Directory.Parent.Name)
            $tmp = New-Item -Path $packageVersion -ItemType Directory

            Write-Log "Created folder $packageVersion"
            # copy binary to subfolder
            $file = Copy-Item $FilePath $packageVersion -PassThru

            # split file path into folder parts to
            $subpath = ((Get-Item $file).FullName).Split("\")
            # build file url on remote server
            $UrlOnServer = "$remoteServerURl/" + $subpath[-3] + "/" + $subpath[-2] + "/" + $subpath[-1]
            Write-Log "Send binary file to $UrlOnServer"
            # Send binary file to repo server
            scp -r -i $sshConfig ".\$packageName\" $remoteServer

            # Delete binary file locally
            Write-Log "Remove $FilePath" -Severity 1
            Remove-Item -Path $FilePath -ErrorAction SilentlyContinue

            # Delete helper files
            Write-Log "Remove $packageName" -Severity 1
            Remove-Item -Path $packageName -Recurse -ErrorAction SilentlyContinue

            Write-Log "Function returns $UrlOnServer" -Severity 1
            return $UrlOnServer
        }
        catch [Exception] {
            Write-Log ($_.Exception | Format-List -force | Out-String) -Severity 3
            # Delete helper files
            Write-Log "Remove $packageName" -Severity 1
            Remove-Item -Path $packageName -Recurse -ErrorAction SilentlyContinue
        }
    }
}