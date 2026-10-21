unit TicketApi.Controller;

interface

procedure Registry;

implementation

uses
  System.SysUtils,
  System.JSON,
  Horse,
  Platform.Http,
  TicketApi.Entity.Batch,
  TicketApi.Entity.Reservation,
  TicketApi.DTO,
  TicketApi.Container;

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
  LReservation: TReservation;
begin
  LReservation := ReservationService.Reserve(TReservationRequest.FromJSON(RequestBody(Req)));
  try
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
    Res.Send<TJSONObject>(TTicketMapper.ToJSON(LReservation));
  finally
    LReservation.Free;
  end;
end;

// POST /reservations/:id/cancel
procedure CancelReservation(Req: THorseRequest; Res: THorseResponse);
var
  LReservation: TReservation;
begin
  LReservation := ReservationService.Cancel(ParseId(Req.Params['id']));
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
  THorse
    .Put('/batches/:id', PutBatch)
    .Get('/batches/:id', GetBatch)
    .Post('/reservations', PostReservation)
    .Get('/reservations/:id', GetReservation)
    .Post('/reservations/:id/cancel', CancelReservation)
    .Get('/tickets/:code', GetTicket)
    .Post('/tickets/:code/check-in', CheckIn);
end;

end.
