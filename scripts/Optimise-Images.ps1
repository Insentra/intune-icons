<#
    .SYNOPSIS
        Optimise icons
#>

# Variables
$bin = Join-Path -Path $projectRoot -ChildPath "bin"
$pngout = Join-Path -Path $bin -ChildPath "pngout.exe"
$icons = Join-Path -Path $projectRoot -ChildPath "icons"
$scripts = Join-Path -Path $projectRoot -ChildPath "scripts"
$imageHashes = Join-Path -Path $scripts -ChildPath "ImageHashes.json"

# Dot source Invoke-Process.ps1. Prevent 'RemoteException' error when running specific git commands
. $projectRoot\ci\Invoke-Process.ps1

#region Optimise images
# Read in the existing hashes file
If (Test-Path -Path $imageHashes) {
    try {
        $pngHashes = Get-Content -Path $imageHashes -Verbose | ConvertFrom-Json
    }
    catch {
        Throw $_
        Break
    }
}

# Get all images in the icons folder
$images = Get-ChildItem -Path $icons -Recurse -Include *.*

# Optimse each file if the hash does not match
Push-Location -Path $icons
$cleanUp = @()
ForEach ($image in $images) {
    $hash = Get-FileHash -Path $image.FullName -Verbose
    If ($pngHashes.($image.Name) -ne $hash.Hash) {
        $result = Invoke-Process -FilePath $pngout -ArgumentList "$($image.FullName) /y /force" -Verbose
        If ($result -like "*Out:*") {
            $result
            If ([IO.Path]::GetExtension($image.Name) -notmatch ".png" ) {
                $cleanUp += $image.FullName
            }
        }
    }
    Else {
        Write-Host "Hash matches. Skip optimisation: $($image.Name)"
    }
}

# Remove files that aren't .png that have been optimised
ForEach ($file in $cleanUp) { Remove-Item -Path $file -Force -Verbose }
Pop-Location

# Read the hashes from all PNG files and output to file for next run
$pngImages = Get-ChildItem -Path $icons -Recurse -Include "*.png"
$pngHashes = @{}
ForEach ($png in $pngImages) {
    $hash = Get-FileHash -Path $png.FullName
    $pngHashes.Add((Split-Path -Path $hash.Path -Leaf), $hash.Hash)
}
$pngHashes | ConvertTo-Json | Out-File -FilePath $imageHashes -Force -Verbose
#endregion
