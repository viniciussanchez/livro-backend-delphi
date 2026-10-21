unit Platform.Config;

{ Configuração dos serviços.

  Cada valor é procurado, nesta ordem:
    1. variável de ambiente do sistema operacional;
    2. arquivo .env (na pasta atual ou na pasta do executável);
    3. valor padrão declarado no código, pensado para o desenvolvimento.

  Em produção (APP_ENV=production), os itens marcados como obrigatórios
  precisam vir do ambiente ou do .env: o padrão do código não vale.
  Se algo estiver faltando, o serviço não sobe e diz exatamente o quê. }

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  EConfigException = class(Exception);

  TSetting = record
    Key: string;
    DefaultValue: string;
    // Nunca aparece no console nem em logs.
    Secret: Boolean;
    // Em produção, precisa ser informado explicitamente.
    RequiredInProduction: Boolean;
    // Em produção, tamanho mínimo (para chaves e senhas).
    MinLengthInProduction: Integer;
    class function New(const AKey, ADefault: string; const ASecret: Boolean = False;
      const ARequiredInProduction: Boolean = False;
      const AMinLengthInProduction: Integer = 0): TSetting; static;
  end;

  TConfig = class
  private
    class var FSettings: TList<TSetting>;
    class var FValues: TDictionary<string, string>;
    class var FSources: TDictionary<string, string>;
    class function ReadEnvFile(out AFileName: string): TDictionary<string, string>; static;
    class procedure Validate; static;
  public
    class constructor Create;
    class destructor Destroy;
    // Lê e valida a configuração. Lança EConfigException com todos os problemas.
    class procedure Load(const ASettings: TArray<TSetting>); static;
    class function Value(const AKey: string): string; static;
    class function IntValue(const AKey: string): Integer; static;
    class function IsProduction: Boolean; static;
    // Mostra a configuração em uso, com os segredos mascarados.
    class procedure PrintSummary(const AServiceName: string); static;
  end;

// Itens que todos os serviços usam: ambiente, banco e chave dos tokens.
function CommonSettings: TArray<TSetting>;

const
  DEV_JWT_SECRET = 'chave-de-desenvolvimento-troque-em-producao';

implementation

uses
  System.Classes,
  System.IOUtils;

function CommonSettings: TArray<TSetting>;
begin
  Result := [
    TSetting.New('APP_ENV', 'development'),
    TSetting.New('DB_HOST', 'localhost'),
    TSetting.New('DB_PORT', '5432'),
    TSetting.New('DB_USER', 'eventos'),
    TSetting.New('DB_PASSWORD', 'eventos', True, True),
    TSetting.New('DB_POOL_SIZE', '50'),
    // 32 caracteres é o mínimo razoável para uma chave HMAC-SHA256.
    TSetting.New('JWT_SECRET', DEV_JWT_SECRET, True, True, 32)
  ];
end;

{ TSetting }

class function TSetting.New(const AKey, ADefault: string; const ASecret: Boolean;
  const ARequiredInProduction: Boolean; const AMinLengthInProduction: Integer): TSetting;
begin
  Result.Key := AKey;
  Result.DefaultValue := ADefault;
  Result.Secret := ASecret;
  Result.RequiredInProduction := ARequiredInProduction;
  Result.MinLengthInProduction := AMinLengthInProduction;
end;

{ TConfig }

class constructor TConfig.Create;
begin
  FSettings := TList<TSetting>.Create;
  FValues := TDictionary<string, string>.Create;
  FSources := TDictionary<string, string>.Create;
end;

class destructor TConfig.Destroy;
begin
  FSources.Free;
  FValues.Free;
  FSettings.Free;
end;

class function TConfig.ReadEnvFile(out AFileName: string): TDictionary<string, string>;
var
  LCandidates: TArray<string>;
  LCandidate, LLine, LKey, LValue: string;
  LPos: Integer;
begin
  Result := TDictionary<string, string>.Create;
  AFileName := '';
  LCandidates := [TPath.Combine(GetCurrentDir, '.env'),
    TPath.Combine(ExtractFilePath(ParamStr(0)), '.env')];
  for LCandidate in LCandidates do
    if TFile.Exists(LCandidate) then
    begin
      AFileName := LCandidate;
      Break;
    end;
  if AFileName.IsEmpty then
    Exit;

  // Formato simples: CHAVE=valor, uma por linha; # inicia um comentário.
  for LLine in TFile.ReadAllLines(AFileName, TEncoding.UTF8) do
  begin
    if LLine.Trim.IsEmpty or LLine.Trim.StartsWith('#') then
      Continue;
    LPos := LLine.IndexOf('=');
    if LPos < 1 then
      Continue;
    LKey := LLine.Substring(0, LPos).Trim.ToUpper;
    LValue := LLine.Substring(LPos + 1).Trim;
    // Aceita valores entre aspas: SENHA="minha senha"
    if (LValue.Length >= 2) and LValue.StartsWith('"') and LValue.EndsWith('"') then
      LValue := LValue.Substring(1, LValue.Length - 2);
    Result.AddOrSetValue(LKey, LValue);
  end;
