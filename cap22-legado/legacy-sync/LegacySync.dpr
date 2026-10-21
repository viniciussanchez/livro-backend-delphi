program LegacySync;

{ Sincronização do sistema antigo da bilheteria com a plataforma nova
  (capítulo 22). Lê a fila SYNC_FILA no banco antigo e leva cada cliente
  incluído ou alterado lá para a customer-api.

  É um serviço como os outros: configuração, log, métricas, /health e
  encerramento com calma vêm das units compartilhadas. A diferença é que,
  além de responder HTTP, ele tem threads trabalhando o tempo todo. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.Jhonson,
  Platform.Exceptions in '..\shared\src\Platform.Exceptions.pas',
  Platform.Config in '..\shared\src\Platform.Config.pas',
  Platform.Dates in '..\shared\src\Platform.Dates.pas',
  Platform.Http in '..\shared\src\Platform.Http.pas',
  Platform.Log in '..\shared\src\Platform.Log.pas',
  Platform.Metrics in '..\shared\src\Platform.Metrics.pas',
  Platform.Middleware.Observability in '..\shared\src\Platform.Middleware.Observability.pas',
  Platform.SecureRandom in '..\shared\src\Platform.SecureRandom.pas',
  Platform.Middleware.Errors in '..\shared\src\Platform.Middleware.Errors.pas',
  Platform.Shutdown in '..\shared\src\Platform.Shutdown.pas',
  Platform.HealthCheck in '..\shared\src\Platform.HealthCheck.pas',
  Platform.Jwt in '..\shared\src\Platform.Jwt.pas',
  Platform.Auth in '..\shared\src\Platform.Auth.pas',
  Platform.Integration in '..\shared\src\Platform.Integration.pas',
  Platform.Transactions in '..\shared\src\Platform.Transactions.pas',
  Platform.Database in '..\shared\src\Platform.Database.pas',
  Platform.Health in '..\shared\src\Platform.Health.pas',
  LegacySync.Translator in 'src\LegacySync.Translator.pas',
  LegacySync.Queue in 'src\LegacySync.Queue.pas',
  LegacySync.CustomerClient in 'src\LegacySync.CustomerClient.pas',
  LegacySync.Worker in 'src\LegacySync.Worker.pas',
  LegacySync.Controller in 'src\LegacySync.Controller.pas';

procedure CheckQueueTable;
var
  LSession: IDbSession;
  LQueue: TLegacyQueue;
begin
  LSession := TDatabase.NewSession(LEGACY_DB);
  LQueue := TLegacyQueue.Create(LSession.Connection);
  try
    if not LQueue.QueueExists then
      raise EConfigException.Create(
        'A tabela SYNC_FILA não existe no banco do sistema antigo. Rode legacy/sql/03-sincronizacao.sql.');
  finally
    LQueue.Free;
  end;
end;

begin
  if RunHealthCheckIfRequested('9004', [200]) then
    Exit;

  EnableGracefulShutdown('legacy-sync');
  try
    // DB_HOST, DB_USER e DB_PASSWORD (de CommonSettings) apontam para o
    // servidor do sistema antigo. Este serviço não tem banco próprio.
    TConfig.Load(CommonSettings + [
      TSetting.New('PORT', '9004'),
      TSetting.New('LEGACY_DB_NAME', 'bilheteria'),
      TSetting.New('CUSTOMER_API_URL', 'http://127.0.0.1:9002'),
      TSetting.New('SERVICE_TIMEOUT_MS', '2000'),
      TSetting.New('SYNC_WORKERS', '2'),
      TSetting.New('SYNC_IDLE_MS', '1000')
    ]);
    TLog.Configure('legacy-sync', TConfig.Value('LOG_FORMAT'), TConfig.IsProduction);
    TConfig.PrintSummary('legacy-sync');
    ConfigureAuth(TConfig.Value('JWT_SECRET'), 'legacy-sync');
    TDatabase.Configure(LEGACY_DB, TConfig.Value('LEGACY_DB_NAME'), 'legacy-sync');
    CheckQueueTable;
  except
    on E: EConfigException do
    begin
      TLog.Error(E.Message);
      ExitCode := 2;
      Exit;
    end;
    on E: Exception do
    begin
      TLog.Error('falha ao acessar o banco do sistema antigo', [F('detail', E.Message)]);
      ExitCode := 1;
      Exit;
    end;
  end;

  THorse.Use(Observability);
  THorse.Use(ErrorHandler);
  THorse.Use(Jhonson('UTF-8', InvalidJsonHandler));

  LegacySync.Controller.Registry;
  RegisterHealthCheck('legacy-sync', LEGACY_DB);
  RegisterMetricsEndpoint;

  TSyncWorkers.Start(TConfig.IntValue('SYNC_WORKERS'), TConfig.IntValue('SYNC_IDLE_MS'),
    TConfig.Value('CUSTOMER_API_URL'), TConfig.IntValue('SERVICE_TIMEOUT_MS'));

  THorse.Listen(TConfig.IntValue('PORT'),
    procedure
    begin
      TLog.Info('legacy-sync no ar', [F('port', THorse.Port)]);
    end,
    procedure
    begin
      // Para as threads antes de o processo terminar: o item em andamento
      // é concluído (ou desfeito) e nada fica pela metade.
      TSyncWorkers.Stop;
      TLog.Info('legacy-sync encerrada');
    end);
end.
