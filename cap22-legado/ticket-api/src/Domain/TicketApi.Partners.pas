unit TicketApi.Partners;

{ O que a ticket-api precisa saber dos outros serviços, descrito do ponto
  de vista dela. O Service conhece só estas interfaces; quem fala HTTP são
  as classes da pasta Integration. Nos testes (capítulo 15), trocamos as
  implementações por versões falsas, sem rede. }

interface

type
  // O lote como a event-api o descreve, com o resumo do evento.
  TCatalogBatch = record
    Id: Integer;
    EventId: Integer;
    EventName: string;
    EventPublished: Boolean;
    Price: Currency;
    Quantity: Integer;
    SalesStart: TDateTime;
    SalesEnd: TDateTime;
  end;

  IEventCatalog = interface
    ['{2E7C51A4-8B3D-4F60-9A15-C4D8E2F07B39}']
    // False quando o lote não existe. Lança EServiceUnavailableException
    // quando a event-api não responde.
    function FindBatch(const ABatchId: Integer; out ABatch: TCatalogBatch): Boolean;
    function FindEventName(const AEventId: Integer; out AName: string): Boolean;
  end;

  ICustomerDirectory = interface
    ['{B8F4D2C6-1A93-4E57-8C0B-7D35A6E19F24}']
    // Lança EServiceUnavailableException quando a customer-api não responde.
    function Exists(const ACustomerId: Integer): Boolean;
  end;

implementation

end.
