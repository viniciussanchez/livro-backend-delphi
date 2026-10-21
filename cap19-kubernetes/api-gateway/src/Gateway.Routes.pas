unit Gateway.Routes;

{ A tabela de rotas do gateway: qual prefixo de URL pública vai para qual
  serviço, e com qual caminho lá dentro.

  O cliente só conhece os caminhos públicos. Os serviços podem mudar de
  endereço, ou um caminho interno pode mudar de nome, sem que nenhum
  cliente precise saber: basta ajustar esta tabela. }

interface

type
  // Um serviço para onde o gateway encaminha requisições.
  TUpstream = record
    Name: string;
    BaseURL: string;
  end;

  // Uma linha da tabela: tudo que começa com PublicPrefix vai para
  // Upstream, trocando o prefixo por InternalPrefix.
  TGatewayRoute = record
    PublicPrefix: string;
    InternalPrefix: string;
    Upstream: TUpstream;
  end;

  // O resultado de procurar um caminho na tabela.
  TRouteMatch = record
    Route: TGatewayRoute;
    // Caminho no serviço de destino, já com o prefixo trocado.
    InternalPath: string;
  end;

  TRouteTable = class
  private
    class var FRoutes: TArray<TGatewayRoute>;
    class var FUpstreams: TArray<TUpstream>;
    class procedure Add(const APublicPrefix, AInternalPrefix: string; const AUpstream: TUpstream); static;
  public
    // Monta a tabela com os endereços que vieram da configuração.
    class procedure Build(const AEventApiURL, ACustomerApiURL, ATicketApiURL: string); static;
    // Procura o prefixo mais longo que combina com APath.
    class function TryMatch(const APath: string; out AMatch: TRouteMatch): Boolean; static;
    class property Upstreams: TArray<TUpstream> read FUpstreams;
  end;

implementation

uses
  System.SysUtils;

function NewUpstream(const AName, ABaseURL: string): TUpstream;
begin
  Result.Name := AName;
  // Sem barra no fim: o caminho interno sempre começa com uma.
  Result.BaseURL := ABaseURL.TrimRight(['/']);
end;

class procedure TRouteTable.Add(const APublicPrefix, AInternalPrefix: string; const AUpstream: TUpstream);
var
  LRoute: TGatewayRoute;
begin
  LRoute.PublicPrefix := APublicPrefix;
  LRoute.InternalPrefix := AInternalPrefix;
  LRoute.Upstream := AUpstream;
  FRoutes := FRoutes + [LRoute];
end;

class procedure TRouteTable.Build(const AEventApiURL, ACustomerApiURL, ATicketApiURL: string);
var
  LEvents, LCustomers, LTickets: TUpstream;
begin
  LEvents := NewUpstream('event-api', AEventApiURL);
  LCustomers := NewUpstream('customer-api', ACustomerApiURL);
  LTickets := NewUpstream('ticket-api', ATicketApiURL);
  FUpstreams := [LEvents, LCustomers, LTickets];
  FRoutes := [];

  // Catálogo: eventos, locais, categorias e lotes à venda.
  Add('/events', '/events', LEvents);
  Add('/venues', '/venues', LEvents);
  Add('/categories', '/categories', LEvents);
  Add('/batches', '/batches', LEvents);

  // Pessoas: login, usuários da equipe e participantes.
  Add('/auth', '/auth', LCustomers);
  Add('/users', '/users', LCustomers);
  Add('/customers', '/customers', LCustomers);

  // Vendas: reservas, ingressos e relatórios.
  Add('/reservations', '/reservations', LTickets);
  Add('/tickets', '/tickets', LTickets);
  Add('/reports', '/reports', LTickets);
  // A ticket-api também tem uma rota /batches, a do estoque de lugares.
  // Do lado de fora, ela ganha outro nome para não brigar com a do catálogo.
  Add('/inventory/batches', '/batches', LTickets);
end;

// '/events' combina com '/events' e '/events/7/batches', mas não com '/eventsx'.
function PrefixMatches(const APath, APrefix: string): Boolean;
begin
  Result := SameText(APath, APrefix) or
    APath.StartsWith(APrefix + '/', True);
end;

class function TRouteTable.TryMatch(const APath: string; out AMatch: TRouteMatch): Boolean;
var
  LRoute: TGatewayRoute;
  LBestLength: Integer;
begin
  Result := False;
  LBestLength := -1;
  for LRoute in FRoutes do
    if PrefixMatches(APath, LRoute.PublicPrefix) and
       (LRoute.PublicPrefix.Length > LBestLength) then
    begin
      LBestLength := LRoute.PublicPrefix.Length;
      AMatch.Route := LRoute;
      AMatch.InternalPath := LRoute.InternalPrefix + APath.Substring(LRoute.PublicPrefix.Length);
      Result := True;
    end;
end;

end.
