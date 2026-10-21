unit TicketApi.Integration.EventApi;

{ Cliente HTTP da event-api. }

interface

uses
  Platform.Integration,
  TicketApi.Partners;

type
  TEventApiClient = class(TServiceClient, IEventCatalog)
  public
    constructor Create(const ABaseURL: string; const ATimeout: Integer);
    function FindBatch(const ABatchId: Integer; out ABatch: TCatalogBatch): Boolean;
    function FindEventName(const AEventId: Integer; out AName: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.JSON,
  RESTRequest4D,
  Platform.Dates;

constructor TEventApiClient.Create(const ABaseURL: string; const ATimeout: Integer);
begin
  inherited Create('event-api', ABaseURL, ATimeout);
end;

function TEventApiClient.FindBatch(const ABatchId: Integer; out ABatch: TCatalogBatch): Boolean;
var
  LResponse: IResponse;
  LJSON, LEvent: TJSONObject;
begin
  ABatch := Default(TCatalogBatch);
  LResponse := Get('batches/' + ABatchId.ToString);
  if LResponse.StatusCode = 404 then
    Exit(False);
  if LResponse.StatusCode <> 200 then
    RaiseUnavailable(Format('HTTP %d ao buscar o lote %d', [LResponse.StatusCode, ABatchId]));

  // O JSONValue pertence à resposta: não liberamos.
  LJSON := LResponse.JSONValue as TJSONObject;
  LEvent := LJSON.GetValue<TJSONObject>('event');
  ABatch.Id := LJSON.GetValue<Integer>('id');
  ABatch.EventId := LJSON.GetValue<Integer>('eventId');
  ABatch.Price := SimpleRoundTo(LJSON.GetValue<Double>('price'), -2);
  ABatch.Quantity := LJSON.GetValue<Integer>('quantity');
  TryParseISODateTime(LJSON.GetValue<string>('salesStart'), ABatch.SalesStart);
  TryParseISODateTime(LJSON.GetValue<string>('salesEnd'), ABatch.SalesEnd);
  ABatch.EventName := LEvent.GetValue<string>('name');
  ABatch.EventPublished := SameText(LEvent.GetValue<string>('status'), 'PUBLISHED');
  Result := True;
end;

function TEventApiClient.FindEventName(const AEventId: Integer; out AName: string): Boolean;
var
  LResponse: IResponse;
begin
  AName := '';
  LResponse := Get('events/' + AEventId.ToString);
  if LResponse.StatusCode = 404 then
    Exit(False);
  if LResponse.StatusCode <> 200 then
    RaiseUnavailable(Format('HTTP %d ao buscar o evento %d', [LResponse.StatusCode, AEventId]));
  AName := (LResponse.JSONValue as TJSONObject).GetValue<string>('name');
  Result := True;
end;

end.
