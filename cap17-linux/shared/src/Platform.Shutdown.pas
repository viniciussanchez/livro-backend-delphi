unit Platform.Shutdown;

(* Encerramento organizado do serviço.

  Quem pede para o serviço parar:
    - você, com Ctrl+C no terminal (Windows ou Linux);
    - o systemd ou o Docker, com o sinal SIGTERM (Linux).

  Sem este cuidado, cada sistema faz uma coisa: o Windows mata o processo
  na hora, no meio de uma compra; o Linux também; e dentro de um contêiner
  o SIGTERM é simplesmente ignorado, e o Docker espera 10 segundos antes
  de matar o processo à força (capítulo 18).

  Com ele, o serviço para de aceitar conexões, espera as requisições em
  andamento terminarem (até ADrainMs) e só então sai, passando pelas
  seções finalization de todas as units, que fecham o pool do banco. *)

interface

// Chame no início do programa, antes de THorse.Listen e de criar threads.
procedure EnableGracefulShutdown(const AServiceName: string; const ADrainMs: Integer = 5000);

implementation

uses
  System.SysUtils,
  System.Classes,
  Horse
{$IFDEF MSWINDOWS}
  , Winapi.Windows
{$ENDIF}
{$IFDEF POSIX}
  , Posix.Signal
{$ENDIF}
  ;

var
  GServiceName: string;
  GDrainMs: Integer;
  GStopping: Integer = 0;

procedure StopService(const AReason: string);
begin
  // Dois Ctrl+C seguidos não podem disparar duas paradas.
  if AtomicExchange(GStopping, 1) = 1 then
    Exit;
  Writeln(Format('%s: %s recebido, encerrando (aguardando até %d ms)...',
    [GServiceName, AReason, GDrainMs]));
  Flush(Output);
  THorse.StopListenGraceful(GDrainMs);
end;

{$IFDEF MSWINDOWS}
// O Windows chama esta função em uma thread própria quando o console
// recebe Ctrl+C, Ctrl+Break ou é fechado.
function ConsoleHandler(ACtrlType: DWORD): BOOL; stdcall;
begin
  case ACtrlType of
    CTRL_C_EVENT, CTRL_BREAK_EVENT, CTRL_CLOSE_EVENT:
      begin
        StopService('Ctrl+C');
        Result := True;
      end;
  else
    Result := False;
  end;
end;

procedure InstallHandler;
begin
  SetConsoleCtrlHandler(@ConsoleHandler, True);
end;
{$ENDIF}

{$IFDEF POSIX}
(* No Linux, um sinal pode chegar a qualquer momento, em qualquer thread,
  interrompendo o que ela estiver fazendo. Dentro de um tratador de sinal
  quase nada é seguro de chamar: nem Writeln, nem alocar memória.

  Por isso usamos outro caminho: bloqueamos SIGTERM e SIGINT em todas as
  threads e deixamos uma thread dedicada esperando por eles com sigwait.
  Para ela, o sinal chega como o retorno de uma função comum, e ali
  podemos fazer o que quisermos. *)
type
  TSignalThread = class(TThread)
  private
    FSignals: sigset_t;
  protected
    procedure Execute; override;
  public
    constructor Create(const ASignals: sigset_t);
  end;

constructor TSignalThread.Create(const ASignals: sigset_t);
begin
  FSignals := ASignals;
  FreeOnTerminate := True;
  inherited Create(False);
end;

procedure TSignalThread.Execute;
var
  LSignal: Integer;
begin
  LSignal := 0;
  if sigwait(FSignals, @LSignal) <> 0 then
    Exit;
  if LSignal = SIGTERM then
    StopService('SIGTERM')
  else
    StopService('SIGINT (Ctrl+C)');
end;

procedure InstallHandler;
var
  LSignals: sigset_t;
begin
  sigemptyset(LSignals);
  sigaddset(LSignals, SIGTERM);
  sigaddset(LSignals, SIGINT);
  // A máscara vale para esta thread e para as que ela criar depois:
  // por isso o pedido de chamar antes de o Horse abrir as suas.
  pthread_sigmask(SIG_BLOCK, @LSignals, nil);
  TSignalThread.Create(LSignals);
end;
{$ENDIF}

procedure EnableGracefulShutdown(const AServiceName: string; const ADrainMs: Integer);
begin
  GServiceName := AServiceName;
  GDrainMs := ADrainMs;
  InstallHandler;
end;

end.
