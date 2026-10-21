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
    FPassword: string;
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
    [SwagProp('Senha de acesso, com pelo menos 8 caracteres. Obrigatória no cadastro', False)]
    property Password: string read FPassword write FPassword;
  end;

  [SwagClass('TokenRequest')]
  TTokenRequestDoc = class
  private
    FEmail: string;
    FPassword: string;
  public
    [SwagProp('E-mail de acesso', True)]
    property Email: string read FEmail write FEmail;
    [SwagProp('Senha', True)]
    property Password: string read FPassword write FPassword;
  end;

  [SwagClass('Token')]
  TTokenDoc = class
  private
    FAccessToken: string;
    FTokenType: string;
    FExpiresIn: Integer;
    FRole: string;
  public
    [SwagProp('JWT para enviar no cabeçalho Authorization: Bearer', True)]
    property AccessToken: string read FAccessToken write FAccessToken;
    [SwagProp('Sempre Bearer', True)]
    property TokenType: string read FTokenType write FTokenType;
    [SwagProp('Validade em segundos', True)]
    property ExpiresIn: Integer read FExpiresIn write FExpiresIn;
    [SwagProp('admin, staff ou customer', True)]
    property Role: string read FRole write FRole;
  end;

  [SwagClass('StaffUserRequest')]
  TStaffUserRequestDoc = class(TTokenRequestDoc)
  private
    FRole: string;
  public
    [SwagProp('admin ou staff', True)]
    property Role: string read FRole write FRole;
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
        'Somente admin ou outro serviço. Não existe listagem geral: informe cpf ou email.')
        .AddParamQuery('cpf', 'CPF, com ou sem pontuação').Schema(SWAG_STRING).&End
        .AddParamQuery('email', 'E-mail').Schema(SWAG_STRING).&End
        .AddResponse(200, 'Resultado da busca').Schema(TCustomerDoc).IsArray(True).&End
        .AddResponse(400).&End
      .&End
      .POST('Cadastra um participante', 'Rota pública: cria o cadastro e o acesso do participante.')
        .IsPublic(True)
        .AddParamBody('body', 'Dados do participante').Schema(TCustomerRequestDoc).&End
        .AddResponse(201, 'Participante cadastrado').Schema(TCustomerDoc).&End
        .AddResponse(400).&End
        .AddResponse(409, 'CPF ou e-mail já cadastrado').&End
      .&End
    .&End
    .Path('/customers/{id}')
      .Tag('Participantes')
      .GET('Busca um participante pelo id', 'O participante só enxerga o próprio cadastro; admin e serviços enxergam todos.')
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
    .&End

    .Path('/auth/token')
      .Tag('Acesso')
      .POST('Gera um token de acesso', 'Rota pública. O token vale por uma hora.')
        .IsPublic(True)
        .AddParamBody('body', 'Credenciais').Schema(TTokenRequestDoc).&End
        .AddResponse(200, 'Token gerado').Schema(TTokenDoc).&End
        .AddResponse(401, 'E-mail ou senha inválidos').&End
      .&End
    .&End
    .Path('/users')
      .Tag('Acesso')
      .POST('Cria uma conta da equipe', 'Somente admin.')
        .AddParamBody('body', 'Dados da conta').Schema(TStaffUserRequestDoc).&End
        .AddResponse(201, 'Conta criada').&End
        .AddResponse(400).&End
        .AddResponse(401).&End
        .AddResponse(403).&End
        .AddResponse(409, 'E-mail já em uso').&End
      .&End
    .&End;
end;

end.
