# Gera um .env com segredos aleatórios para os testes do capítulo 18.
param([string]$Path)
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
function Secret([int]$Bytes) {
  $b = New-Object byte[] $Bytes
  $rng.GetBytes($b)
  [Convert]::ToBase64String($b)
}
$lines = @(
  ('DB_PASSWORD=' + (Secret 24)),
  ('JWT_SECRET=' + (Secret 48)),
  'ADMIN_EMAIL=admin@eventos.local',
  ('ADMIN_PASSWORD=' + (Secret 18)),
  'CORS_ORIGINS=http://localhost:5173'
)
[IO.File]::WriteAllLines($Path, $lines)
