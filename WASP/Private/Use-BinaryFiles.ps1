function Use-BinaryFiles {
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
        # create packageName folder
        $packageName = (Get-Item $FilePath).Parent.Parent.Parent.Name
        New-Item -Path $packageName -ItemType Directory
        # create version sub folder
        $packageVersion = (Join-Path $packageName (Get-Item $FilePath).Parent.Parent.Name)
        New-Item -Path $packageVersion -ItemType Directory

        # copy binary to subfolder
        $file = Copy-Item $FilePath $packageVersion -PassThru

        # split file path into folder parts to
        $subpath = ((Get-Item $file).FullName).Split("\")
        # build file url on remote server
        $url = "$remoteServerURl/" + $subpath[-3] + "/" + $subpath[-2] + "/" + $subpath[-1]
        # Send binary file to repo server
        scp -r -i $sshConfig ".\$packageName\" $remoteServer

        # Delete binary file locally
        Write-Log "Removing $FilePath" -Severity 1
        Remove-Item -Path $path -ErrorAction SilentlyContinue

        # Delete helper files
        Write-Log "Removing $packageName" -Severity 1
        Remove-Item -Path $packageName -Recurse -ErrorAction SilentlyContinue
    }

    end {
        return $url
    }
}