unit CustomerApi.Entity.Customer;

interface

type
  TCustomer = class
  private
    FId: Integer;
    FName: string;
    FCpf: string;
    FEmail: string;
    FPhone: string;
    FBirthDate: TDate;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
    FLegacyCode: Integer;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    // Somente os 11 dígitos, sem pontos nem traço.
    property Cpf: string read FCpf write FCpf;
    property Email: string read FEmail write FEmail;
    // Somente dígitos: DDD + número.
    property Phone: string read FPhone write FPhone;
    // Zero quando não informada.
    property BirthDate: TDate read FBirthDate write FBirthDate;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
    // Capítulo 22: o código do cliente no sistema antigo (COD_CLI). Zero
    // quando o participante nasceu na plataforma nova.
    property LegacyCode: Integer read FLegacyCode write FLegacyCode;
  end;

implementation

end.
