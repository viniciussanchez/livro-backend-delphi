unit Gateway.Health;

(* GET /health do gateway: pergunta a cada serviço se ele está de pé,
  todos ao mesmo tempo, e junta as respostas.

    200 {"status": "up", "services": [{"name": "event-api", "status": "up", "latencyMs": 4}, ...]}
    503 {"status": "degraded", "services": [..., {"name": "ticket-api", "status": "down", ...}]} *)

interface

uses
  Horse;

procedure ConfigureHealth(const ATimeout: Integer);
procedure GetHealth(Req: THorseRequest; Res: THorseResponse);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Threading,
  System.Diagnostics,
  System.Net.HttpClient,
  Horse.Commons,
  Gateway.Routes;

type
  TServiceHealth = record
    Name: string;
    Up: Boolean;
    LatencyMs: Int64;
    Detail: string;
  end;

var
  GTimeout: Integer = 2000;

procedure ConfigureHealth(const ATimeout: Integer);
begin
  GTimeout := ATimeout;
end;

function CheckService(const AUpstream: TUpstream): TServiceHealth;
var
  LClient: THTTPClient;
  LWatch: TStopwatch;
  LStatus: Integer;
begin
  Result.Name := AUpstream.Name;
  Result.Up := False;
  Result.Detail := '';
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := GTimeout;
    LClient.ResponseTimeout := GTimeout;
    LWatch := TStopwatch.StartNew;
    try
      LStatus := LClient.Get(AUpstream.BaseURL + '/health').StatusCode;
      Result.Up := LStatus = 200;
      if not Result.Up then
        Result.Detail := Format('respondeu %d', [LStatus]);
    except
      on E: Exception do
        Result.Detail := 'sem resposta';
    end;
    Result.LatencyMs := LWatch.ElapsedMilliseconds;
  finally
    LClient.Free;
  end;
end;

// Por que uma função separada? Um método anônimo criado dentro do "for"
// enxergaria a variável LIndex, e não o valor dela naquele momento: quando
// a tarefa rodasse, o laço talvez já tivesse avançado. Aqui, cada tarefa
// recebe a sua própria cópia de AIndex e AUpstream.
function StartCheck(AResults: TArray<TServiceHealth>; AIndex: Integer;
  AUpstream: TUpstream): ITask;
begin
  Result := TTask.Run(
    procedure
    begin
      AResults[AIndex] := CheckService(AUpstream);
    end);
end;

procedure GetHealth(Req: THorseRequest; Res: THorseResponse);
var
  LUpstreams: TArray<TUpstream>;
  LResults: TArray<TServiceHealth>;
  LTasks: TArray<ITask>;
  LIndex: Integer;
  LAllUp: Boolean;
  LBody: TJSONObject;
  LServices: TJSONArray;
  LItem: TJSONObject;
  LHealth: TServiceHealth;
begin
  LUpstreams := TRouteTable.Upstreams;
  SetLength(LResults, Length(LUpstreams));
  SetLength(LTasks, Length(LUpstreams));

  // Em paralelo: o tempo total é o do serviço mais lento, não a soma de todos.
  for LIndex := 0 to High(LUpstreams) do
    LTasks[LIndex] := StartCheck(LResults, LIndex, LUpstreams[LIndex]);
  TTask.WaitForAll(LTasks);

  LAllUp := True;
  LServices := TJSONArray.Create;
  for LHealth in LResults do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('name', LHealth.Name);
    if LHealth.Up then
      LItem.AddPair('status', 'up')
    else
    begin
      LItem.AddPair('status', 'down');
      LItem.AddPair('detail', LHealth.Detail);
      LAllUp := False;
    end;
    LItem.AddPair('latencyMs', TJSONNumber.Create(LHealth.LatencyMs));
    LServices.AddElement(LItem);
  end;

  LBody := TJSONObject.Create;
  if LAllUp then
    LBody.AddPair('status', 'up')
  else
    LBody.AddPair('status', 'degraded');
  LBody.AddPair('services', LServices);
  try
    Res.ContentType('application/json; charset=UTF-8');
    if LAllUp then
      Res.Status(THTTPStatus.OK)
    else
      Res.Status(THTTPStatus.ServiceUnavailable);
    Res.Send(LBody.ToJSON([TJSONValue.TJSONOutputOption.EncodeBelow32]));
  finally
    LBody.Free;
  end;
end;

end.
