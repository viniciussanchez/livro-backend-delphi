unit TicketApi.Controller;

interface

procedure Registry;

implementation

uses
  System.SysUtils,
  System.JSON,
  Horse,
  Platform.Http,
  Platform.Auth,
  Platform.Exceptions,
  Platform.Metrics,
  TicketApi.Entity.Batch,
  TicketApi.Entity.Reservation,
  TicketApi.DTO,
  TicketApi.Service,
  TicketApi.Container;

// Um participante só enxerga as próprias reservas. Para as dos outros,
// respondemos 404, como se não existissem.
procedure EnsureOwner(const AReq: THorseRequest; const AReservation: TReservation);
var
  LUser: TPrincipal;
begin
  LUser := CurrentUser(AReq);
  if LUser.HasRole([ROLE_CUSTOMER]) and not LUser.IsCustomer(AReservation.CustomerId) then
    raise ENotFoundException.Create('Reserva não encontrada.');
end;

// PUT /batches/:id
procedure PutBatch(Req: THorseRequest; Res: THorseResponse);
var
  LBatch: TBatchInventory;
begin
  LBatch := BatchService.Save(ParseId(Req.Params['id']), TBatchRequest.FromJSON(RequestBody(Req)));
  try
    Res.Send<TJSONObject>(TTicketMapper.ToJSON(LBatch));
  finally
    LBatch.Free;
  end;
end;

// GET /batches/:id
procedure GetBatch(Req: THorseRequest; Res: THorseResponse);
var
  LBatch: TBatchInventory;
begin
  LBatch := BatchService.FindById(ParseId(Req.Params['id']));
  try
    Res.Send<TJSONObject>(TTicketMapper.ToJSON(LBatch));
  finally
    LBatch.Free;
  end;
end;

// POST /reservations
procedure PostReservation(Req: THorseRequest; Res: THorseResponse);
var
  LRequest: TReservationRequest;
  LUser: TPrincipal;
  LReservation: TReservation;
begin
  LRequest := TReservationRequest.FromJSON(RequestBody(Req));
  // O participante compra em nome de si mesmo: o customerId vem do token,
  // nunca do corpo. Só um administrador pode comprar para outra pessoa.
  LUser := CurrentUser(Req);
  if LUser.HasRole([ROLE_CUSTOMER]) then
    LRequest.CustomerId := LUser.CustomerId;
  LReservation := ReservationService.Reserve(LRequest);
  try
    // Capítulo 21: uma métrica de negócio, ao lado das técnicas.
    TMetrics.Inc('tickets_sold_total', 'Ingressos vendidos.', [], LReservation.Quantity);
    Res.AddHeader('Location', '/reservations/' + LReservation.Id.ToString);
    Res.Status(THTTPStatus.Created).Send<TJSONObject>(TTicketMapper.ToJSON(LReservation));
  finally
    LReservation.Free;
  end;
end;

// GET /reservations/:id
procedure GetReservation(Req: THorseRequest; Res: THorseResponse);
var
  LReservation: TReservation;
begin
  LReservation := ReservationService.FindById(ParseId(Req.Params['id']));
  try
    EnsureOwner(Req, LReservation);
    Res.Send<TJSONObject>(TTicketMapper.ToJSON(LReservation));
  finally
    LReservation.Free;
  end;
end;

// POST /reservations/:id/cancel
procedure CancelReservation(Req: THorseRequest; Res: THorseResponse);
var
  LService: IReservationService;
  LId: Integer;
  LReservation: TReservation;
begin
  LService := ReservationService;
  LId := ParseId(Req.Params['id']);
  // Confere o dono antes de cancelar.
  LReservation := LService.FindById(LId);
  try
    EnsureOwner(Req, LReservation);
  finally
    LReservation.Free;
  end;
  LReservation := LService.Cancel(LId);
  try
    Res.Send<TJSONObject>(TTicketMapper.ToJSON(LReservation));
  finally
    LReservation.Free;
  end;
end;

// GET /tickets/:code
procedure GetTicket(Req: THorseRequest; Res: THorseResponse);
var
  LTicket: TTicket;
begin
  LTicket := ReservationService.FindTicket(Req.Params['code']);
  try
    Res.Send<TJSONObject>(TTicketMapper.ToJSON(LTicket));
  finally
    LTicket.Free;
  end;
end;

// POST /tickets/:code/check-in
procedure CheckIn(Req: THorseRequest; Res: THorseResponse);
var
  LTicket: TTicket;
begin
  LTicket := ReservationService.CheckIn(Req.Params['code']);
  try
    Res.Send<TJSONObject>(TTicketMapper.ToJSON(LTicket));
  finally
    LTicket.Free;
  end;
end;

procedure Registry;
begin
  // Estoque: administração (e consulta também pela equipe).
  THorse.AddCallbacks(Protect([ROLE_ADMIN])).Put('/batches/:id', PutBatch);
  THorse.AddCallbacks(Protect([ROLE_ADMIN, ROLE_STAFF])).Get('/batches/:id', GetBatch);
  // Reservas: o participante compra e cancela as próprias.
  THorse.AddCallbacks(Protect([ROLE_CUSTOMER, ROLE_ADMIN])).Post('/reservations', PostReservation);
  THorse.AddCallbacks(Protect([ROLE_CUSTOMER, ROLE_ADMIN, ROLE_STAFF])).Get('/reservations/:id', GetReservation);
  THorse.AddCallbacks(Protect([ROLE_CUSTOMER, ROLE_ADMIN])).Post('/reservations/:id/cancel', CancelReservation);
  // Portaria: equipe e administração.
  THorse.AddCallbacks(Protect([ROLE_STAFF, ROLE_ADMIN])).Get('/tickets/:code', GetTicket);
  THorse.AddCallbacks(Protect([ROLE_STAFF, ROLE_ADMIN])).Post('/tickets/:code/check-in', CheckIn);
end;

end.
