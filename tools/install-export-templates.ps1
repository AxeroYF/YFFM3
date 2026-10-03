$ErrorActionPreference = 'Stop'
$archivePath = Join-Path $PSScriptRoot 'downloads/Godot_v4.7.2-stable_export_templates.tpz'
$expectedHash = 'F298490B8D44D934BE425A5A65A51BF15F422428B229A06A6E11D9FFEA248011'
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'Export template archive SHA256 mismatch.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $versionEntry = $archive.GetEntry('templates/version.txt')
    if ($null -eq $versionEntry) { throw 'Missing template version.' }
    $reader = [System.IO.StreamReader]::new($versionEntry.Open())
    try { $templateVersion = $reader.ReadToEnd().Trim() } finally { $reader.Dispose() }
    if ($templateVersion -ne '4.7.2.stable') { throw "Unexpected template version: $templateVersion" }
    $destination = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "godot/editor_data/export_templates/$templateVersion"))
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    $destinationPrefix = $destination + [System.IO.Path]::DirectorySeparatorChar
    $fileCount = 0
    foreach ($entry in $archive.Entries) {
        if (-not $entry.FullName.StartsWith('templates/')) { continue }
        $relativePath = $entry.FullName.Substring('templates/'.Length)
        if (-not $relativePath -or $entry.FullName.EndsWith('/')) { continue }
        $target = [System.IO.Path]::GetFullPath((Join-Path $destination $relativePath))
        if (-not $target.StartsWith($destinationPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Archive entry escapes installation directory: $($entry.FullName)"
        }
        New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($target)) | Out-Null
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        $fileCount++
    }
    [PSCustomObject]@{ Version = $templateVersion; Files = $fileCount; Destination = $destination } | ConvertTo-Json
} finally {
    $archive.Dispose()
}
