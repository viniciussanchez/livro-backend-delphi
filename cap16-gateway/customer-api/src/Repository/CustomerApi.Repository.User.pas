unit CustomerApi.Repository.User;

{ Contas de acesso: equipe (admin, staff) e participantes (customer). }

interface

type
  TUserAccount = record
    Id: Integer;
    Role: string;
    CustomerId: Integer;
  end;

  IUserRepository = interface
    ['{7A1C93E5-4D28-4B6F-9E30-B5C8D17F2A46}']
    // Confere e-mail e senha. A senha nunca é comparada no Delphi: o banco
    // calcula o hash com o mesmo "sal" guardado e compara.
    function FindByCredentials(const AEmail, APassword: string; out AAccount: TUserAccount): Boolean;
    // Para participantes, AEmail fica vazio: o login usa o e-mail do cadastro.
    procedure Insert(const AEmail, APassword, ARole: string; const ACustomerId: Integer;
      const ANow: TDateTime);
    // E-mail usado por alguém da equipe ou por um participante ativo.
    function EmailInUse(const AEmail: string): Boolean;
    function AdminExists: Boolean;
  end;

implementation

end.
