unit CustomerApi.Docs;

{ Documentação Swagger da customer-api.
  Acesse http://localhost:9002/swagger/doc/html com a API no ar. }

interface

uses
  GBSwagger.Model.Attributes;

type
  [SwagClass('CustomerRequest')]
  TCustomerRequestDoc = class
  private
    FCpf: string;
    FName: string;
    FEmail: string;
    FPhone: string;
    FBirthDate: string;
  public
    [SwagProp('CPF, com ou sem pontuação. Obrigatório no cadastro e ignorado na alteração', True)]
    property Cpf: string read FCpf write FCpf;
    [SwagProp('Nome completo', True)]
    [SwagString(150, 1)]
    property Name: string read FName write FName;
    [SwagProp('E-mail, único na plataforma', True)]
    property Email: string read FEmail write FEmail;
    [SwagProp('Telefone com DDD, por exemplo (31) 99999-8888', False)]
    property Phone: string read FPhone write FPhone;
    [SwagProp('Data de nascimento, aaaa-mm-dd', False)]
    property BirthDate: string read FBirthDate write FBirthDate;
  end;

  [SwagClass('Customer')]
  TCustomerDoc = class
  private
    FId: Integer;
    FName: string;
    FCpf: string;
    FEmail: string;
    FPhone: string;
    FBirthDate: string;
    FCreatedAt: string;
    FUpdatedAt: string;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    [SwagProp('CPF mascarado, por exemplo ***.982.247-**', True)]
    property Cpf: string read FCpf write FCpf;
    property Email: string read FEmail write FEmail;
    [SwagProp('Somente dígitos; null quando não informado', False)]
    property Phone: string read FPhone write FPhone;
    [SwagProp('aaaa-mm-dd; null quando não informada', False)]
    property BirthDate: string read FBirthDate write FBirthDate;
    property CreatedAt: string read FCreatedAt write FCreatedAt;
    property UpdatedAt: string read FUpdatedAt write FUpdatedAt;
  end;

procedure Configure;

implementation

uses
  Horse.GBSwagger,
  Platform.Docs;

procedure Configure;
begin
  ConfigureSwagger('customer-api',
    'Participantes da plataforma. Dados pessoais protegidos pela LGPD: ' +
    'o CPF sai sempre mascarado e a exclusão anonimiza o cadastro.');

  Swagger
    .Path('/customers')
      .Tag('Participantes')
      .GET('Busca participantes por CPF ou e-mail',
        'Não existe listagem geral: informe cpf ou email. Devolve uma lista com zero ou um participante.')
        .AddParamQuery('cpf', 'CPF, com ou sem pontuação').Schema(SWAG_STRING).&End
        .AddParamQuery('email', 'E-mail').Schema(SWAG_STRING).&End
        .AddResponse(200, 'Resultado da busca').Schema(TCustomerDoc).IsArray(True).&End
        .AddResponse(400).&End
      .&End
      .POST('Cadastra um participante')
        .AddParamBody('body', 'Dados do participante').Schema(TCustomerRequestDoc).&End
        .AddResponse(201, 'Participante cadastrado').Schema(TCustomerDoc).&End
        .AddResponse(400).&End
        .AddResponse(409, 'CPF ou e-mail já cadastrado').&End
      .&End
    .&End
    .Path('/customers/{id}')
      .Tag('Participantes')
      .GET('Busca um participante pelo id')
        .AddParamPath('id', 'Id do participante').Schema(SWAG_INTEGER).Required(True).&End
        .AddResponse(200, 'Participante encontrado').Schema(TCustomerDoc).&End
        .AddResponse(400).&End
        .AddResponse(404).&End
      .&End
      .PUT('Altera um participante', 'O CPF não pode ser alterado.')
        .AddParamPath('id', 'Id do participante').Schema(SWAG_INTEGER).Required(True).&End
        .AddParamBody('body', 'Novos dados do participante').Schema(TCustomerRequestDoc).&End
        .AddResponse(200, 'Participante alterado').Schema(TCustomerDoc).&End
        .AddResponse(400).&End
        .AddResponse(404).&End
        .AddResponse(409, 'E-mail já usado por outro participante').&End
      .&End
      .DELETE('Exclui um participante', 'Os dados pessoais são anonimizados; o histórico de compras continua íntegro.')
        .AddParamPath('id', 'Id do participante').Schema(SWAG_INTEGER).Required(True).&End
        .AddResponse(204, 'Participante excluído').&End
        .AddResponse(404).&End
      .&End
    .&End;
end;

end.
