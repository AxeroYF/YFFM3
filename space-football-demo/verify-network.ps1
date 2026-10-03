param([int]$Port = 28769, [int]$Delay = 100, [int]$LossEvery = 5, [switch]$Graphical, [int]$Rounds = 2, [switch]$PlayerHost, [string]$Executable = "", [switch]$AlternateRoster, [switch]$Rules, [int]$LoadDelay = 0, [switch]$Mechanics, [switch]$Ice)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
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
  if($Executable){ $arguments = @($arguments | Where-Object {$_ -ne "--path" -and $_ -ne $gameRoot}) }
  if($role -eq 'server') { $arguments += '--server'; if($PlayerHost){$arguments += '--listen-host-test'} }
  elseif($role -eq 'client-b' -and $Graphical) { $arguments = @($arguments | Where-Object {$_ -ne '--headless'}); $arguments += @('--client-test','--connect=127.0.0.1') }
  else { $arguments += @('--bot','--connect=127.0.0.1') }
  if($role -eq 'client-b') { $arguments += @(('--delay='+$Delay),('--loss-every='+$LossEvery)) }
  if($role -eq 'client-b' -and $LoadDelay -gt 0) { $arguments += ('--load-delay-ms='+$LoadDelay) }
  if($role -eq 'client-b' -and $AlternateRoster) { $arguments += '--test-alternate-roster' }
  if($Rules){ $arguments += '--rules-test' }
  if($Ice){ $arguments += '--ice-mode' }
  if($Mechanics){ $arguments += '--mechanics-test' }
  $processes += Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru
  if($role -eq 'server') { Start-Sleep -Milliseconds 750 }
 }
 foreach($process in $processes) {
  if(-not $process.WaitForExit(48000)) { throw 'Network test timed out' }
 }
 $finals = @()
 foreach($role in $roles) {
  $log = Get-Content (Join-Path $gameRoot ('artifacts/network-'+$role+'.log')) -Raw
  if($log -match 'ERROR|failed' -or $log -notmatch 'NETWORK_TEST_PASS') { throw ($role+': '+$log) }
  if($role -eq 'client-b' -and $AlternateRoster -and $log -notmatch 'NETWORK_ROSTER_VERIFIED.*legend-mbappe') { throw 'Alternate roster not acknowledged by authority' }
  if($role -eq 'client-b' -and $LoadDelay -gt 0 -and -not $Graphical -and ([regex]::Matches($log,'NETWORK_LOADING_WAIT_PASS frame=0 elapsed=0.0')).Count -ne $Rounds) { throw 'Loading readiness barrier did not hold the match at frame zero' }
  $matches = [regex]::Matches($log,'NETWORK_FINAL score=(.+) frame=(\d+)')
  if($matches.Count -ne $Rounds) { throw ('Missing final snapshot: '+$role) }
  $finals += ($matches | ForEach-Object {$_.Value}) -join "|"
  Write-Output (($log -split "`n" | Where-Object {$_ -match 'NETWORK_TEST_PASS|NETWORK_FINAL'}) -join "`n")
 }
 if(($finals | Select-Object -Unique).Count -ne 1) { throw 'Final score or frame diverged between server and clients' }
 if(($processes | Where-Object {$_.ExitCode -ne 0}).Count -ne 0) { throw 'Process failed' }
 $topology = if($PlayerHost){"player host + client"}else{"dedicated server + 2 clients"}
 Write-Output ("NETWORK_INTEGRATION_PASS: "+$topology+"; client B movement uplink delay="+$Delay+'ms, drops=1/'+$LossEvery)
} finally {
 foreach($process in $processes) { if(-not $process.HasExited){ Stop-Process -Id $process.Id } }
 $env:APPDATA = $previousAppData
}




