# Roteiro de verificação do capítulo 22: o sistema antigo da bilheteria
# sincronizado com a plataforma nova.
param(
  [string]$Part,
  [string]$Gw = 'http://127.0.0.1:9000',
  [string]$Sync = 'http://127.0.0.1:9004',
  [string]$AdminPassword = 'admin12345'
)
$ErrorActionPreference = 'Stop'
$env:PGPASSWORD = 'eventos'
$env:PGCLIENTENCODING = 'UTF8'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Net.Http
$http = New-Object System.Net.Http.HttpClient
$http.Timeout = [TimeSpan]::FromSeconds(30)

function Call([string]$Method, [string]$Url, [string]$Body = '', [string]$Token = '') {
  $req = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($Method)), $Url)
  if ($Token) { $req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $Token) }
  if ($Body) { $req.Content = New-Object System.Net.Http.StringContent($Body, [Text.Encoding]::UTF8, 'application/json') }
  $r = $http.SendAsync($req).Result
  [pscustomobject]@{ Status = [int]$r.StatusCode; Body = $r.Content.ReadAsStringAsync().Result }
}
function Sql([string]$Db, [string]$Command) {
  $out = & psql -h 127.0.0.1 -U eventos -d $Db -tAq -c $Command 2>&1
  ($out | Out-String).Trim()
}
# No PowerShell 5, ConvertFrom-Json devolve um array JSON como um objeto só.
# E uma função devolve um array de um item só como o próprio item; a
# vírgula na frente evita isso.
function JsonList([string]$Text) { , @(($Text | ConvertFrom-Json) | ForEach-Object { $_ }) }
function Status($A) { (Call GET "$Sync/sync/status" '' $A).Body | ConvertFrom-Json }
function WaitDrain($A, [int]$Seconds = 300) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  do { Start-Sleep -Milliseconds 500; $s = Status $A } while ($s.pending -gt 0 -and $sw.Elapsed.TotalSeconds -lt $Seconds)
  [pscustomobject]@{ Status = $s; Ms = $sw.ElapsedMilliseconds }
}
function NewCpf {
  $d = 1..9 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 }
  $s = 0; for ($i = 0; $i -lt 9; $i++) { $s += $d[$i] * (10 - $i) }; $d += (($s * 10) % 11) % 10
  $s = 0; for ($i = 0; $i -lt 10; $i++) { $s += $d[$i] * (11 - $i) }; $d += (($s * 10) % 11) % 10
  -join $d
}
# Espera o participante com este CPF aparecer na customer-api (pelo gateway).
function WaitCustomer($A, [string]$Cpf, [int]$Seconds = 30) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
    $r = Call GET "$Gw/customers?cpf=$Cpf" '' $A
    $list = JsonList $r.Body
    if ($list.Count -gt 0) { return [pscustomobject]@{ Customer = $list[0]; Ms = $sw.ElapsedMilliseconds } }
    Start-Sleep -Milliseconds 100
  }
  [pscustomobject]@{ Customer = $null; Ms = $sw.ElapsedMilliseconds }
}

# O token vem da customer-api. Na parte em que ela está fora do ar, usamos
# o último token obtido (ele vale por bastante tempo).
$cache = "$env:TEMP\cap22-token.txt"
$login = Call POST "$Gw/auth/token" ("{""email"":""admin@eventos.local"",""password"":""$AdminPassword""}")
if ($login.Status -eq 200) { $A = ($login.Body | ConvertFrom-Json).accessToken; Set-Content -Path $cache -Value $A }
else { $A = (Get-Content $cache).Trim() }

