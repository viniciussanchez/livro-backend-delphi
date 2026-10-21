unit CustomerApi.Controller.Customer;

interface

procedure Registry;

implementation

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  Horse,
  Platform.Http,
  Platform.Auth,
  Platform.Exceptions,
  CustomerApi.Entity.Customer,
  CustomerApi.DTO.Customer,
  CustomerApi.Container;

// Participantes só enxergam o próprio cadastro. Para qualquer outro id,
// respondemos 404, como se ele não existisse: assim ninguém descobre
// quais ids estão cadastrados testando um por um.
function AllowedCustomerId(const AReq: THorseRequest; const AAllowService: Boolean): Integer;
var
  LUser: TPrincipal;
begin
  Result := ParseId(AReq.Params['id']);
  LUser := CurrentUser(AReq);
  if LUser.HasRole([ROLE_ADMIN]) or LUser.IsCustomer(Result) then
    Exit;
  if AAllowService and LUser.HasRole([ROLE_SERVICE]) then
    Exit;
  raise ENotFoundException.Create('Participante não encontrado.');
end;

// GET /customers?cpf=... ou ?email=...
procedure GetCustomers(Req: THorseRequest; Res: THorseResponse);
var
  LCustomers: TObjectList<TCustomer>;
begin
  LCustomers := CustomerService.Search(Req.Query['cpf'], Req.Query['email']);
  try
    Res.Send<TJSONArray>(TCustomerMapper.ToJSONArray(LCustomers));
  finally
    LCustomers.Free;
  end;
end;

// GET /customers/:id
procedure GetCustomerById(Req: THorseRequest; Res: THorseResponse);
var
  LCustomer: TCustomer;
begin
  LCustomer := CustomerService.FindById(AllowedCustomerId(Req, True));
  try
    Res.Send<TJSONObject>(TCustomerMapper.ToJSON(LCustomer));
  finally
    LCustomer.Free;
  end;
end;

// POST /customers
procedure PostCustomer(Req: THorseRequest; Res: THorseResponse);
var
  LCustomer: TCustomer;
begin
  LCustomer := CustomerService.Add(TCustomerRequest.FromJSON(RequestBody(Req)));
  try
    Res.AddHeader('Location', '/customers/' + LCustomer.Id.ToString);
    Res.Status(THTTPStatus.Created).Send<TJSONObject>(TCustomerMapper.ToJSON(LCustomer));
  finally
    LCustomer.Free;
  end;
end;

// PUT /customers/:id
procedure PutCustomer(Req: THorseRequest; Res: THorseResponse);
var
  LCustomer: TCustomer;
begin
  LCustomer := CustomerService.Update(AllowedCustomerId(Req, False),
    TCustomerRequest.FromJSON(RequestBody(Req)));
  try
    Res.Send<TJSONObject>(TCustomerMapper.ToJSON(LCustomer));
  finally
    LCustomer.Free;
  end;
end;

// DELETE /customers/:id
procedure DeleteCustomer(Req: THorseRequest; Res: THorseResponse);
begin
  CustomerService.Remove(AllowedCustomerId(Req, False));
  Res.Status(THTTPStatus.NoContent);
end;

procedure Registry;
begin
  // Busca por CPF ou e-mail: só a administração e os outros serviços.
  THorse.AddCallbacks(Protect([ROLE_ADMIN, ROLE_SERVICE])).Get('/customers', GetCustomers);
  // Cadastro: público. É assim que o participante cria o próprio acesso.
  THorse.Post('/customers', PostCustomer);
  // As demais exigem login; quem pode o quê é decidido em AllowedCustomerId.
  THorse.AddCallback(Authenticate).Get('/customers/:id', GetCustomerById);
  THorse.AddCallback(Authenticate).Put('/customers/:id', PutCustomer);
  THorse.AddCallback(Authenticate).Delete('/customers/:id', DeleteCustomer);
end;

end.
