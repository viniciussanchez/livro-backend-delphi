unit Platform.Auth;

{ Autenticação e autorização com JWT, compartilhadas pelos serviços.

  - Authenticate: middleware que exige um token válido no cabeçalho
    "Authorization: Bearer <token>" e guarda quem fez a requisição.
  - RequireRole: middleware que exige um dos papéis informados.
  - CurrentUser: quem fez a requisição, dentro de um handler.
  - IssueToken / ServiceToken: geram tokens (login e chamadas entre serviços). }

interface

uses
  System.SysUtils,
  Horse;

const
  ROLE_ADMIN = 'admin';       // organizador: cadastra eventos, vê relatórios
  ROLE_STAFF = 'staff';       // equipe da portaria: check-in
  ROLE_CUSTOMER = 'customer'; // participante: compra os próprios ingressos
  ROLE_SERVICE = 'service';   // outro microsserviço da plataforma

  USER_TOKEN_SECONDS = 3600;    // 1 hora
  SERVICE_TOKEN_SECONDS = 300;  // 5 minutos

type
  // Quem fez a requisição, segundo o token.
  TPrincipal = class
  private
    FSubject: string;
    FRole: string;
    FCustomerId: Integer;
  public
    function HasRole(const ARoles: array of string): Boolean;
    // True se for o participante AId falando de si mesmo.
    function IsCustomer(const AId: Integer): Boolean;
    property Subject: string read FSubject;
    property Role: string read FRole;
    property CustomerId: Integer read FCustomerId;
  end;

// Chamado uma vez, na inicialização do serviço, com a chave de Platform.Config.
procedure ConfigureAuth(const ASecret, AServiceName: string);

procedure Authenticate(Req: THorseRequest; Res: THorseResponse; Next: TProc);
function RequireRole(const ARoles: TArray<string>): THorseCallback;
// Atalho para as rotas protegidas: autentica e confere o papel.
function Protect(const ARoles: TArray<string>): TArray<THorseCallback>;
function CurrentUser(const AReq: THorseRequest): TPrincipal;

function IssueToken(const ASubject, ARole: string; const ACustomerId: Integer;
  const AExpiresIn: Integer): string;
// Token deste serviço para chamar os outros. Reaproveitado enquanto válido.
function ServiceToken: string;

implementation

uses
  System.JSON,
  System.SyncObjs,
  Platform.Exceptions,
  Platform.Jwt;

var
  GSecret: string;
  GServiceName: string;
  GServiceToken: string;
  GServiceTokenExpires: Int64;
  GLock: TCriticalSection;

procedure ConfigureAuth(const ASecret, AServiceName: string);
begin
  GSecret := ASecret;
  GServiceName := AServiceName;
end;

{ TPrincipal }

function TPrincipal.HasRole(const ARoles: array of string): Boolean;
var
  LRole: string;
begin
  for LRole in ARoles do
    if SameText(LRole, FRole) then
      Exit(True);
  Result := False;
end;

function TPrincipal.IsCustomer(const AId: Integer): Boolean;
begin
  Result := SameText(FRole, ROLE_CUSTOMER) and (FCustomerId = AId);
end;

{ Tokens }

function IssueToken(const ASubject, ARole: string; const ACustomerId: Integer;
  const AExpiresIn: Integer): string;
var
  LClaims: TJSONObject;
  LNow: Int64;
begin
  LNow := TJwt.NowUnix;
  LClaims := TJSONObject.Create;
  try
    LClaims.AddPair('iss', 'eventos-platform');
    LClaims.AddPair('sub', ASubject);
    LClaims.AddPair('role', ARole);
    if ACustomerId > 0 then
      LClaims.AddPair('cid', TJSONNumber.Create(ACustomerId));
    LClaims.AddPair('iat', TJSONNumber.Create(LNow));
    LClaims.AddPair('exp', TJSONNumber.Create(LNow + AExpiresIn));
    Result := TJwt.Sign(LClaims, GSecret);
  finally
    LClaims.Free;
  end;
end;

function ServiceToken: string;
begin
  GLock.Enter;
  try
    // Renova um minuto antes de vencer, para nunca enviar um token no limite.
    if GServiceToken.IsEmpty or (TJwt.NowUnix > GServiceTokenExpires - 60) then
    begin
      GServiceToken := IssueToken(GServiceName, ROLE_SERVICE, 0, SERVICE_TOKEN_SECONDS);
      GServiceTokenExpires := TJwt.NowUnix + SERVICE_TOKEN_SECONDS;
    end;
    Result := GServiceToken;
  finally
    GLock.Leave;
  end;
end;

{ Middlewares }

procedure Authenticate(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LHeader, LToken: string;
  LClaims: TJSONObject;
  LPrincipal: TPrincipal;
begin
  LHeader := Req.Headers['Authorization'];
  if not LHeader.StartsWith('Bearer ', True) then
    raise EUnauthorizedException.Create('Envie o token no cabeçalho Authorization: Bearer <token>.');
  LToken := LHeader.Substring(7).Trim;

  try
    LClaims := TJwt.Verify(LToken, GSecret);
  except
    on E: EJwtException do
      // O motivo exato (assinatura, expiração...) vai na mensagem: ajuda
      // quem integra e não ajuda quem ataca, que não tem a chave.
      raise EUnauthorizedException.Create(E.Message);
  end;
  try
    LPrincipal := TPrincipal.Create;
    LPrincipal.FSubject := LClaims.GetValue<string>('sub', '');
    LPrincipal.FRole := LClaims.GetValue<string>('role', '');
    LPrincipal.FCustomerId := LClaims.GetValue<Integer>('cid', 0);
  finally
    LClaims.Free;
  end;
  // A requisição passa a ser dona do objeto e o libera no fim.
  Req.Session(LPrincipal, True);
  Next;
end;

function RequireRole(const ARoles: TArray<string>): THorseCallback;
var
  LRoles: TArray<string>;
begin
  LRoles := ARoles;
  Result :=
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      if not CurrentUser(Req).HasRole(LRoles) then
        raise EForbiddenException.Create('Você não tem permissão para esta operação.');
      Next;
    end;
end;

function Protect(const ARoles: TArray<string>): TArray<THorseCallback>;
var
  LAuthenticate: THorseCallback;
begin
  LAuthenticate := Authenticate;
  Result := [LAuthenticate, RequireRole(ARoles)];
end;

function CurrentUser(const AReq: THorseRequest): TPrincipal;
begin
  if not (AReq.Session<TObject> is TPrincipal) then
    raise EUnauthorizedException.Create('Requisição sem autenticação.');
  Result := AReq.Session<TPrincipal>;
end;

initialization
  GLock := TCriticalSection.Create;

finalization
  GLock.Free;

end.
