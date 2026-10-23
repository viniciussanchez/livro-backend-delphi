# Mostra o /metrics sem as dezenas de linhas de faixas do histograma.
param([string]$Path)
Get-Content $Path -Encoding UTF8 | Where-Object {
  ($_ -notmatch '_bucket') -or ($_ -match 'route="/reservations"' -and $_ -match 'le="(0.1|0.5|1|2.5|\+Inf)"')
}
