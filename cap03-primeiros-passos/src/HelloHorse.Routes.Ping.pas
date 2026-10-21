unit HelloHorse.Routes.Ping;

interface

procedure Registry;

implementation

uses
  Horse;

procedure GetPing(Req: THorseRequest; Res: THorseResponse);
begin
  Res.Send('pong');
end;

// GET /hello/:name
procedure GetHello(Req: THorseRequest; Res: THorseResponse);
begin
  Res.Send('Olá, ' + Req.Params['name'] + '!');
end;

procedure Registry;
begin
  THorse
    .Get('/ping', GetPing)
    .Get('/hello/:name', GetHello);
end;

end.
