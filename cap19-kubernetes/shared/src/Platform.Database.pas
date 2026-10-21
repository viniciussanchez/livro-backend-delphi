unit Platform.Database;

{ Configuração do FireDAC para o PostgreSQL, com pool de conexões.

  Cada requisição abre uma sessão, que pega uma conexão do pool. Todos os
  repositórios da requisição usam essa mesma conexão. Quando o último
  repositório deixa de ser usado, a sessão é liberada e a conexão volta ao pool. }

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  Platform.Transactions;

type
  // A sessão é também um escopo de transação (InTransaction vem de ITransactionScope).
  IDbSession = interface(ITransactionScope)
    ['{5E0B8C3A-7D21-4F96-B4A8-2C6E91F03D7B}']
    function Connection: TFDConnection;
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
  Platform.Config,
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
    FConnection: TFDConnection;
  public
    constructor Create(const AConnectionDefName: string);
    destructor Destroy; override;
    function Connection: TFDConnection;
    procedure InTransaction(const AProc: TProc);
  end;

var
  GDriverLink: TFDPhysPgDriverLink;

{ TDbSession }

constructor TDbSession.Create(const AConnectionDefName: string);
begin
  inherited Create;
  FConnection := TDatabase.NewConnection(AConnectionDefName);
end;

destructor TDbSession.Destroy;
begin
  // Em uma conexão com pool, Free devolve a conexão física ao pool.
  FConnection.Free;
  inherited;
end;

function TDbSession.Connection: TFDConnection;
begin
  Result := FConnection;
end;

procedure TDbSession.InTransaction(const AProc: TProc);
begin
  FConnection.StartTransaction;
  try
    AProc();
    FConnection.Commit;
  except
    FConnection.Rollback;
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
    // Os valores vêm de Platform.Config (capítulo 14).
    LParams.Values['Server'] := TConfig.Value('DB_HOST');
    LParams.Values['Port'] := TConfig.Value('DB_PORT');
    LParams.Values['Database'] := ADatabaseName;
    LParams.Values['User_Name'] := TConfig.Value('DB_USER');
    LParams.Values['Password'] := TConfig.Value('DB_PASSWORD');
    LParams.Values['CharacterSet'] := 'UTF8';
    LParams.Values['ApplicationName'] := AApplicationName;
    LParams.Values['Pooled'] := 'True';
    LParams.Values['POOL_MaximumItems'] := TConfig.Value('DB_POOL_SIZE');
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
{$IFDEF LINUX}
  // Capítulo 17. No Linux, a página de código "ANSI" do Delphi é UTF-8,
  // e não a 1252 do Windows. O FireDAC converte parâmetros do tipo ftString
  // (o tipo de AsString e dos valores passados em ExecSQL) passando por essa
  // página de código, e calcula errado o tamanho de textos acentuados:
  // o PostgreSQL recebe lixo no fim do texto ou recusa o comando.
  // Usar a 1252, como no Windows, faz o serviço se comportar igual nos dois.
  SetMultiByteConversionCodePage(1252);
  // O console continua em UTF-8, que é o que o terminal e o Docker esperam.
  SetTextCodePage(Output, CP_UTF8);
{$ENDIF}
  // A biblioteca cliente do PostgreSQL precisa estar no sistema.
  // PG_LIB permite apontar um caminho específico. É lida direto do ambiente
  // porque a unit é inicializada antes de o serviço carregar a configuração.
  GDriverLink := TFDPhysPgDriverLink.Create(nil);
  GDriverLink.VendorLib := GetEnvironmentVariable('PG_LIB');
  if GDriverLink.VendorLib = '' then
  {$IFDEF LINUX}
    // Capítulo 17: no Linux, o pacote libpq5 instala libpq.so.5. O nome sem
    // versão (libpq.so), que o FireDAC procuraria, só vem no pacote de
    // desenvolvimento, que não queremos em um servidor.
    GDriverLink.VendorLib := 'libpq.so.5';
  {$ELSE}
    GDriverLink.VendorLib := 'libpq.dll';
  {$ENDIF}
  FDManager.SilentMode := True;

finalization
  FDManager.Close;
  GDriverLink.Free;

end.
