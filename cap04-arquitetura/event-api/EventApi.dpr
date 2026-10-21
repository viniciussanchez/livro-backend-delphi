program EventApi;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.Jhonson,
  EventApi.Entity.Event in 'src\Domain\EventApi.Entity.Event.pas',
  EventApi.Exceptions in 'src\Domain\EventApi.Exceptions.pas',
  EventApi.Commons.Dates in 'src\Commons\EventApi.Commons.Dates.pas',
  EventApi.DTO.Event in 'src\DTO\EventApi.DTO.Event.pas',
  EventApi.Repository.Event in 'src\Repository\EventApi.Repository.Event.pas',
  EventApi.Repository.Event.Memory in 'src\Repository\EventApi.Repository.Event.Memory.pas',
  EventApi.Service.Event in 'src\Service\EventApi.Service.Event.pas',
  EventApi.Controller.Event in 'src\Controller\EventApi.Controller.Event.pas',
  EventApi.Container in 'src\EventApi.Container.pas';

begin
  THorse.Use(Jhonson);

  EventApi.Controller.Event.Registry;

  THorse.Listen(9001,
    procedure
    begin
      Writeln(Format('event-api rodando em http://localhost:%d', [THorse.Port]));
      Writeln('Pressione Ctrl+C para encerrar.');
    end);
end.
