unit EventApi.DTO.Event;

{ DTOs: o formato dos dados que entram e saem da API.
  Eles existem para que o JSON da API e a entidade possam
  evoluir de forma independente. }

interface

uses
  System.JSON,
  System.Generics.Collections,
  EventApi.Entity.Event;

type
  // Dados recebidos no cadastro de um evento.
  TEventRequest = record
    Name: string;
    City: string;
    EventDate: string;
    Capacity: Integer;
    class function FromJSON(const AJSON: TJSONObject): TEventRequest; static;
  end;

  // Conversão da entidade para o JSON de resposta.
  TEventMapper = class
  public
    class function ToJSON(const AEvent: TEvent): TJSONObject; static;
    class function ToJSONArray(const AEvents: TObjectList<TEvent>): TJSONArray; static;
  end;

implementation

uses
  System.SysUtils,
  EventApi.Commons.Dates;

{ TEventRequest }

class function TEventRequest.FromJSON(const AJSON: TJSONObject): TEventRequest;
begin
  Result.Name := AJSON.GetValue<string>('name', '').Trim;
  Result.City := AJSON.GetValue<string>('city', '').Trim;
  Result.EventDate := AJSON.GetValue<string>('eventDate', '').Trim;
  Result.Capacity := AJSON.GetValue<Integer>('capacity', 0);
end;

{ TEventMapper }

class function TEventMapper.ToJSON(const AEvent: TEvent): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(AEvent.Id));
  Result.AddPair('name', AEvent.Name);
  Result.AddPair('city', AEvent.City);
  Result.AddPair('eventDate', FormatISODate(AEvent.EventDate));
  Result.AddPair('capacity', TJSONNumber.Create(AEvent.Capacity));
end;

class function TEventMapper.ToJSONArray(const AEvents: TObjectList<TEvent>): TJSONArray;
var
  LEvent: TEvent;
begin
  Result := TJSONArray.Create;
  for LEvent in AEvents do
    Result.AddElement(ToJSON(LEvent));
end;

end.
