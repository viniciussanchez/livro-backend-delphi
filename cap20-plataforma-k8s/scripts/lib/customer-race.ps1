# Sobe N cópias da customer-api ao mesmo tempo, num banco sem administrador,
# e conta quantas criaram o administrador e quantas reiniciaram (capítulo 20).
param([string]$Image, [int]$Replicas = 4, [int]$Rounds = 3)
$ns = 'eventos'
for ($r = 1; $r -le $Rounds; $r++) {
  kubectl -n $ns scale deploy/customer-api --replicas=0 | Out-Null
  kubectl -n $ns wait --for=delete pod -l app.kubernetes.io/name=customer-api --timeout=90s 2>$null | Out-Null
  kubectl -n $ns exec postgres-0 -- psql -U eventos -d customer_db -q -c "delete from app_user where role = 'admin'" | Out-Null
  kubectl -n $ns set image deploy/customer-api "customer-api=$Image" | Out-Null
  kubectl -n $ns scale deploy/customer-api --replicas=$Replicas | Out-Null
  kubectl -n $ns rollout status deploy/customer-api --timeout=180s | Out-Null
  Start-Sleep -Seconds 2
  $pods = kubectl -n $ns get pods -l app.kubernetes.io/name=customer-api -o jsonpath='{.items[*].metadata.name}'
  $restarts = 0; $created = 0; $errors = 0
  foreach ($p in $pods.Split(' ')) {
    $restarts += [int](kubectl -n $ns get pod $p -o jsonpath='{.status.containerStatuses[0].restartCount}')
    $log = (kubectl -n $ns logs $p 2>$null) -join "`n"
    if ($log -match 'Administrador inicial criado') { $created++ }
    $prev = (kubectl -n $ns logs $p --previous 2>$null) -join "`n"
    if ($prev -match 'Administrador inicial criado') { $created++ }
    if ($prev -match 'Falha ao preparar') { $errors++; $script:lastError = ($prev -split "`n" | Where-Object { $_ -match 'Falha' } | Select-Object -First 1) }
  }
  $admins = (kubectl -n $ns exec postgres-0 -- psql -U eventos -d customer_db -t -A -c "select count(*) from app_user where role = 'admin'").Trim()
  "rodada ${r} ($Image): $Replicas cópias, administradores criados nos logs: $created, reinícios: $restarts, falhas na subida: $errors, administradores no banco: $admins"
}
if ($script:lastError) { "   exemplo de falha: $($script:lastError)" }
