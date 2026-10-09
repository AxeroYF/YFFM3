param([int]$Port = 28769, [int]$Delay = 100, [int]$LossEvery = 7, [int]$Jitter = 25, [int]$ReorderEvery = 11, [int]$BurstEvery = 0, [switch]$Graphical, [switch]$LatencyActions, [int]$Rounds = 2, [switch]$PlayerHost, [string]$Executable = "", [switch]$AlternateRoster, [switch]$Rules, [int]$LoadDelay = 0, [switch]$Mechanics, [switch]$Ice, [switch]$AllowSystemCertificateWarning)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
& node (Join-Path $projectRoot 'tools/network-build.mjs') --check
if($LASTEXITCODE -ne 0){throw 'Network build manifest is stale.'}
$gameRoot = $PSScriptRoot
$engine = Join-Path $projectRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
if($Executable){ $engine = (Resolve-Path -LiteralPath $Executable).Path }
$previousAppData = $env:APPDATA
$processes = @()
try {
 $env:APPDATA = Join-Path $projectRoot 'tools/godot/user_data'
 $roles = if($PlayerHost){@('server','client-b')}else{@('server','client-a','client-b')}
 foreach($role in $roles) {
  $log = Join-Path $gameRoot ('artifacts/network-' + $role + '.log')
  $arguments = @('--headless','--path',$gameRoot,'--log-file',$log,'--','--network-test',('--rounds='+$Rounds),('--port='+$Port))
  if($Graphical -and $role -eq 'client-b'){ $arguments = @('--fullscreen','--resolution','2560x1440') + $arguments }
  if($Executable){ $arguments = @($arguments | Where-Object {$_ -ne "--path" -and $_ -ne $gameRoot}) }
  if($role -eq 'server') { $arguments += '--server'; if($PlayerHost){$arguments += '--listen-host-test'} }
  elseif($role -eq 'client-b' -and $Graphical) { $arguments = @($arguments | Where-Object {$_ -ne '--headless'}); $arguments += @('--client-test','--connect=127.0.0.1') }
  else { $arguments += @('--bot','--connect=127.0.0.1') }
  $arguments += @(('--delay='+$Delay),('--jitter='+$Jitter),('--loss-every='+$LossEvery),('--reorder-every='+$ReorderEvery),('--burst-every='+$BurstEvery))
  if($role -eq 'client-b' -and $LoadDelay -gt 0) { $arguments += ('--load-delay-ms='+$LoadDelay) }
  if($role -eq 'client-b' -and $AlternateRoster) { $arguments += '--test-alternate-roster' }
  if($LatencyActions){ $arguments += "--latency-test" }
  if($Rules){ $arguments += '--rules-test' }
  if($Ice){ $arguments += '--ice-mode' }
  if($Mechanics){ $arguments += '--mechanics-test' }
  $processes += Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru
  if($role -eq 'server') { Start-Sleep -Milliseconds 750 }
 }
 foreach($process in $processes) {
  if(-not $process.WaitForExit(60000)) { throw 'Network test timed out' }
 }
 $finals = @()
 foreach($role in $roles) {
  $log = Get-Content (Join-Path $gameRoot ('artifacts/network-'+$role+'.log')) -Raw -Encoding UTF8
  $scenario = if($LatencyActions){'latency-actions'}elseif($Mechanics){'mechanics'}elseif($Rules){'rules'}elseif($Graphical){'graphical'}else{'latency'}
  $topologyTag = if($PlayerHost){'host'}else{'dedicated'}
  Copy-Item -LiteralPath (Join-Path $gameRoot ('artifacts/network-'+$role+'.log')) -Destination (Join-Path $gameRoot ('artifacts/v8-'+$scenario+'-'+$topologyTag+'-'+$role+'.log')) -Force
  $checkedLog = $log
  if($AllowSystemCertificateWarning) {
   # Only the known Windows sandbox CA-store diagnostic is allowed, never script errors.
   # Keep the original log intact. ENet itself does not use TLS certificates.
   $checkedLog = [regex]::Replace($log, '(?m)^ERROR: Failed to read the root certificate store\.\r?\n[ \t]+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)\r?\n', '')
   if($checkedLog -ne $log){ Write-Warning ($role+': known Windows certificate-store warning retained in log') }
  }
  if($checkedLog -match 'ERROR|failed|above the MTU' -or $log -notmatch 'NETWORK_TEST_PASS') { throw ($role+': '+$log) }
  $metricLines = [regex]::Matches($log,'NETWORK_METRICS (.+)')
  if($metricLines.Count -eq 0){ throw ('Missing network metrics: '+$role) }
  $metric = $metricLines[$metricLines.Count-1].Groups[1].Value | ConvertFrom-Json
  if(($metric.fault_profile -join ',') -ne (@($Delay,$Jitter,$LossEvery,$ReorderEvery,$BurstEvery) -join ',')){ throw ('Fault profile not active on '+$role) }
  if($Delay -gt 0 -and $role -ne 'server' -and ($metric.rtt_ms | Measure-Object -Maximum).Maximum -lt $Delay){ throw 'Application probe did not measure simulated delay' }
  if($role -eq 'client-b' -and $AlternateRoster -and $log -notmatch 'NETWORK_ROSTER_VERIFIED.*legend-mbappe') { throw 'Alternate roster not acknowledged by authority' }
  if($role -eq 'client-b' -and $LoadDelay -gt 0 -and -not $Graphical -and ([regex]::Matches($log,'NETWORK_LOADING_WAIT_PASS frame=0 elapsed=0.0')).Count -ne $Rounds) { throw 'Loading readiness barrier did not hold the match at frame zero' }
  $matches = [regex]::Matches($log,'NETWORK_FINAL score=(.+) frame=(\d+)')
  if($matches.Count -ne $Rounds) { throw ('Missing final snapshot: '+$role) }
  $finals += ($matches | ForEach-Object {$_.Value}) -join "|"
  Write-Output (($log -split "`n" | Where-Object {$_ -match 'NETWORK_TEST_PASS|NETWORK_FINAL|NETWORK_METRICS'}) -join "`n")
 }
 if(($finals | Select-Object -Unique).Count -ne 1) { throw 'Final score or frame diverged between server and clients' }
 if(($processes | Where-Object {$_.ExitCode -ne 0}).Count -ne 0) { throw 'Process failed' }
 $topology = if($PlayerHost){"player host + client"}else{"dedicated server + 2 clients"}
 Write-Output ("NETWORK_INTEGRATION_PASS: "+$topology+"; all peers bidirectional application delay per leg="+$Delay+'ms, drops=1/'+$LossEvery)
} finally {
 foreach($process in $processes) { if(-not $process.HasExited){ Stop-Process -Id $process.Id } }
 $env:APPDATA = $previousAppData
}




