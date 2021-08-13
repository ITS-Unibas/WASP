function Get-NupkgHash() {
  <#
    .SYNOPSIS
        Gets a hash string for a given nupkg

    .DESCRIPTION
        This function extracts the nupkg into a temporary created folder. Afterwards it goes over the nuspec, all files in the tools folder and in the legal folder if they exists.
        It creates the hash for each file and appends it to a hash string which is returned later. The temporary folder will be deleted in the end, so the package does not change by this function.

    .PARAMETER nupkgPath
        This parameter is the absolute path of the nupkg to extract.

    .PARAMETER packageFolder
        This parameter is the absolute path to the package folder where the nupkg is in.

    .OUTPUTS
        This fuction returns a string which consists of a concatenation of all file hashes and represents the hashvalue of the nupkg
    #>
  param(
    [Parameter(Mandatory = $true)][string]$nupkgPath,
    [Parameter(Mandatory = $true)][string]$packageFolder
  )
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $hashString = ""
  # Delete "unzipedNupkg" and "package.zip". For some reason those items aren't always removed (see lines 63/64). To get sure no errors occure in the Workflow, we remove them as a precaution
  Remove-Item (Join-Path $packageFolder "unzipedNupkg") -Force -Recurse -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $packageFolder "package.zip") -Force -ErrorAction SilentlyContinue
  $dir = New-Item -ItemType directory -Path (Join-Path $packageFolder "unzipedNupkg")
  try {
    $tmpZipPath = Join-Path (Split-Path $nupkgPath -Parent) "package.zip"
    Copy-Item $nupkgPath -Destination $tmpZipPath
    Expand-Archive -Path $tmpZipPath -DestinationPath $dir.FullName
    #[System.IO.Compression.ZipFile]::ExtractToDirectory($nupkgPath, $dir.FullName)
    # Get hashvalue of the nuspec File
    $nuspec = (Get-ChildItem -Path $dir.FullName | Where-Object { $_.FullName -match ".nuspec" }).FullName
    $hashString = $hashString + ([string](Get-FileHash $nuspec).Hash)
    # Get hashvalue of the tools and legal folder
    $toolsDir = ($dir.FullName + '\tools')
    if (Test-Path $toolsDir) {
      $toolsObjects = Get-ChildItem -Path $toolsDir -File -Recurse |
      Foreach-Object {
        $hashString = $hashString + ([string](Get-FileHash $_.FullName).Hash)
      }
      # add file and folder names to check for name changes
      $toolsObjects = Get-ChildItem -Path $toolsDir -Recurse |
      Foreach-Object {
        $hashString = $hashString + $_.Name
      }
    }

    $legalDir = ($dir.FullName + '\legal')
    if (Test-Path $legalDir) {
      $legalObjects = Get-ChildItem -Path $legalDir -File -Recurse |
      Foreach-Object {
        $hashString = $hashString + ([string](Get-FileHash $_.FullName).Hash)
      }
      # add file and folder names to check for name changes
      $toolsObjects = Get-ChildItem -Path $toolsDir -Recurse |
      Foreach-Object {
        $hashString = $hashString + $_.Name
      }
    }
    $removed = Remove-Item -Path $dir.FullName -Recurse -Force
    $removed = Remove-Item -Path $tmpZipPath -Recurse -Force
    return $hashString
  }
  catch {
    Write-Error -Exception $_.Exception
    Write-Log $_.Exception -Severity 3
  }
}