end;

class procedure TConfig.Load(const ASettings: TArray<TSetting>);
var
  LFile: TDictionary<string, string>;
  LFileName: string;
  LSetting: TSetting;
  LValue: string;
begin
  FSettings.Clear;
  FValues.Clear;
  FSources.Clear;
  LFile := ReadEnvFile(LFileName);
  try
    for LSetting in ASettings do
    begin
      FSettings.Add(LSetting);
      LValue := GetEnvironmentVariable(LSetting.Key);
      if not LValue.IsEmpty then
        FSources.AddOrSetValue(LSetting.Key, 'ambiente')
      else if LFile.TryGetValue(LSetting.Key, LValue) and not LValue.IsEmpty then
        FSources.AddOrSetValue(LSetting.Key, ExtractFileName(LFileName))
      else
      begin
        LValue := LSetting.DefaultValue;
        FSources.AddOrSetValue(LSetting.Key, 'padrão');
      end;
      FValues.AddOrSetValue(LSetting.Key, LValue);
    end;
  finally
    LFile.Free;
  end;
  Validate;
end;

class procedure TConfig.Validate;
var
  LErrors: TStringList;
  LSetting: TSetting;
  LEnv: string;
begin
  LEnv := Value('APP_ENV');
  if not (SameText(LEnv, 'development') or SameText(LEnv, 'production')) then
    raise EConfigException.CreateFmt('APP_ENV deve ser development ou production, não "%s".', [LEnv]);
  if not IsProduction then
    Exit;

  // Junta todos os problemas antes de falhar: quem configura o servidor
  // corrige tudo de uma vez, em vez de descobrir um por reinicialização.
  LErrors := TStringList.Create;
  try
    for LSetting in FSettings do
    begin
      if LSetting.RequiredInProduction and (FSources[LSetting.Key] = 'padrão') then
        LErrors.Add(Format('  - %s é obrigatória em produção.', [LSetting.Key]))
      else if (LSetting.MinLengthInProduction > 0) and
              (Value(LSetting.Key).Length < LSetting.MinLengthInProduction) then
        LErrors.Add(Format('  - %s deve ter pelo menos %d caracteres.',
          [LSetting.Key, LSetting.MinLengthInProduction]));
    end;
    // A chave de desenvolvimento está no código-fonte, que qualquer um pode ler.
    if FValues.ContainsKey('JWT_SECRET') and (FSources['JWT_SECRET'] <> 'padrão') and
       (Value('JWT_SECRET') = DEV_JWT_SECRET) then
      LErrors.Add('  - JWT_SECRET não pode ser a chave de desenvolvimento.');
    if LErrors.Count > 0 then
      raise EConfigException.Create('Configuração inválida para produção:' + sLineBreak +
        LErrors.Text.TrimRight);
  finally
    LErrors.Free;
  end;
end;

class function TConfig.Value(const AKey: string): string;
begin
  if not FValues.TryGetValue(AKey, Result) then
    raise EConfigException.CreateFmt('Configuração não declarada: %s.', [AKey]);
end;

class function TConfig.IntValue(const AKey: string): Integer;
begin
  if not TryStrToInt(Value(AKey), Result) then
    raise EConfigException.CreateFmt('%s deve ser um número inteiro, não "%s".', [AKey, Value(AKey)]);
end;

class function TConfig.IsProduction: Boolean;
begin
  Result := SameText(Value('APP_ENV'), 'production');
end;

class procedure TConfig.PrintSummary(const AServiceName: string);
var
  LSetting: TSetting;
  LShown: string;
begin
  Writeln(Format('Configuração da %s (%s):', [AServiceName, Value('APP_ENV')]));
  for LSetting in FSettings do
  begin
    if LSetting.Secret then
      LShown := '********'
    else
      LShown := Value(LSetting.Key);
    Writeln(Format('  %-27s = %-30s [%s]', [LSetting.Key, LShown, FSources[LSetting.Key]]));
  end;
  // O gateway (capítulo 16) não usa tokens, então nem todo serviço tem JWT_SECRET.
  if not IsProduction and FValues.ContainsKey('JWT_SECRET') and
     (Value('JWT_SECRET') = DEV_JWT_SECRET) then
    Writeln('  Atenção: usando a chave JWT de desenvolvimento.');
end;

end.
