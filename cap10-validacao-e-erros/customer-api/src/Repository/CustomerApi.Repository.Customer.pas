unit CustomerApi.Repository.Customer;

interface

uses
  CustomerApi.Entity.Customer;

type
  ICustomerRepository = interface
    ['{A71C3E58-2D94-4B06-9F1E-6C8B0D25E3A7}']
    // Todas as buscas ignoram participantes anonimizados.
    // Retornam nil quando não encontram. Quem chama é dono do objeto.
    function FindById(const AId: Integer): TCustomer;
    function FindByCpf(const ACpf: string): TCustomer;
    function FindByEmail(const AEmail: string): TCustomer;
    // AExceptId permite ignorar o próprio participante em uma atualização.
    function EmailInUse(const AEmail: string; const AExceptId: Integer = 0): Boolean;
    function CpfInUse(const ACpf: string): Boolean;
    procedure Insert(const ACustomer: TCustomer);
    procedure Update(const ACustomer: TCustomer);
    // Apaga os dados pessoais e mantém só o registro técnico. Retorna False se não existir.
    function Anonymize(const AId: Integer; const AWhen: TDateTime): Boolean;
  end;

implementation

end.
