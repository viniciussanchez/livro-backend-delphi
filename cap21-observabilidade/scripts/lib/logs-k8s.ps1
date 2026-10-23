# Junta os logs JSON de todos os Pods da plataforma (capítulo 21).
#   -TraceId x  -> mostra só as linhas daquela requisição, em ordem de tempo
#   (sem)       -> conta linhas e confere se todas são JSON válido
param([string]$TraceId = '')
$apps = 'api-gateway', 'event-api', 'customer-api', 'ticket-api'
$lines = foreach ($app in $apps) { kubectl -n eventos logs -l "app.kubernetes.io/name=$app" --tail=-1 --max-log-requests=10 2>$null }
$parsed = @(); $bad = 0
foreach ($l in $lines) {
  if (-not $l.Trim()) { continue }
  try { $parsed += ($l | ConvertFrom-Json) } catch { $bad++ }
}
if ($TraceId) {
  $parsed | Where-Object { $_.requestId -eq $TraceId } | Sort-Object time | ForEach-Object {
    $extra = ''
    if ($_.route) { $extra = "$($_.method) $($_.path) -> $($_.status) em $($_.durationMs) ms" } else { $extra = $_.msg }
    "{0}  {1,-13} {2,-30} {3}" -f $_.time.ToString().Substring(11, 12), $_.service, $_.pod, $extra
  }
} else {
  "linhas de log: $($parsed.Count + $bad), JSON válido: $($parsed.Count), inválidas: $bad"
  $parsed | Group-Object service | Sort-Object Name | ForEach-Object { "   $($_.Name): $($_.Count) linhas" }
  "exemplo de linha:"
  ($lines | Where-Object { $_ -match '"msg":"requisição"' -and $_ -match 'reservations' } | Select-Object -First 1)
}
