unit EventApi.Docs;

{ Documentação Swagger da event-api.
  Acesse http://localhost:9001/swagger/doc/html com a API no ar. }

interface

uses
  System.Generics.Collections,
  GBSwagger.Model.Attributes;

type
  [SwagClass('CategoryRequest')]
  TCategoryRequestDoc = class
  private
    FName: string;
  public
    [SwagProp('Nome da categoria', True)]
    [SwagString(60, 1)]
    property Name: string read FName write FName;
  end;

  [SwagClass('Category')]
  TCategoryDoc = class(TCategoryRequestDoc)
  private
    FId: Integer;
  public
    [SwagProp('Identificador gerado pela API', False, True)]
    property Id: Integer read FId write FId;
  end;

  [SwagClass('VenueRequest')]
  TVenueRequestDoc = class
  private
    FName: string;
    FAddress: string;
    FCity: string;
    FState: string;
    FCapacity: Integer;
  public
    [SwagProp('Nome do local', True)]
    property Name: string read FName write FName;
    [SwagProp('Endereço', True)]
    property Address: string read FAddress write FAddress;
    [SwagProp('Cidade', True)]
    property City: string read FCity write FCity;
    [SwagProp('UF com duas letras, por exemplo MG', True)]
    [SwagString(2, 2)]
    property State: string read FState write FState;
    [SwagProp('Quantas pessoas o local comporta', True)]
    property Capacity: Integer read FCapacity write FCapacity;
  end;

  [SwagClass('Venue')]
  TVenueDoc = class(TVenueRequestDoc)
  private
    FId: Integer;
  public
    [SwagProp('Identificador gerado pela API', False, True)]
    property Id: Integer read FId write FId;
  end;

  [SwagClass('EventRequest')]
  TEventRequestDoc = class
  private
    FName: string;
    FDescription: string;
    FCategoryId: Integer;
    FVenueId: Integer;
    FStartAt: string;
  public
    [SwagProp('Nome do evento', True)]
    [SwagString(150, 1)]
    property Name: string read FName write FName;
    [SwagProp('Descrição livre', False)]
    property Description: string read FDescription write FDescription;
    [SwagProp('Id de uma categoria existente', True)]
    property CategoryId: Integer read FCategoryId write FCategoryId;
    [SwagProp('Id de um local existente', True)]
    property VenueId: Integer read FVenueId write FVenueId;
    [SwagProp('Início do evento, aaaa-mm-ddThh:mm:ss, no futuro', True)]
    property StartAt: string read FStartAt write FStartAt;
  end;

  [SwagClass('EventCategory')]
  TEventCategoryDoc = class
  private
    FId: Integer;
    FName: string;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

  [SwagClass('EventVenue')]
  TEventVenueDoc = class
  private
    FId: Integer;
    FName: string;
    FCity: string;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property City: string read FCity write FCity;
  end;

  [SwagClass('Event')]
  TEventDoc = class
  private
    FId: Integer;
    FName: string;
    FDescription: string;
    FStartAt: string;
    FStatus: string;
    FCategory: TEventCategoryDoc;
    FVenue: TEventVenueDoc;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    [SwagProp('Início do evento, aaaa-mm-ddThh:mm:ss', True)]
    property StartAt: string read FStartAt write FStartAt;
    [SwagProp('DRAFT, PUBLISHED ou CANCELLED', True)]
    property Status: string read FStatus write FStatus;
    property Category: TEventCategoryDoc read FCategory write FCategory;
    property Venue: TEventVenueDoc read FVenue write FVenue;
  end;

  [SwagClass('BatchRequest')]
  TBatchRequestDoc = class
  private
    FName: string;
    FPrice: Currency;
    FQuantity: Integer;
    FSalesStart: string;
    FSalesEnd: string;
  public
    [SwagProp('Nome do lote, por exemplo "1º lote"', True)]
    property Name: string read FName write FName;
    [SwagProp('Preço em reais; zero para ingressos gratuitos', True)]
    property Price: Currency read FPrice write FPrice;
    [SwagProp('Quantidade de ingressos; a soma dos lotes não passa da capacidade do local', True)]
    property Quantity: Integer read FQuantity write FQuantity;
    [SwagProp('Início das vendas, aaaa-mm-ddThh:mm:ss', True)]
    property SalesStart: string read FSalesStart write FSalesStart;
    [SwagProp('Fim das vendas, até o início do evento', True)]
    property SalesEnd: string read FSalesEnd write FSalesEnd;
  end;

  [SwagClass('Batch')]
  TBatchDoc = class(TBatchRequestDoc)
  private
    FId: Integer;
    FEventId: Integer;
  public
    [SwagProp('Identificador gerado pela API', False, True)]
    property Id: Integer read FId write FId;
    property EventId: Integer read FEventId write FEventId;
  end;

  [SwagClass('EventDetail')]
  TEventDetailDoc = class(TEventDoc)
  private
    FBatches: TObjectList<TBatchDoc>;
  public
    [SwagProp('Lotes de ingressos do evento', True)]
    property Batches: TObjectList<TBatchDoc> read FBatches write FBatches;
  end;

procedure Configure;

implementation

uses
  Horse.GBSwagger,
  Platform.Docs;

procedure Configure;
begin
  ConfigureSwagger('event-api',
    'Eventos, locais, categorias e lotes de ingressos da plataforma.');

  Swagger
    .Path('/categories')
      .Tag('Categorias')
      .GET('Lista as categorias')
        .AddResponse(200, 'Categorias em ordem alfabética').Schema(TCategoryDoc).IsArray(True).&End
      .&End
      .POST('Cria uma categoria')
        .AddParamBody('body', 'Dados da categoria').Schema(TCategoryRequestDoc).&End
        .AddResponse(201, 'Categoria criada').Schema(TCategoryDoc).&End
        .AddResponse(400).&End
        .AddResponse(409, 'Já existe uma categoria com este nome').&End
      .&End
    .&End

    .Path('/venues')
      .Tag('Locais')
      .GET('Lista os locais')
        .AddParamQuery('city', 'Filtra pela cidade').Schema(SWAG_STRING).&End
        .AddResponse(200, 'Locais encontrados').Schema(TVenueDoc).IsArray(True).&End
      .&End
      .POST('Cria um local')
        .AddParamBody('body', 'Dados do local').Schema(TVenueRequestDoc).&End
        .AddResponse(201, 'Local criado').Schema(TVenueDoc).&End
        .AddResponse(400).&End
      .&End
    .&End
    .Path('/venues/{id}')
      .Tag('Locais')
      .GET('Busca um local pelo id')
        .AddParamPath('id', 'Id do local').Schema(SWAG_INTEGER).Required(True).&End
        .AddResponse(200, 'Local encontrado').Schema(TVenueDoc).&End
        .AddResponse(400).&End
        .AddResponse(404).&End
      .&End
    .&End

    .Path('/events')
      .Tag('Eventos')
      .GET('Lista os eventos', 'Sem o filtro status, mostra apenas os eventos publicados.')
        .AddParamQuery('city', 'Cidade do local').Schema(SWAG_STRING).&End
        .AddParamQuery('category', 'Id da categoria').Schema(SWAG_INTEGER).&End
        .AddParamQuery('from', 'Eventos a partir desta data, aaaa-mm-dd').Schema(SWAG_STRING).&End
        .AddParamQuery('to', 'Eventos até esta data, inclusive, aaaa-mm-dd').Schema(SWAG_STRING).&End
        .AddParamQuery('status', 'draft, published (padrão), cancelled ou all').Schema(SWAG_STRING).&End
        .AddResponse(200, 'Eventos encontrados').Schema(TEventDoc).IsArray(True).&End
        .AddResponse(400).&End
      .&End
      .POST('Cria um evento em rascunho')
        .AddParamBody('body', 'Dados do evento').Schema(TEventRequestDoc).&End
        .AddResponse(201, 'Evento criado com status DRAFT').Schema(TEventDoc).&End
        .AddResponse(400).&End
        .AddResponse(422, 'O evento precisa começar em uma data futura').&End
      .&End
    .&End
    .Path('/events/{id}')
      .Tag('Eventos')
      .GET('Busca um evento com os seus lotes')
        .AddParamPath('id', 'Id do evento').Schema(SWAG_INTEGER).Required(True).&End
        .AddResponse(200, 'Evento encontrado').Schema(TEventDetailDoc).&End
        .AddResponse(400).&End
        .AddResponse(404).&End
      .&End
    .&End
    .Path('/events/{id}/publish')
      .Tag('Eventos')
      .POST('Publica um evento', 'O evento precisa estar em rascunho, ter ao menos um lote e não ter começado.')
        .AddParamPath('id', 'Id do evento').Schema(SWAG_INTEGER).Required(True).&End
        .AddResponse(200, 'Evento publicado').Schema(TEventDoc).&End
        .AddResponse(404).&End
        .AddResponse(409, 'O evento não está em rascunho').&End
        .AddResponse(422).&End
      .&End
    .&End
    .Path('/events/{id}/batches')
      .Tag('Eventos')
      .GET('Lista os lotes de um evento')
        .AddParamPath('id', 'Id do evento').Schema(SWAG_INTEGER).Required(True).&End
        .AddResponse(200, 'Lotes do evento').Schema(TBatchDoc).IsArray(True).&End
        .AddResponse(404).&End
      .&End
      .POST('Cria um lote de ingressos')
        .AddParamPath('id', 'Id do evento').Schema(SWAG_INTEGER).Required(True).&End
        .AddParamBody('body', 'Dados do lote').Schema(TBatchRequestDoc).&End
        .AddResponse(201, 'Lote criado').Schema(TBatchDoc).&End
        .AddResponse(400).&End
        .AddResponse(404).&End
        .AddResponse(409, 'O evento está cancelado').&End
        .AddResponse(422, 'Datas de venda ou capacidade do local').&End
      .&End
    .&End;
end;

end.
