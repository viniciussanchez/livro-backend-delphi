unit Platform.Middleware.Observability;

(* O primeiro middleware de todos os serviços (capítulo 21).

  Para cada requisição:
    1. define o X-Request-Id (o que veio do gateway ou um novo) e o
       guarda na thread, para os logs e para as chamadas a outros serviços;
    2. mede o tempo e, no fim, conta a requisição nas métricas;
    3. escreve uma linha de log de acesso.

  Até o capítulo 20, só o gateway fazia os itens 1 e 3, com código próprio.
  Agora todo serviço faz, com o mesmo código. *)

interface

uses
  System.SysUtils,
  Horse;

procedure Observability(Req: THorseRequest; Res: THorseResponse; Next: TProc);

implementation

uses
  System.Diagnostics,
  Platform.Log,
  Platform.Metrics,
  Platform.SecureRandom;

function NewRequestId: string;
var
  LByte: Byte;
begin
  // 16 bytes aleatórios em hexadecimal: 32 caracteres, como no capítulo 16,
  // mas sem depender do GUID, que no Linux não é aleatório (capítulo 17).
  Result := '';
  for LByte in SecureRandomBytes(16) do
    Result := Result + IntToHex(LByte, 2).ToLower;
end;

function AcceptableId(const AValue: string): Boolean;
begin
  // Um id enorme ou com espaços e quebras de linha iria parar nos logs
  // de todos os serviços. Esse tipo de valor nós não aceitamos.
  Result := not AValue.IsEmpty and (AValue.Length <= 64) and
    (AValue.IndexOfAny([' ', #13, #10, #9, '"']) < 0);
end;

// Sondas do Kubernetes e a coleta do Prometheus chegam a cada poucos
// segundos. Contamos nas métricas, mas não poluímos o log com elas.
function IsQuietPath(const APath: string): Boolean;
begin
  Result := SameText(APath, '/health') or SameText(APath, '/health/live') or
    SameText(APath, '/metrics');
end;

procedure Observability(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LId, LRoute, LMethod, LStatus: string;
  LWatch: TStopwatch;
begin
  LId := Req.Headers['X-Request-Id'];
  if not AcceptableId(LId) then
    LId := NewRequestId;
  Req.Headers.Dictionary.AddOrSetValue('X-Request-Id', LId);
  Res.AddHeader('X-Request-Id', LId);
  SetCurrentRequestId(LId);

  LWatch := TStopwatch.StartNew;
  try
    Next;
  finally
    LMethod := Req.RawWebRequest.Method.ToUpper;
    LRoute := RouteTemplate(Req.PathInfo);
    // Cada valor diferente de rótulo vira uma série nova no Prometheus.
    // Um robô pedindo milhares de caminhos inventados criaria milhares de
    // séries; por isso, toda resposta 404 conta sob um rótulo só.
    if Res.Status = 404 then
      LRoute := '(desconhecida)';
    LStatus := Res.Status.ToString;
    if not SameText(LRoute, '/metrics') then
    begin
      TMetrics.Inc('http_requests_total', 'Requisições HTTP atendidas.',
        ['method=' + LMethod, 'route=' + LRoute, 'status=' + LStatus]);
      TMetrics.Observe('http_request_duration_seconds', 'Tempo de resposta das requisições HTTP.',
        ['method=' + LMethod, 'route=' + LRoute], LWatch.Elapsed.TotalSeconds);
    end;
    if not IsQuietPath(Req.PathInfo) then
      TLog.Info('requisição', [F('method', LMethod), F('path', Req.PathInfo), F('route', LRoute),
        F('status', Res.Status), F('durationMs', LWatch.ElapsedMilliseconds)]);
    // A thread volta para o Indy e vai atender outra requisição.
    SetCurrentRequestId('');
  end;
end;

end.