switch ($Part) {
  'fullload' {
    "-- antes: " + ((Status $A) | ConvertTo-Json -Compress)
    $r = Call POST "$Sync/sync/full-load" '' $A
    "-- POST /sync/full-load: status $($r.Status) $($r.Body)"
    $w = WaitDrain $A
    "-- fila vazia em $($w.Ms) ms: " + ($w.Status | ConvertTo-Json -Compress)
    $rej = JsonList (Call GET "$Sync/sync/rejected?limit=500" '' $A).Body
    "-- clientes rejeitados: $($rej.Count), agrupados pelo motivo:"
    $rej | Group-Object { $_.error } | Sort-Object Count -Descending | ForEach-Object { "   {0,4}  {1}" -f $_.Count, $_.Name }
    "-- três exemplos:"
    $rej | Select-Object -First 3 | ForEach-Object { "   " + ($_ | ConvertTo-Json -Compress) }
  }
  'reconcile' {
    "-- sistema antigo"
    "   clientes no CLIENTE:                 " + (Sql bilheteria "select count(*) from CLIENTE")
    "   inativos:                            " + (Sql bilheteria "select count(*) from CLIENTE where SITUACAO = 'I'")
    "   com item feito na fila:              " + (Sql bilheteria "select count(distinct CHAVE) from SYNC_FILA where STATUS = 'O' and (ERRO is null or ERRO = '')")
    "   rejeitados (aguardando correção):    " + (Sql bilheteria "select count(distinct CHAVE) from SYNC_FILA where STATUS = 'R'")
    "-- plataforma nova"
    "   participantes com legacy_code:       " + (Sql customer_db "select count(*) from customer where legacy_code is not null")
    "   sem e-mail:                          " + (Sql customer_db "select count(*) from customer where legacy_code is not null and email is null")
    "   sem telefone:                        " + (Sql customer_db "select count(*) from customer where legacy_code is not null and phone is null")
    "-- conferência campo a campo de 3 clientes"
    foreach ($cod in 2, 3, 6) {
      "   CLIENTE " + (Sql bilheteria "select COD_CLI || ' | ' || NOME || ' | ' || coalesce(CPF,'') || ' | ' || coalesce(FONE,'') || ' | ' || coalesce(trim(EMAIL),'') || ' | ' || coalesce(DT_NASC,'') from CLIENTE where COD_CLI = $cod")
      "   legacy   " + (Sql customer_db "select legacy_code || ' | ' || name || ' | ' || cpf || ' | ' || coalesce(phone,'') || ' | ' || coalesce(email,'') || ' | ' || coalesce(birth_date::text,'') from customer where legacy_code = $cod")
    }
  }
  'counter' {
    $cpf = NewCpf
    $cod = Sql bilheteria "insert into CLIENTE (NOME, CPF, FONE, DT_NASC) values (U&'PEDRO DE ALC\00C2NTARA', '$cpf', '(31) 98888-7777', '07/09/1990') returning COD_CLI"
    "-- balcão: cliente $cod incluído no sistema antigo (CPF $cpf)"
    $w = WaitCustomer $A $cpf
    "   apareceu na plataforma nova em $($w.Ms) ms: " + ($w.Customer | ConvertTo-Json -Compress)
    $id = $w.Customer.id
    Sql bilheteria "update CLIENTE set FONE = '(31) 3222-1111' where COD_CLI = $cod" | Out-Null
    "-- balcão: telefone do cliente $cod alterado no sistema antigo"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    do { Start-Sleep -Milliseconds 100; $c = (Call GET "$Gw/customers/$id" '' $A).Body | ConvertFrom-Json } while ($c.phone -ne '3132221111' -and $sw.Elapsed.TotalSeconds -lt 30)
    "   alteração chegou em $($sw.ElapsedMilliseconds) ms: phone=$($c.phone)"
  }
  'fix' {
    "-- cliente 7 antes: " + (Sql bilheteria "select COD_CLI || ' | ' || NOME || ' | ' || CPF from CLIENTE where COD_CLI = 7")
    "   motivo: " + (Sql bilheteria "select ERRO from SYNC_FILA where CHAVE = 7 and STATUS = 'R' order by ID desc limit 1")
    "   rejeitados agora: $((Status $A).rejectedCustomers)"
    $cpf = NewCpf
    Sql bilheteria "update CLIENTE set CPF = '$cpf' where COD_CLI = 7" | Out-Null
    "-- operador corrigiu o CPF no sistema antigo: $cpf"
    $w = WaitCustomer $A $cpf
    "   chegou em $($w.Ms) ms: " + ($w.Customer | ConvertTo-Json -Compress)
    "   rejeitados agora: $((Status $A).rejectedCustomers)"
  }
  'outage-insert' {
    $cpf = NewCpf
    $cod = Sql bilheteria "insert into CLIENTE (NOME, CPF) values (U&'LUIZA DO APAG\00C3O', '$cpf') returning COD_CLI"
    "-- customer-api fora do ar; cliente $cod incluído no balcão (CPF $cpf)"
    Start-Sleep -Seconds 6
    "   fila: " + ((Status $A) | ConvertTo-Json -Compress)
    "   item: " + (Sql bilheteria "select 'tentativas=' || TENTATIVAS || ' | proxima em ' || round(extract(epoch from PROXIMA_TENTATIVA - localtimestamp)) || ' s | ' || ERRO from SYNC_FILA where CHAVE = $cod order by ID desc limit 1")
    Set-Content -Path "$env:TEMP\cap22-cpf.txt" -Value $cpf
  }
  'outage-check' {
    $cpf = (Get-Content "$env:TEMP\cap22-cpf.txt").Trim()
    $w = WaitCustomer $A $cpf 90
    "-- customer-api de volta; o cliente chegou $($w.Ms) ms depois de ela voltar: " + ($w.Customer | ConvertTo-Json -Compress)
    "   fila: " + ((Status $A) | ConvertTo-Json -Compress)
  }
  'again' {
    $before = Sql customer_db "select count(*) from customer"
    $r = Call POST "$Sync/sync/full-load" '' $A
    "-- carga completa de novo, agora com duas cópias do legacy-sync: $($r.Body)"
    $w = WaitDrain $A
    $after = Sql customer_db "select count(*) from customer"
    "   fila vazia em $($w.Ms) ms; participantes antes: $before, depois: $after"
  }
  'purchase' {
    $cpf = Sql bilheteria "select regexp_replace(CPF, '\D', '', 'g') from CLIENTE where COD_CLI = 2"
    $id = (JsonList (Call GET "$Gw/customers?cpf=$cpf" '' $A).Body)[0].id
    $year = (Get-Date).Year + 1
    $venueId = ((Call POST "$Gw/venues" '{"name":"Teatro da Migração","address":"Rua Velha, 6","city":"Belo Horizonte","state":"MG","capacity":200}' $A).Body | ConvertFrom-Json).id
    $eventId = ((Call POST "$Gw/events" ("{""name"":""Noite do Legado"",""categoryId"":1,""venueId"":$venueId,""startAt"":""$year-06-06T20:00:00""}") $A).Body | ConvertFrom-Json).id
    $batchId = ((Call POST "$Gw/events/$eventId/batches" ("{""name"":""Plateia"",""price"":70,""quantity"":50,""salesStart"":""2020-01-01T00:00:00"",""salesEnd"":""$year-06-01T00:00:00""}") $A).Body | ConvertFrom-Json).id
    Call POST "$Gw/events/$eventId/publish" '' $A | Out-Null
    $r = Call POST "$Gw/reservations" ("{""batchId"":$batchId,""quantity"":2,""customerId"":$id}") $A
    "-- compra para o cliente 2 do sistema antigo (participante $id na plataforma nova): status $($r.Status)"
    "   " + $r.Body
  }
  'metrics' {
    $m = (Call GET "$Sync/metrics").Body -split "`n" | Where-Object { $_ -match '^legacy_sync' -and $_ -notmatch '_bucket' }
    $m
    (Call GET "$Sync/metrics").Body -split "`n" | Where-Object { $_ -match '^legacy_sync_delay_seconds_bucket' }
  }
}
