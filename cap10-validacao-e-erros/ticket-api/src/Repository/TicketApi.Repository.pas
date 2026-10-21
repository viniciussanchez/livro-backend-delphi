unit TicketApi.Repository;

{ Contratos da camada de dados da ticket-api. }

interface

uses
  TicketApi.Entity.Batch,
  TicketApi.Entity.Reservation;

type
  IBatchRepository = interface
    ['{6B3F8D20-9E14-4A7C-B5D1-2E7A0C94F8B3}']
    // Retorna nil quando não encontra. Quem chama é dono do objeto.
    function FindById(const AId: Integer): TBatchInventory;
    // Cria ou atualiza o lote. Retorna False se a nova quantidade for
    // menor do que o que já foi vendido.
    function Save(const ABatch: TBatchInventory; const ANow: TDateTime): Boolean;
    // Tenta retirar AQuantity ingressos do estoque, em uma única operação atômica.
    // Só consegue se o lote estiver à venda e houver ingressos suficientes.
    function TryTakeStock(const ABatchId, AQuantity: Integer; const ANow: TDateTime;
      out AUnitPrice: Currency; out AEventId: Integer): Boolean;
    procedure ReleaseStock(const ABatchId, AQuantity: Integer; const ANow: TDateTime);
  end;

  IReservationRepository = interface
    ['{D9A42C17-7F3E-4B85-A0C6-15E8B3D79F42}']
    // Com ALock = True, a linha da reserva fica travada até o fim da transação.
    function FindById(const AId: Integer; const ALock: Boolean = False): TReservation;
    // Grava a reserva e os seus ingressos.
    procedure Insert(const AReservation: TReservation);
    procedure MarkCancelled(const AId: Integer; const ANow: TDateTime);
    function FindTicket(const ACode: string): TTicket;
    // Marca o ingresso como usado, se ele ainda for válido. Operação atômica.
    function TryCheckIn(const ACode: string; const ANow: TDateTime): Boolean;
  end;

implementation

end.
