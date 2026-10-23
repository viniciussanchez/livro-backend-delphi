# Espera um Deployment ter N réplicas prontas e diz quanto tempo levou.
param([string]$Deploy, [int]$Count, [int]$TimeoutSec = 120)
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  $ready = kubectl get deploy $Deploy -n eventos -o jsonpath='{.status.readyReplicas}' 2>$null
  if ([int]("0$ready") -ge $Count) { "$Deploy com $Count prontas em $([int]$sw.Elapsed.TotalMilliseconds) ms"; exit 0 }
  Start-Sleep -Milliseconds 250
}
"$Deploy nao chegou a $Count prontas em $TimeoutSec s"
exit 1
