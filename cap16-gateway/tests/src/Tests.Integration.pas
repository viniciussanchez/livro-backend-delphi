unit Tests.Integration;

{ Testes de integração: falam HTTP com os três serviços de verdade,
  rodando com banco. Ficam na categoria "integracao" para poderem ser
  executados separadamente:

    EventosTests.exe --exclude:integracao   (só os rápidos)
    EventosTests.exe --include:integracao   (só estes, com tudo no ar) }

interface

uses
  System.SysUtils,
  System.JSON,
  DUnitX.TestFramework,
  RESTRequest4D;

type
  [TestFixture]
  [Category('integracao')]
  TPlatformIntegrationTests = class
  private
    FAdmin: string;
    FCustomer: string;
    FRaceBatchId: Integer;
    FBatchId: Integer;
    function Url(const AService: string): string;
    function Call(const AMethod, ABaseUrl, AResource, AToken: string;
      const ABody: string = ''): IResponse;
    function PostJSON(const ABaseUrl, AResource, AToken, ABody: string): TJSONObject;
    function Login(const AEmail, APassword: string): string;
    // Uma compra, para rodar em paralelo; grava o status HTTP em ACodes[AIndex].
    function Buyer(const ACodes: TArray<Integer>; const AIndex: Integer): TProc;
  public
    [SetupFixture]
    procedure PrepareEvent;

    [Test]
    procedure ConcurrentPurchasesNeverOversell;
    [Test]
    procedure ReservationMatchesTheSwaggerContract;
    [Test]
    procedure ErrorsMatchTheProblemContract;
    [Test]
    procedure CustomerCannotOpenReports;
    [Test]
    procedure RequestWithoutTokenIsUnauthorized;
  end;

implementation

uses
  System.Classes,
  System.Threading,
  System.Generics.Collections,
  System.SyncObjs;

const
  RACE_TICKETS = 10;
  RACE_BUYERS = 30;

function EnvOr(const AName, ADefault: string): string;
begin
  Result := GetEnvironmentVariable(AName);
  if Result.IsEmpty then
    Result := ADefault;
end;

// CPF válido e aleatório, para que o teste possa rodar várias vezes.
function RandomCpf: string;
var
  LDigits: array[0..10] of Integer;
  I, LSum, LCheck: Integer;
begin
  for I := 0 to 8 do
    LDigits[I] := Random(10);
  LDigits[0] := 1 + Random(9); // evita sequências como 000.000.000
  LSum := 0;
  for I := 0 to 8 do
    Inc(LSum, LDigits[I] * (10 - I));
  LCheck := (LSum * 10) mod 11;
  if LCheck = 10 then
    LCheck := 0;
  LDigits[9] := LCheck;
  LSum := 0;
  for I := 0 to 9 do
    Inc(LSum, LDigits[I] * (11 - I));
  LCheck := (LSum * 10) mod 11;
  if LCheck = 10 then
    LCheck := 0;
  LDigits[10] := LCheck;
  Result := '';
  for I := 0 to 10 do
    Result := Result + LDigits[I].ToString;
end;

function KeysOf(const AObject: TJSONObject): TArray<string>;
var
  LPair: TJSONPair;
begin
  Result := [];
  for LPair in AObject do
    Result := Result + [LPair.JsonString.Value];
end;

function Contains(const AList: TArray<string>; const AValue: string): Boolean;
var
  LItem: string;
begin
  for LItem in AList do
    if LItem = AValue then
      Exit(True);
  Result := False;
end;

{ TPlatformIntegrationTests }

function TPlatformIntegrationTests.Url(const AService: string): string;
begin
  if AService = 'event' then
    Result := EnvOr('EVENT_API_URL', 'http://127.0.0.1:9001')
  else if AService = 'customer' then
    Result := EnvOr('CUSTOMER_API_URL', 'http://127.0.0.1:9002')
  else
    Result := EnvOr('TICKET_API_URL', 'http://127.0.0.1:9003');
end;

function TPlatformIntegrationTests.Call(const AMethod, ABaseUrl, AResource, AToken: string;
  const ABody: string): IResponse;
var
  LRequest: IRequest;
begin
  LRequest := TRequest.New.BaseURL(ABaseUrl).Resource(AResource)
    .Accept('application/json').Timeout(10000);
  if not AToken.IsEmpty then
    LRequest.TokenBearer(AToken);
  if not ABody.IsEmpty then
    LRequest.ContentType('application/json').AddBody(ABody);
  if AMethod = 'POST' then
    Result := LRequest.Post
  else
    Result := LRequest.Get;
