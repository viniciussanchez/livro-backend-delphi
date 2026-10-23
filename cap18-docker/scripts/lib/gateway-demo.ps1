# Roteiro de verificação do capítulo 16: tudo pela porta 9000.
#   -Part main     -> cenários com todos os serviços no ar
#   -Part degraded -> health e encaminhamento com a ticket-api parada
#   -Part timeout  -> gateway apontando para um serviço que nunca responde
param(
  [string]$Part = 'main',
  [string]$Gw = 'http://127.0.0.1:9000',
  [string]$AdminPassword = 'admin12345'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $false
$http = New-Object System.Net.Http.HttpClient($handler)
$http.Timeout = [TimeSpan]::FromSeconds(30)

function Call([string]$Method, [string]$Path, [string]$Body = '', [string]$Token = '', [hashtable]$Headers = @{}, [string]$Base = $Gw) {
  $req = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($Method)), "$Base$Path")
  if ($Token) { $req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $Token) }
  foreach ($k in $Headers.Keys) { [void]$req.Headers.TryAddWithoutValidation($k, $Headers[$k]) }
  if ($Body) { $req.Content = New-Object System.Net.Http.StringContent($Body, [Text.Encoding]::UTF8, 'application/json') }
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try { $res = $http.SendAsync($req).Result }
  catch { return [pscustomobject]@{ Status = 0; Body = 'falha de rede: ' + $_.Exception.InnerException.Message; Headers = @{}; Ms = $sw.ElapsedMilliseconds } }
  if (-not $res) { return [pscustomobject]@{ Status = 0; Body = 'falha de rede: sem resposta'; Headers = @{}; Ms = $sw.ElapsedMilliseconds } }
  $text = $res.Content.ReadAsStringAsync().Result
  $sw.Stop()
  $h = @{}
  foreach ($p in $res.Headers) { $h[$p.Key] = ($p.Value -join ', ') }
  foreach ($p in $res.Content.Headers) { $h[$p.Key] = ($p.Value -join ', ') }
  [pscustomobject]@{ Status = [int]$res.StatusCode; Body = $text; Headers = $h; Ms = $sw.ElapsedMilliseconds }
}
function Show([string]$Title, $R, [string[]]$Keys = @()) {
  "-- $Title"
  "   status $($R.Status) em $($R.Ms) ms"
  foreach ($k in $Keys) { if ($R.Headers.ContainsKey($k)) { "   ${k}: $($R.Headers[$k])" } else { "   ${k}: (ausente)" } }
  if ($R.Body) { $b = $R.Body; if ($b.Length -gt 400) { $b = $b.Substring(0, 400) + '...' }; "   $b" }
}

