unit Platform.Docs;

{ Configuração do Swagger comum aos três serviços: informações gerais,
  nomes em camelCase e o formato Problem Details de todas as respostas
  de erro (capítulo 10). Cada serviço descreve as próprias rotas na
  sua unit <Servico>.Docs. }

interface

uses
  System.Generics.Collections,
  GBSwagger.Model.Attributes;

type
  // As classes "Doc" existem só para descrever o JSON na documentação.
  // Nenhuma delas é criada em tempo de execução: o GBSwagger lê as
  // propriedades por RTTI.

  [SwagClass('FieldError')]
  TFieldErrorDoc = class
  private
    FField: string;
    FMessage: string;
  public
    [SwagProp('Nome do campo, igual ao do JSON enviado', True)]
    property Field: string read FField write FField;
    [SwagProp('O que está errado e como corrigir', True)]
    property Message: string read FMessage write FMessage;
  end;

  [SwagClass('Problem')]
  TProblemDoc = class
  private
    FType: string;
    FTitle: string;
    FStatus: Integer;
    FDetail: string;
    FInstance: string;
    FCode: string;
    FErrors: TObjectList<TFieldErrorDoc>;
    FErrorId: string;
  public
    [SwagProp('Tipo do problema, por exemplo /problems/not-found', True)]
    property &Type: string read FType write FType;
    [SwagProp('Resumo do tipo de problema', True)]
    property Title: string read FTitle write FTitle;
    [SwagProp('Status HTTP', True)]
    property Status: Integer read FStatus write FStatus;
    [SwagProp('Explicação desta ocorrência', True)]
    property Detail: string read FDetail write FDetail;
    [SwagProp('Caminho da requisição que falhou', False)]
    property Instance: string read FInstance write FInstance;
    [SwagProp('Código estável para uso em programas: validation-error, not-found, conflict, sold-out...', True)]
    property Code: string read FCode write FCode;
    [SwagProp('Campos inválidos, apenas em erros de validação', False)]
    property Errors: TObjectList<TFieldErrorDoc> read FErrors write FErrors;
    [SwagProp('Identificador para o suporte, apenas em erros 500', False)]
    property ErrorId: string read FErrorId write FErrorId;
  end;

// Configuração geral do documento. Chame antes de descrever as rotas.
procedure ConfigureSwagger(const ATitle, ADescription: string);

implementation

uses
  Horse.GBSwagger;

procedure ConfigureSwagger(const ATitle, ADescription: string);
begin
  Swagger
    .Config
      // Propriedades Pascal (CategoryId) viram camelCase no JSON (categoryId).
      .CaseDefinition(TCaseDefinition.cdLowerCamelCase)
    .&End
    .Info
      .Title(ATitle)
      .Description(ADescription)
      .Version('1.0')
      // O GBSwagger vem com uma licença de exemplo preenchida; limpamos.
      .TermsOfService('')
      .License.Name('').URL('').&End
    .&End
    // Respostas de erro que todas as rotas compartilham. Uma rota só
    // precisa dizer ".AddResponse(404).&End" para herdar a descrição.
    .Register
      .Response(400).Description('Dados inválidos').&End
      .Response(404).Description('Recurso não encontrado').&End
      .Response(409).Description('Conflito com o estado atual').&End
      .Response(422).Description('Regra de negócio não atendida').&End
      .Response(500).Description('Erro interno').&End
      // Todas as respostas de erro acima seguem o formato Problem Details.
      .SchemaOnError(TProblemDoc)
    .&End;
end;

end.