end;

function TPlatformIntegrationTests.PostJSON(const ABaseUrl, AResource, AToken, ABody: string): TJSONObject;
var
  LResponse: IResponse;
begin
  LResponse := Call('POST', ABaseUrl, AResource, AToken, ABody);
  if not (LResponse.StatusCode in [200, 201]) then
    raise Exception.CreateFmt('POST %s devolveu %d: %s', [AResource, LResponse.StatusCode, LResponse.Content]);
  Result := TJSONObject.ParseJSONValue(LResponse.Content) as TJSONObject;
end;

function TPlatformIntegrationTests.Login(const AEmail, APassword: string): string;
var
  LToken: TJSONObject;
begin
  LToken := PostJSON(Url('customer'), 'auth/token', '',
    Format('{"email":"%s","password":"%s"}', [AEmail, APassword]));
  try
    Result := LToken.GetValue<string>('accessToken');
  finally
    LToken.Free;
  end;
end;

function IdOf(const AJSON: TJSONObject): Integer;
begin
  try
    Result := AJSON.GetValue<Integer>('id');
  finally
    AJSON.Free;
  end;
end;

procedure TPlatformIntegrationTests.PrepareEvent;
var
  LVenueId, LEventId: Integer;
  LEmail: string;
begin
  Randomize;
  FAdmin := Login(EnvOr('ADMIN_EMAIL', 'admin@eventos.local'), EnvOr('ADMIN_PASSWORD', 'admin12345'));

  LVenueId := IdOf(PostJSON(Url('event'), 'venues', FAdmin,
    '{"name":"Arena dos Testes","address":"Rua dos Testes, 1","city":"Belo Horizonte","state":"MG","capacity":5000}'));
  LEventId := IdOf(PostJSON(Url('event'), 'events', FAdmin, Format(
    '{"name":"Evento de teste automatizado","categoryId":1,"venueId":%d,"startAt":"%d-12-10T20:00:00"}',
    [LVenueId, CurrentYear + 1])));
  FRaceBatchId := IdOf(PostJSON(Url('event'), Format('events/%d/batches', [LEventId]), FAdmin, Format(
    '{"name":"Lote da corrida","price":100,"quantity":%d,"salesStart":"2020-01-01T00:00:00","salesEnd":"%d-12-01T00:00:00"}',
    [RACE_TICKETS, CurrentYear + 1])));
  FBatchId := IdOf(PostJSON(Url('event'), Format('events/%d/batches', [LEventId]), FAdmin, Format(
    '{"name":"Lote geral","price":80,"quantity":1000,"salesStart":"2020-01-01T00:00:00","salesEnd":"%d-12-01T00:00:00"}',
    [CurrentYear + 1])));
  PostJSON(Url('event'), Format('events/%d/publish', [LEventId]), FAdmin, '').Free;

  // Um participante novo a cada execução: CPF e e-mail únicos.
  LEmail := Format('teste.%s@exemplo.com', [TGUID.NewGuid.ToString.Substring(1, 8).ToLower]);
  PostJSON(Url('customer'), 'customers', '', Format(
    '{"cpf":"%s","name":"Participante de Teste","email":"%s","password":"senha-de-teste"}',
    [RandomCpf, LEmail])).Free;
  FCustomer := Login(LEmail, 'senha-de-teste');
end;

function TPlatformIntegrationTests.Buyer(const ACodes: TArray<Integer>; const AIndex: Integer): TProc;
var
  LCodes: TArray<Integer>;
  LIndex: Integer;
begin
  // Cópias locais: o método anônimo captura variáveis, não parâmetros const.
  // LCodes aponta para o mesmo array de quem chamou.
  LCodes := ACodes;
  LIndex := AIndex;
  Result :=
    procedure
    begin
      LCodes[LIndex] := Call('POST', Url('ticket'), 'reservations', FCustomer,
        Format('{"batchId":%d,"quantity":1}', [FRaceBatchId])).StatusCode;
    end;
end;

procedure TPlatformIntegrationTests.ConcurrentPurchasesNeverOversell;
var
  LTasks: array of ITask;
  LCodes: TArray<Integer>;
  I, LCreated, LConflict: Integer;
  LBatch: TJSONObject;
