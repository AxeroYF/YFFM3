param(
 [ValidateSet('Fast','Full','Visual')][string]$Suite='Fast',
 [string]$Executable='',
 [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$LogPrefix='refactor',
 [switch]$AllowSystemCertificateWarning
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
& node (Join-Path $projectRoot 'tools/network-build.mjs') --check
if($LASTEXITCODE -ne 0){throw 'Network build manifest is stale.'}
if(-not $Executable){$Executable=Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'}
$engine=(Resolve-Path -LiteralPath $Executable).Path
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'verification-suites.json') -Raw | ConvertFrom-Json
$entries=$manifest.$Suite
$artifactRoot=Join-Path $PSScriptRoot 'artifacts'
New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
$previousAppData=$env:APPDATA
$results=@()
try {
 $env:APPDATA=Join-Path $projectRoot 'tools/godot/user_data'
 foreach($entry in $entries){
  $log=Join-Path $artifactRoot ($LogPrefix+'-'+$entry.name+'.log')
  $arguments=@('--path',('"{0}"' -f $PSScriptRoot),'--log-file',('"{0}"' -f $log))
  if($entry.script){$arguments=@('--headless')+$arguments+@('--script',$entry.script)}
  else {$arguments=@('--fullscreen','--resolution','2560x1440')+$arguments+@('--',$entry.flag)}
  $started=Get-Date
  $process=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru
  if(-not $process.WaitForExit(180000)){
   Stop-Process -Id $process.Id -Force
   throw ('Verification timed out: '+$entry.name)
  }
  $process.Refresh()
  $output=Get-Content -LiteralPath $log -Raw
  if($AllowSystemCertificateWarning){
   $rawOutput=$output
   $output=[regex]::Replace($output,'(?m)^ERROR: Failed to read the root certificate store\.\r?\n[ \t]+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)\r?\n','')
   if($output -ne $rawOutput){Write-Warning ($entry.name+': known Windows certificate-store warning retained in log')}
  }
  $passed=$process.ExitCode -eq 0 -and $output -match $entry.pass -and $output -notmatch 'SCRIPT ERROR|ERROR:|FAILED|failures=[1-9]'
  $results+= [pscustomobject]@{name=$entry.name;passed=$passed;exitCode=$process.ExitCode;seconds=[math]::Round(((Get-Date)-$started).TotalSeconds,2);log=$log}
  Write-Output ($entry.name+': '+$(if($passed){'PASS'}else{'FAIL'}))
  if(-not $passed){throw ('Verification failed; see '+$log)}
 }
} finally {
 $env:APPDATA=$previousAppData
 ConvertTo-Json -InputObject @($results) -Depth 4 | Set-Content -LiteralPath (Join-Path $artifactRoot ($LogPrefix+'-'+$Suite+'-summary.json')) -Encoding utf8
}
