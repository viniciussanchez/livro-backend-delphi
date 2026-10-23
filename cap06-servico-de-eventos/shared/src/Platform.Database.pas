unit Platform.Database;

{ Configuração do FireDAC para o PostgreSQL, com pool de conexões.

  Cada requisição abre uma sessão, que pega uma conexão do pool. Todos os
  repositórios da requisição usam essa mesma conexão. Quando o último
  repositório deixa de ser usado, a sessão é liberada e a conexão volta ao pool. }

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client;

type
  IDbSession = interface
    ['{5E0B8C3A-7D21-4F96-B4A8-2C6E91F03D7B}']
    function Connection: TFDConnection;
    // Executa AProc em uma transação: commit se der certo, rollback se falhar.
    procedure InTransaction(const AProc: TProc);
  end;

  TDatabase = class
  public
    // Registra uma definição de conexão com pool. Chamar uma vez, na inicialização.
    class procedure Configure(const AConnectionDefName, ADatabaseName, AApplicationName: string); static;
    // Pega uma conexão do pool. Liberar com Free devolve a conexão ao pool.
    class function NewConnection(const AConnectionDefName: string): TFDConnection; static;
    // Abre uma sessão (uma conexão do pool) para a requisição atual.
    class function NewSession(const AConnectionDefName: string): IDbSession; static;
  end;

implementation

uses
  System.Classes,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Stan.Pool,
  FireDAC.Phys,
  FireDAC.Phys.PG,
  FireDAC.Phys.PGDef,
  FireDAC.DApt,
  FireDAC.ConsoleUI.Wait;

type
  TDbSession = class(TInterfacedObject, IDbSession)
  private
    FConnectionDefName: string;
    FConnection: TFDConnection;
  public
    constructor Create(const AConnectionDefName: string);
    destructor Destroy; override;
    function Connection: TFDConnection;
    procedure InTransaction(const AProc: TProc);
  end;

var
  GDriverLink: TFDPhysPgDriverLink;

// Lê uma variável de ambiente ou devolve o valor padrão.
// O capítulo 14 trata configuração com mais cuidado.
function EnvOrDefault(const AName, ADefault: string): string;
begin
  Result := GetEnvironmentVariable(AName);
  if Result.IsEmpty then
    Result := ADefault;
end;

{ TDbSession }

constructor TDbSession.Create(const AConnectionDefName: string);
begin
  inherited Create;
  // A conexão só sai do pool quando alguém precisa dela (veja Connection).
  // Assim, um serviço que conversa com outros pela rede antes de tocar no
  // banco não segura uma conexão enquanto espera a resposta (capítulo 12).
  FConnectionDefName := AConnectionDefName;
end;

destructor TDbSession.Destroy;
begin
  // Em uma conexão com pool, Free devolve a conexão física ao pool.
  FConnection.Free;
  inherited;
end;

function TDbSession.Connection: TFDConnection;
begin
  // Uma sessão é usada por uma única requisição, numa única thread:
  // não há corrida aqui.
  if not Assigned(FConnection) then
    FConnection := TDatabase.NewConnection(FConnectionDefName);
  Result := FConnection;
end;

procedure TDbSession.InTransaction(const AProc: TProc);
begin
  Connection.StartTransaction;
  try
    AProc();
    Connection.Commit;
  except
    Connection.Rollback;
    raise;
  end;
end;

{ TDatabase }

class procedure TDatabase.Configure(const AConnectionDefName, ADatabaseName, AApplicationName: string);
var
  LParams: TStringList;
begin
  LParams := TStringList.Create;
  try
    LParams.Values['Server'] := EnvOrDefault('DB_HOST', 'localhost');
    LParams.Values['Port'] := EnvOrDefault('DB_PORT', '5432');
    LParams.Values['Database'] := ADatabaseName;
    LParams.Values['User_Name'] := EnvOrDefault('DB_USER', 'eventos');
    LParams.Values['Password'] := EnvOrDefault('DB_PASSWORD', 'eventos');
    LParams.Values['CharacterSet'] := 'UTF8';
    LParams.Values['ApplicationName'] := AApplicationName;
    LParams.Values['Pooled'] := 'True';
    LParams.Values['POOL_MaximumItems'] := EnvOrDefault('DB_POOL_SIZE', '50');
    FDManager.AddConnectionDef(AConnectionDefName, 'PG', LParams);
  finally
    LParams.Free;
  end;
end;

class function TDatabase.NewConnection(const AConnectionDefName: string): TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.ConnectionDefName := AConnectionDefName;
    Result.Connected := True;
  except
    Result.Free;
    raise;
  end;
end;

class function TDatabase.NewSession(const AConnectionDefName: string): IDbSession;
begin
  Result := TDbSession.Create(AConnectionDefName);
end;

initialization
  // A libpq.dll precisa estar no PATH ou na pasta do executável.
  // PG_LIB permite apontar um caminho específico.
  GDriverLink := TFDPhysPgDriverLink.Create(nil);
  GDriverLink.VendorLib := EnvOrDefault('PG_LIB', 'libpq.dll');
  FDManager.SilentMode := True;

finalization
  FDManager.Close;
  GDriverLink.Free;

end.
