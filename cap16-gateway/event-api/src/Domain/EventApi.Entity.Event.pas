unit EventApi.Entity.Event;

interface

type
  TEventStatus = (esDraft, esPublished, esCancelled);

  TEventStatusHelper = record helper for TEventStatus
    function ToString: string;
    class function TryParse(const AValue: string; out AStatus: TEventStatus): Boolean; static;
  end;

  TEvent = class
  private
    FId: Integer;
    FName: string;
    FDescription: string;
    FCategoryId: Integer;
    FCategoryName: string;
    FVenueId: Integer;
    FVenueName: string;
    FCity: string;
    FStartAt: TDateTime;
    FStatus: TEventStatus;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property CategoryId: Integer read FCategoryId write FCategoryId;
    property VenueId: Integer read FVenueId write FVenueId;
    property StartAt: TDateTime read FStartAt write FStartAt;
    property Status: TEventStatus read FStatus write FStatus;
    // Dados de leitura, preenchidos pelo repositório a partir da categoria e do local.
    property CategoryName: string read FCategoryName write FCategoryName;
    property VenueName: string read FVenueName write FVenueName;
    property City: string read FCity write FCity;
  end;

implementation

uses
  System.SysUtils;

const
  STATUS_NAMES: array[TEventStatus] of string = ('DRAFT', 'PUBLISHED', 'CANCELLED');

function TEventStatusHelper.ToString: string;
begin
  Result := STATUS_NAMES[Self];
end;

class function TEventStatusHelper.TryParse(const AValue: string; out AStatus: TEventStatus): Boolean;
var
  LStatus: TEventStatus;
begin
  for LStatus := Low(TEventStatus) to High(TEventStatus) do
    if SameText(STATUS_NAMES[LStatus], AValue) then
    begin
      AStatus := LStatus;
      Exit(True);
    end;
  Result := False;
end;

end.
