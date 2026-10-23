# Corrida de compras pelo gateway (capítulo 20): N compradores ao mesmo tempo,
# disputando um lote pequeno, com várias cópias da ticket-api atrás do gateway.
param(
  [string]$Gw = 'http://127.0.0.1:9000',
  [string]$AdminPassword,
  [int]$Buyers = 30,
  [int]$Tickets = 10
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$http = New-Object System.Net.Http.HttpClient
$http.Timeout = [TimeSpan]::FromSeconds(30)

function Send([string]$Method, [string]$Path, [string]$Body = '', [string]$Token = '') {
  $req = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($Method)), "$Gw$Path")
  if ($Token) { $req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $Token) }
  if ($Body) { $req.Content = New-Object System.Net.Http.StringContent($Body, [Text.Encoding]::UTF8, 'application/json') }
  $http.SendAsync($req)
}
function Call([string]$Method, [string]$Path, [string]$Body = '', [string]$Token = '') {
  $r = (Send $Method $Path $Body $Token).Result
  [pscustomobject]@{ Status = [int]$r.StatusCode; Body = $r.Content.ReadAsStringAsync().Result }
}

$A = ((Call POST '/auth/token' ("{""email"":""admin@eventos.local"",""password"":""$AdminPassword""}")).Body | ConvertFrom-Json).accessToken
$year = (Get-Date).Year + 1
$venueId = ((Call POST '/venues' '{"name":"Arena do Cluster","address":"Rua dos Pods, 3","city":"Belo Horizonte","state":"MG","capacity":500}' $A).Body | ConvertFrom-Json).id
$eventId = ((Call POST '/events' ("{""name"":""Show das três réplicas"",""categoryId"":1,""venueId"":$venueId,""startAt"":""$year-12-12T20:00:00""}") $A).Body | ConvertFrom-Json).id
$batchId = ((Call POST "/events/$eventId/batches" ("{""name"":""Lote relâmpago"",""price"":150,""quantity"":$Tickets,""salesStart"":""2020-01-01T00:00:00"",""salesEnd"":""$year-12-01T00:00:00""}") $A).Body | ConvertFrom-Json).id
Call POST "/events/$eventId/publish" '' $A | Out-Null

$d = 1..9 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 }
$s = 0; for ($i = 0; $i -lt 9; $i++) { $s += $d[$i] * (10 - $i) }; $v1 = (($s * 10) % 11) % 10; $d += $v1
$s = 0; for ($i = 0; $i -lt 10; $i++) { $s += $d[$i] * (11 - $i) }; $v2 = (($s * 10) % 11) % 10; $d += $v2
$cpf = -join $d
$email = "cluster." + [guid]::NewGuid().ToString().Substring(0, 8) + "@exemplo.com"
Call POST '/customers' ("{""cpf"":""$cpf"",""name"":""Compradora do Cluster"",""email"":""$email"",""password"":""senha-do-cluster""}") | Out-Null
$C = ((Call POST '/auth/token' ("{""email"":""$email"",""password"":""senha-do-cluster""}")).Body | ConvertFrom-Json).accessToken
"lote $batchId com $Tickets ingressos; $Buyers compradores ao mesmo tempo"

$sw = [Diagnostics.Stopwatch]::StartNew()
$tasks = @()
for ($i = 0; $i -lt $Buyers; $i++) { $tasks += Send POST '/reservations' ("{""batchId"":$batchId,""quantity"":1}") $C }
[Threading.Tasks.Task]::WaitAll($tasks)
$sw.Stop()
$codes = $tasks | ForEach-Object { [int]$_.Result.StatusCode }
$codes | Group-Object | Sort-Object Name | ForEach-Object { "   status $($_.Name): $($_.Count)" }
"   tempo total: $($sw.ElapsedMilliseconds) ms"
foreach ($t in $tasks) {
  $sc = [int]$t.Result.StatusCode
  if ($sc -ne 201 -and $sc -ne 409) { "   resposta $($sc): $($t.Result.Content.ReadAsStringAsync().Result)" }
}
$inv = (Call GET "/inventory/batches/$batchId" '' $A).Body
"   estoque depois da corrida: $inv"
