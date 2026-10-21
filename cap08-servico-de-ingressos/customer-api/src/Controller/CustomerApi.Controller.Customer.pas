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
  CustomerApi.Entity.Customer,
  CustomerApi.DTO.Customer,
  CustomerApi.Container;

// GET /customers?cpf=... ou ?email=...
procedure GetCustomers(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    var
      LCustomers: TObjectList<TCustomer>;
    begin
      LCustomers := CustomerService.Search(Req.Query['cpf'], Req.Query['email']);
      try
        Res.Send<TJSONArray>(TCustomerMapper.ToJSONArray(LCustomers));
      finally
        LCustomers.Free;
      end;
    end);
end;

// GET /customers/:id
procedure GetCustomerById(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    var
      LCustomer: TCustomer;
    begin
      LCustomer := CustomerService.FindById(ParseId(Req.Params['id']));
      try
        Res.Send<TJSONObject>(TCustomerMapper.ToJSON(LCustomer));
      finally
        LCustomer.Free;
      end;
    end);
end;

// POST /customers
procedure PostCustomer(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
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
    end);
end;

// PUT /customers/:id
procedure PutCustomer(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    var
      LCustomer: TCustomer;
    begin
      LCustomer := CustomerService.Update(ParseId(Req.Params['id']),
        TCustomerRequest.FromJSON(RequestBody(Req)));
      try
        Res.Send<TJSONObject>(TCustomerMapper.ToJSON(LCustomer));
      finally
        LCustomer.Free;
      end;
    end);
end;

// DELETE /customers/:id
procedure DeleteCustomer(Req: THorseRequest; Res: THorseResponse);
begin
  HandleErrors(Res,
    procedure
    begin
      CustomerService.Remove(ParseId(Req.Params['id']));
      Res.Status(THTTPStatus.NoContent);
    end);
end;

procedure Registry;
begin
  THorse
    .Get('/customers', GetCustomers)
    .Get('/customers/:id', GetCustomerById)
    .Post('/customers', PostCustomer)
    .Put('/customers/:id', PutCustomer)
    .Delete('/customers/:id', DeleteCustomer);
end;

end.
