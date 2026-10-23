# Consultas ao Prometheus pela API HTTP dele (capítulo 21).
param([string]$Url = 'http://127.0.0.1:19090')
$queries = @(
  'up',
  'sum by (service, status) (http_requests_total)',
  'sum(tickets_sold_total)',
  'histogram_quantile(0.95, sum by (le, service) (rate(http_request_duration_seconds_bucket[2m])))',
  'sum by (service) (process_resident_memory_bytes) / 1024 / 1024'
)
foreach ($q in $queries) {
  "-- $q"
  $r = Invoke-RestMethod -Uri "$Url/api/v1/query" -Method Get -Body @{ query = $q }
  foreach ($item in $r.data.result) {
    $labels = ($item.metric.PSObject.Properties | Where-Object { $_.Name -ne '__name__' -and $_.Name -ne 'job' -and $_.Name -ne 'instance' } | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' '
    $v = [double]::Parse($item.value[1], [Globalization.CultureInfo]::InvariantCulture)
    "   {0,-55} {1}" -f $labels, [math]::Round($v, 4)
  }
}
