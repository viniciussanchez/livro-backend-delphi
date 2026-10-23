# Tira do nó do cluster as imagens eventos/* com as etiquetas pedidas.
# Com imagePullPolicy: IfNotPresent, o nó guarda a primeira imagem que viu
# com cada etiqueta e não procura outra (capítulo 20). Apagando a cópia do
# nó, o próximo Pod busca de novo a imagem gerada pelo docker build.
param([string[]]$Images)
$Images = $Images -split ','
$node = kubectl get nodes -o jsonpath='{.items[0].metadata.name}'
$cmd = (($Images | ForEach-Object { "crictl rmi docker.io/$_ >/dev/null 2>&1 && echo removida $_ || echo ausente $_" }) -join '; ')
$out = (kubectl debug "node/$node" --image=busybox:1.36 --profile=sysadmin -- chroot /host sh -c $cmd 2>&1) -join ' '
$name = ([regex]'node-debugger-[\w-]+').Match($out).Value
if (-not $name) { "nao consegui criar o pod de depuracao: $out"; exit 1 }
for ($i = 0; $i -lt 60; $i++) {
  $phase = kubectl get pod $name -o jsonpath='{.status.phase}' 2>$null
  if ($phase -eq 'Succeeded' -or $phase -eq 'Failed') { break }
  Start-Sleep -Seconds 1
}
kubectl logs $name 2>&1
kubectl delete pod $name --wait=false 2>&1 | Out-Null
