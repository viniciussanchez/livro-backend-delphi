# Um "servico" que aceita conexoes e nunca responde. Usado no capitulo 16
# para ver o gateway desistir de esperar (504).
param([int]$Port = 9099, [int]$Seconds = 40)
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
$clients = @()
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
  if ($listener.Pending()) { $clients += $listener.AcceptTcpClient() } else { Start-Sleep -Milliseconds 100 }
}
$clients | ForEach-Object { $_.Close() }
$listener.Stop()
