# Ferramentas de teste do capítulo 13.
#   -Action login  -Email x -Password y      -> imprime o accessToken
#   -Action decode -Token t                  -> imprime o conteúdo (payload) do token
#   -Action forge  -Kind expired|none|wrongkey|tampered [-Token t] -> imprime um token forjado
param(
  [string]$Action,
  [string]$Email,
  [string]$Password,
  [string]$Token,
  [string]$Kind,
  [string]$Url = 'http://127.0.0.1:9002',
  [string]$Secret = 'chave-de-desenvolvimento-troque-em-producao'
)

function B64Url([byte[]]$bytes) {
  [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}
function FromB64Url([string]$text) {
  $t = $text.Replace('-', '+').Replace('_', '/')
  while ($t.Length % 4) { $t += '=' }
  [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($t))
}
function Sign([string]$header, [string]$payload, [string]$key) {
  $signingInput = (B64Url ([Text.Encoding]::UTF8.GetBytes($header))) + '.' + (B64Url ([Text.Encoding]::UTF8.GetBytes($payload)))
  $hmac = New-Object System.Security.Cryptography.HMACSHA256
  $hmac.Key = [Text.Encoding]::UTF8.GetBytes($key)
  $signingInput + '.' + (B64Url $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($signingInput)))
}

$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
switch ($Action) {
  'login' {
    $body = @{ email = $Email; password = $Password } | ConvertTo-Json
    try {
      (Invoke-RestMethod -Method Post -Uri "$Url/auth/token" -ContentType 'application/json' -Body $body).accessToken
    } catch { 'LOGIN-FALHOU' }
  }
  'decode' { FromB64Url ($Token.Split('.')[1]) }
  'forge' {
    $header = '{"alg":"HS256","typ":"JWT"}'
    switch ($Kind) {
      'expired'  { Sign $header ('{"sub":"1","role":"admin","iat":' + ($now - 7200) + ',"exp":' + ($now - 3600) + '}') $Secret }
      'wrongkey' { Sign $header ('{"sub":"1","role":"admin","exp":' + ($now + 3600) + '}') 'outra-chave-qualquer' }
      'none' {
        (B64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"none","typ":"JWT"}'))) + '.' +
        (B64Url ([Text.Encoding]::UTF8.GetBytes('{"sub":"1","role":"admin","exp":' + ($now + 3600) + '}'))) + '.'
      }
      'tampered' {
        # Troca o papel no conteúdo de um token verdadeiro e mantém a assinatura original.
        $parts = $Token.Split('.')
        $payload = (FromB64Url $parts[1]).Replace('"customer"', '"admin"')
        $parts[0] + '.' + (B64Url ([Text.Encoding]::UTF8.GetBytes($payload))) + '.' + $parts[2]
      }
    }
  }
}
