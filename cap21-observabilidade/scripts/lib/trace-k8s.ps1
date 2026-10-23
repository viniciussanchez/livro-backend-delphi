# Uma compra com X-Request-Id escolhido por nós, para segui-la nos logs (capítulo 21).
param([string]$Gw = 'http://127.0.0.1:9000', [string]$AdminPassword, [string]$TraceId = 'livro-cap21-compra')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$http = New-Object System.Net.Http.HttpClient
function Call([string]$Method, [string]$Path, [string]$Body = '', [string]$Token = '', [string]$Id = '') {
  $req = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($Method)), "$Gw$Path")
  if ($Token) { $req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $Token) }
  if ($Id) { [void]$req.Headers.TryAddWithoutValidation('X-Request-Id', $Id) }
  if ($Body) { $req.Content = New-Object System.Net.Http.StringContent($Body, [Text.Encoding]::UTF8, 'application/json') }
  $r = $http.SendAsync($req).Result
  [pscustomobject]@{ Status = [int]$r.StatusCode; Body = $r.Content.ReadAsStringAsync().Result; Id = ($r.Headers.GetValues('X-Request-Id') -join '') }
}
$A = ((Call POST '/auth/token' ("{""email"":""admin@eventos.local"",""password"":""$AdminPassword""}")).Body | ConvertFrom-Json).accessToken
$year = (Get-Date).Year + 1
$venueId = ((Call POST '/venues' '{"name":"Teatro dos Logs","address":"Rua do Rastro, 21","city":"Curitiba","state":"PR","capacity":300}' $A).Body | ConvertFrom-Json).id
$eventId = ((Call POST '/events' ("{""name"":""Noite da Observabilidade"",""categoryId"":3,""venueId"":$venueId,""startAt"":""$year-10-21T20:00:00""}") $A).Body | ConvertFrom-Json).id
$batchId = ((Call POST "/events/$eventId/batches" ("{""name"":""Plateia"",""price"":90,""quantity"":100,""salesStart"":""2020-01-01T00:00:00"",""salesEnd"":""$year-10-20T00:00:00""}") $A).Body | ConvertFrom-Json).id
Call POST "/events/$eventId/publish" '' $A | Out-Null
$d = 1..9 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 }
$s = 0; for ($i = 0; $i -lt 9; $i++) { $s += $d[$i] * (10 - $i) }; $v1 = (($s * 10) % 11) % 10; $d += $v1
$s = 0; for ($i = 0; $i -lt 10; $i++) { $s += $d[$i] * (11 - $i) }; $v2 = (($s * 10) % 11) % 10; $d += $v2
$email = "logs." + [guid]::NewGuid().ToString().Substring(0, 8) + "@exemplo.com"
Call POST '/customers' ("{""cpf"":""$(-join $d)"",""name"":""Leitora de Logs"",""email"":""$email"",""password"":""senha-dos-logs""}") | Out-Null
$C = ((Call POST '/auth/token' ("{""email"":""$email"",""password"":""senha-dos-logs""}")).Body | ConvertFrom-Json).accessToken
$r = Call POST '/reservations' ("{""batchId"":$batchId,""quantity"":2}") $C $TraceId
"compra: status $($r.Status), X-Request-Id da resposta: $($r.Id)"
# Algumas respostas de erro, para as métricas terem o que mostrar.
1..3 | ForEach-Object { Call GET '/nao-existe' | Out-Null }
1..2 | ForEach-Object { Call GET '/reservations/1' | Out-Null }
"404 e 401 gerados"
