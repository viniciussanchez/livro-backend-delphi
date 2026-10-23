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
  Platform.Exceptions,
  System.Classes,
  System.Diagnostics,
  FireDAC.Stan.Error,
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
  GPoolWaitMs: Integer = 3000;

const
  // Código do FireDAC para "todas as conexões do pool estão em uso".
  FD_POOL_EXHAUSTED = 708;

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
    GPoolWaitMs := TConfig.IntValue('DB_POOL_WAIT_MS');
  finally
    LParams.Free;
  end;
end;

class function TDatabase.NewConnection(const AConnectionDefName: string): TFDConnection;
var
  LWatch: TStopwatch;
begin
  // Capítulo 20: quando todas as conexões do pool estão em uso, o FireDAC
  // não espera, ele falha na hora (erro 708). Aqui transformamos isso numa
  // fila: tentamos de novo por até DB_POOL_WAIT_MS. Se ainda assim não
  // houver conexão livre, respondemos 503, e não um 500 genérico.
  LWatch := TStopwatch.StartNew;
  while True do
  begin
    Result := TFDConnection.Create(nil);
    try
      Result.ConnectionDefName := AConnectionDefName;
      Result.Connected := True;
      Exit;
    except
      on E: EFDException do
      begin
        FreeAndNil(Result);
        if E.FDCode <> FD_POOL_EXHAUSTED then
          raise;
        if LWatch.ElapsedMilliseconds >= GPoolWaitMs then
          raise EServiceUnavailableException.Create(
            'O serviço está com todas as conexões ao banco ocupadas. Tente de novo em instantes.');
        Sleep(20);
      end;
      on E: Exception do
      begin
        FreeAndNil(Result);
        raise;
      end;
    end;
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