begin
  SetLength(LTasks, RACE_BUYERS);
  SetLength(LCodes, RACE_BUYERS);
  // Todas as compras partem ao mesmo tempo, cada uma na sua thread.
  for I := 0 to RACE_BUYERS - 1 do
    LTasks[I] := TTask.Run(Buyer(LCodes, I));
  TTask.WaitForAll(LTasks);

  LCreated := 0;
  LConflict := 0;
  for I := 0 to RACE_BUYERS - 1 do
    case LCodes[I] of
      201: Inc(LCreated);
      409: Inc(LConflict);
    end;
  Assert.AreEqual(RACE_TICKETS, LCreated, 'Vendas aceitas');
  Assert.AreEqual(RACE_BUYERS - RACE_TICKETS, LConflict, 'Vendas recusadas por falta de estoque');

  LBatch := TJSONObject.ParseJSONValue(
    Call('GET', Url('ticket'), 'batches/' + FRaceBatchId.ToString, FAdmin).Content) as TJSONObject;
  try
    Assert.AreEqual(RACE_TICKETS, LBatch.GetValue<Integer>('sold'));
    Assert.AreEqual(0, LBatch.GetValue<Integer>('available'));
  finally
    LBatch.Free;
  end;
end;

procedure TPlatformIntegrationTests.ReservationMatchesTheSwaggerContract;
var
  LDoc, LReservation: TJSONObject;
  LDocumented, LReturned: TArray<string>;
  LKey: string;
begin
  LDoc := TJSONObject.ParseJSONValue(Call('GET', Url('ticket'), 'swagger/doc/json', '').Content) as TJSONObject;
  LReservation := PostJSON(Url('ticket'), 'reservations', FCustomer,
    Format('{"batchId":%d,"quantity":2}', [FBatchId]));
  try
    LDocumented := KeysOf(LDoc.GetValue<TJSONObject>('definitions.Reservation.properties'));
    LReturned := KeysOf(LReservation);
    // Nos dois sentidos: nada sem documentação, nada documentado que não exista.
    for LKey in LReturned do
      Assert.IsTrue(Contains(LDocumented, LKey), 'Campo devolvido e não documentado: ' + LKey);
    for LKey in LDocumented do
      Assert.IsTrue(Contains(LReturned, LKey), 'Campo documentado e não devolvido: ' + LKey);
  finally
    LReservation.Free;
    LDoc.Free;
  end;
end;

procedure TPlatformIntegrationTests.ErrorsMatchTheProblemContract;
var
  LDoc, LProblem: TJSONObject;
  LDocumented: TArray<string>;
  LRequired: TJSONArray;
  LKey: string;
  LResponse: IResponse;
  I: Integer;
begin
  LDoc := TJSONObject.ParseJSONValue(Call('GET', Url('ticket'), 'swagger/doc/json', '').Content) as TJSONObject;
  LResponse := Call('GET', Url('ticket'), 'reservations/999999', FCustomer);
  LProblem := TJSONObject.ParseJSONValue(LResponse.Content) as TJSONObject;
  try
    Assert.AreEqual(404, LResponse.StatusCode);
    Assert.IsTrue(LResponse.ContentType.StartsWith('application/problem+json'), LResponse.ContentType);
    LDocumented := KeysOf(LDoc.GetValue<TJSONObject>('definitions.Problem.properties'));
    for LKey in KeysOf(LProblem) do
      Assert.IsTrue(Contains(LDocumented, LKey), 'Campo de erro não documentado: ' + LKey);
    LRequired := LDoc.GetValue<TJSONArray>('definitions.Problem.required');
    for I := 0 to LRequired.Count - 1 do
      Assert.IsNotNull(LProblem.FindValue(LRequired.Items[I].Value), 'Campo obrigatório ausente: ' + LRequired.Items[I].Value);
  finally
    LProblem.Free;
    LDoc.Free;
  end;
end;

procedure TPlatformIntegrationTests.CustomerCannotOpenReports;
var
  LResponse: IResponse;
begin
  LResponse := Call('GET', Url('ticket'), 'reports/revenue?from=2026-01-01&to=2026-12-31&groupBy=month', FCustomer);
  Assert.AreEqual(403, LResponse.StatusCode);
  Assert.Contains(LResponse.Content, '"code":"forbidden"');
end;

procedure TPlatformIntegrationTests.RequestWithoutTokenIsUnauthorized;
var
  LResponse: IResponse;
begin
  LResponse := Call('POST', Url('ticket'), 'reservations', '', '{"batchId":1,"quantity":1}');
  Assert.AreEqual(401, LResponse.StatusCode);
  Assert.Contains(LResponse.Content, '"code":"unauthorized"');
end;

initialization
  TDUnitX.RegisterTestFixture(TPlatformIntegrationTests);

end.
