unit TicketApi.Exceptions;

{ Exceções específicas da venda de ingressos. Cada uma herda da família
  certa (e, portanto, do status HTTP certo) e tem o seu próprio código,
  para que o cliente da API saiba exatamente o que aconteceu. }

interface

uses
  Platform.Exceptions;

type
  // O lote não tem mais nenhum ingresso.
  ESoldOutException = class(EConflictException)
  protected
    class function DefaultCode: string; override;
  end;

  // Há ingressos, mas menos do que o pedido.
  EInsufficientStockException = class(EConflictException)
  protected
    class function DefaultCode: string; override;
  end;

  // As vendas do lote ainda não abriram ou já terminaram.
  ESalesClosedException = class(EBusinessRuleException)
  protected
    class function DefaultCode: string; override;
  end;

  // Check-in de um ingresso que já entrou.
  ETicketAlreadyUsedException = class(EConflictException)
  protected
    class function DefaultCode: string; override;
  end;

  // Check-in de um ingresso de reserva cancelada.
  ETicketCancelledException = class(EConflictException)
  protected
    class function DefaultCode: string; override;
  end;

implementation

class function ESoldOutException.DefaultCode: string;
begin
  Result := 'sold-out';
end;

class function EInsufficientStockException.DefaultCode: string;
begin
  Result := 'insufficient-stock';
end;

class function ESalesClosedException.DefaultCode: string;
begin
  Result := 'sales-closed';
end;

class function ETicketAlreadyUsedException.DefaultCode: string;
begin
  Result := 'ticket-already-used';
end;

class function ETicketCancelledException.DefaultCode: string;
begin
  Result := 'ticket-cancelled';
end;

end.
