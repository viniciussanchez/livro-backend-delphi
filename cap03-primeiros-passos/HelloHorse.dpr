program HelloHorse;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.Jhonson,
  HelloHorse.Middleware.RequestLog in 'src\HelloHorse.Middleware.RequestLog.pas',
  HelloHorse.Store.Events in 'src\HelloHorse.Store.Events.pas',
  HelloHorse.Routes.Ping in 'src\HelloHorse.Routes.Ping.pas',
  HelloHorse.Routes.Events in 'src\HelloHorse.Routes.Events.pas';

begin
  // A ordem importa: o log envolve todo o restante da requisição.
  THorse
    .Use(RequestLog)
    .Use(Jhonson);

  HelloHorse.Routes.Ping.Registry;
  HelloHorse.Routes.Events.Registry;

  THorse.Listen(9000,
    procedure
    begin
      Writeln(Format('Servidor rodando em http://localhost:%d', [THorse.Port]));
      Writeln('Pressione Ctrl+C para encerrar.');
    end);
end.