switch ($Part) {
'main' {
  Show 'GET /health' (Call GET '/health')
  Show 'GET /categories (event-api)' (Call GET '/categories') @('X-Request-Id', 'Content-Type')
  Show 'GET /categories com X-Request-Id do cliente' (Call GET '/categories' -Headers @{ 'X-Request-Id' = 'livro-cap16-0001' }) @('X-Request-Id')
  Show 'GET /nao-existe' (Call GET '/nao-existe') @('Content-Type')
  Show 'GET /inventory (sem o resto do caminho)' (Call GET '/inventory')
  Show 'GET /reservations/1 sem token (ticket-api)' (Call GET '/reservations/1') @('WWW-Authenticate')

  $admin = (Call POST '/auth/token' ("{""email"":""admin@eventos.local"",""password"":""$AdminPassword""}")).Body | ConvertFrom-Json
  $A = $admin.accessToken
  "-- login do admin pelo gateway: token com $($A.Length) caracteres"
  $venue = (Call POST '/venues' '{"name":"Arena São João","address":"Praça da Porta, 9000","city":"Recife","state":"PE","capacity":800}' $A)
  Show 'POST /venues' $venue @('Location')
  $venueId = ($venue.Body | ConvertFrom-Json).id
  "   acentos preservados no local: $((($venue.Body | ConvertFrom-Json).name) -eq 'Arena São João')"
  $year = (Get-Date).Year + 1
  $ev = Call POST '/events' ("{""name"":""Show na porta da frente"",""categoryId"":1,""venueId"":$venueId,""startAt"":""$year-11-20T21:00:00""}") $A
  $eventId = ($ev.Body | ConvertFrom-Json).id
  $batch = Call POST "/events/$eventId/batches" ("{""name"":""Pista"",""price"":120,""quantity"":50,""salesStart"":""2020-01-01T00:00:00"",""salesEnd"":""$year-11-19T00:00:00""}") $A
  $batchId = ($batch.Body | ConvertFrom-Json).id
  Show "POST /events/$eventId/publish" (Call POST "/events/$eventId/publish" '' $A)
  Show "GET /batches/$batchId (catalogo, event-api)" (Call GET "/batches/$batchId")

  $suffix = [guid]::NewGuid().ToString().Substring(0, 8)
  $cpfDigits = -join (1..9 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 })
  # Digitos verificadores do CPF.
  $d = $cpfDigits.ToCharArray() | ForEach-Object { [int]::Parse($_) }
  $s = 0; for ($i = 0; $i -lt 9; $i++) { $s += $d[$i] * (10 - $i) }; $v1 = (($s * 10) % 11) % 10
  $d += $v1
  $s = 0; for ($i = 0; $i -lt 10; $i++) { $s += $d[$i] * (11 - $i) }; $v2 = (($s * 10) % 11) % 10
  $cpf = $cpfDigits + $v1 + $v2
  $email = "porta.$suffix@exemplo.com"
  Show 'POST /customers (cadastro pelo gateway)' (Call POST '/customers' ("{""cpf"":""$cpf"",""name"":""José da Conceição"",""email"":""$email"",""password"":""senha-da-porta""}")) @('Location')
  $C = ((Call POST '/auth/token' ("{""email"":""$email"",""password"":""senha-da-porta""}")).Body | ConvertFrom-Json).accessToken
  $res = Call POST '/reservations' ("{""batchId"":$batchId,""quantity"":2}") $C
  Show 'POST /reservations (compra pelo gateway)' $res @('Location')
  Show "GET /inventory/batches/$batchId (estoque, ticket-api)" (Call GET "/inventory/batches/$batchId" '' $A)
  Show "GET /reports/events/$eventId/sales" (Call GET "/reports/events/$eventId/sales" '' $A)

  "-- CORS"
  Show 'OPTIONS /reservations de http://localhost:5173' (Call OPTIONS '/reservations' -Headers @{ Origin = 'http://localhost:5173'; 'Access-Control-Request-Method' = 'POST'; 'Access-Control-Request-Headers' = 'authorization, content-type' }) @('Access-Control-Allow-Origin', 'Access-Control-Allow-Methods', 'Access-Control-Allow-Headers', 'Access-Control-Max-Age')
  Show 'OPTIONS /reservations de http://site-estranho.example' (Call OPTIONS '/reservations' -Headers @{ Origin = 'http://site-estranho.example'; 'Access-Control-Request-Method' = 'POST' }) @('Access-Control-Allow-Origin')
  Show 'GET /categories de http://localhost:5173' (Call GET '/categories' -Headers @{ Origin = 'http://localhost:5173' }) @('Access-Control-Allow-Origin', 'Access-Control-Expose-Headers', 'Vary')

  "-- limite de tentativas de login (o admin ja gastou 1; o cliente, 1)"
  for ($i = 1; $i -le 5; $i++) {
    $r = Call POST '/auth/token' '{"email":"admin@eventos.local","password":"chute-errado"}'
    "   tentativa errada ${i}: $($r.Status) $($r.Headers['Retry-After'])"
  }
  Show 'mais uma, agora com a senha certa' (Call POST '/auth/token' ("{""email"":""admin@eventos.local"",""password"":""$AdminPassword""}")) @('Retry-After')
  Show 'direto na customer-api, sem o gateway' (Call POST '/auth/token' ("{""email"":""admin@eventos.local"",""password"":""$AdminPassword""}") -Base 'http://127.0.0.1:9002')

  "-- custo do gateway: 300 GET /categories em sequencia"
  foreach ($base in @('http://127.0.0.1:9001', $Gw)) {
    if ((Call GET '/categories' -Base $base).Status -eq 0) { "   ${base}: porta fechada, sem medicao"; continue }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 300; $i++) { Call GET '/categories' -Base $base | Out-Null }
    $sw.Stop()
    "   ${base}: $([math]::Round($sw.Elapsed.TotalMilliseconds / 300, 2)) ms por requisicao"
  }
}
'degraded' {
  Show 'GET /health com a ticket-api parada' (Call GET '/health')
  Show 'GET /reservations/1 com a ticket-api parada' (Call GET '/reservations/1') @('Content-Type')
  Show 'GET /categories continua funcionando' (Call GET '/categories')
}
'timeout' {
  Show 'GET /tickets/ABC com um servico que nao responde' (Call GET '/tickets/ABC')
}
}
