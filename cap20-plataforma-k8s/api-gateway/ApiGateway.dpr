program ApiGateway;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Platform.Exceptions in '..\shared\src\Platform.Exceptions.pas',
  Platform.Config in '..\shared\src\Platform.Config.pas',
  Platform.Middleware.Errors in '..\shared\src\Platform.Middleware.Errors.pas',
  Platform.Shutdown in '..\shared\src\Platform.Shutdown.pas',
  Platform.HealthCheck in '..\shared\src\Platform.HealthCheck.pas',
  Gateway.Routes in 'src\Gateway.Routes.pas',
  Gateway.Proxy in 'src\Gateway.Proxy.pas',
  Gateway.Middleware in 'src\Gateway.Middleware.pas',
  Gateway.RateLimit in 'src\Gateway.RateLimit.pas',
  Gateway.Health in 'src\Gateway.Health.pas';

var
  LProxy: TProxySettings;

begin
  // Capítulo 18: "--healthcheck" é o Docker perguntando se estamos bem.
  // O gateway responde 503 quando um serviço atrás dele caiu, mas ele
  // mesmo continua de pé: para o Docker, 200 e 503 são "saudável".
  if RunHealthCheckIfRequested('9000', [200, 503]) then
    Exit;

  // Capítulo 17: Ctrl+C e SIGTERM encerram o serviço com calma.
  // Precisa vir antes de qualquer outra coisa que crie threads.
  EnableGracefulShutdown('api-gateway');
  try
    // O gateway não tem banco nem valida tokens: só precisa saber
    // onde estão os serviços e quais limites aplicar.
    TConfig.Load([
      TSetting.New('APP_ENV', 'development'),
      TSetting.New('PORT', '9000'),
      TSetting.New('MAX_CONNECTIONS', '200'),
      TSetting.New('EVENT_API_URL', 'http://127.0.0.1:9001'),
      TSetting.New('CUSTOMER_API_URL', 'http://127.0.0.1:9002'),
      TSetting.New('TICKET_API_URL', 'http://127.0.0.1:9003'),
      TSetting.New('UPSTREAM_CONNECT_TIMEOUT_MS', '2000'),
      TSetting.New('UPSTREAM_TIMEOUT_MS', '10000'),
      TSetting.New('CORS_ORIGINS', 'http://localhost:5173', False, True),
      TSetting.New('LOGIN_MAX_ATTEMPTS', '5'),
      TSetting.New('LOGIN_WINDOW_SECONDS', '60')
    ]);
    TConfig.PrintSummary('api-gateway');

    TRouteTable.Build(TConfig.Value('EVENT_API_URL'), TConfig.Value('CUSTOMER_API_URL'),
      TConfig.Value('TICKET_API_URL'));
    LProxy.ConnectTimeout := TConfig.IntValue('UPSTREAM_CONNECT_TIMEOUT_MS');
    LProxy.ResponseTimeout := TConfig.IntValue('UPSTREAM_TIMEOUT_MS');
    TProxy.Configure(LProxy);
    ConfigureHealth(LProxy.ConnectTimeout);
    ConfigureCors(TConfig.Value('CORS_ORIGINS'));
    ConfigureLoginLimit(TConfig.IntValue('LOGIN_MAX_ATTEMPTS'), TConfig.IntValue('LOGIN_WINDOW_SECONDS'));
  except
    on E: EConfigException do
    begin
      Writeln(E.Message);
      ExitCode := 2;
      Exit;
    end;
  end;

  // A ordem dos middlewares é a ordem em que a requisição passa por eles.
  // O id vem primeiro para que todos os outros já o encontrem pronto.
  THorse.Use(RequestId);
  THorse.Use(AccessLog);
  THorse.Use(ErrorHandler);
  THorse.Use(Cors);
  THorse.Use(LoginRateLimit);

  // Sem o Jhonson: o gateway não lê nem monta JSON das requisições,
  // ele repassa o corpo como chegou.

  THorse.Get('/health', GetHealth);
  THorse.Get('/health/live', GetLiveness);
  // Qualquer outro caminho, com qualquer método, vai para a tabela de rotas.
  THorse.All('/*', ForwardRequest);

  // Capítulo 20: sem isto, o WebBroker atende no máximo 32 conexões ao mesmo
  // tempo e recusa as outras com um 500.
  THorse.MaxConnections := TConfig.IntValue('MAX_CONNECTIONS');

  THorse.Listen(TConfig.IntValue('PORT'),
    procedure
    begin
      Writeln(Format('api-gateway rodando em http://localhost:%d', [THorse.Port]));
      Writeln('Pressione Ctrl+C para encerrar.');
      Flush(Output);
    end,
    procedure
    begin
      Writeln('api-gateway encerrada.');
      Flush(Output);
    end);
end.
