unit CustomerApi.Controller.Auth;

interface

procedure Registry;

implementation

uses
  System.SysUtils,
  System.JSON,
  Horse,
  Platform.Http,
  Platform.Auth,
  CustomerApi.Service.Auth,
  CustomerApi.Container;

// POST /auth/token  {"email": "...", "password": "..."}
procedure PostToken(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
  LToken: TTokenResult;
  LResult: TJSONObject;
begin
  LBody := RequestBody(Req);
  LToken := AuthService.Login(LBody.GetValue<string>('email', ''), LBody.GetValue<string>('password', ''));
  LResult := TJSONObject.Create;
  LResult.AddPair('accessToken', LToken.AccessToken);
  LResult.AddPair('tokenType', 'Bearer');
  LResult.AddPair('expiresIn', TJSONNumber.Create(LToken.ExpiresIn));
  LResult.AddPair('role', LToken.Role);
  Res.Send<TJSONObject>(LResult);
end;

// POST /users  {"email": "...", "password": "...", "role": "staff"}
procedure PostUser(Req: THorseRequest; Res: THorseResponse);
var
  LBody: TJSONObject;
begin
  LBody := RequestBody(Req);
  AuthService.CreateStaff(LBody.GetValue<string>('email', '').Trim,
    LBody.GetValue<string>('password', ''), LBody.GetValue<string>('role', '').Trim);
  Res.Status(THTTPStatus.Created).Send('');
end;

procedure Registry;
begin
  // Pública: é aqui que se consegue o token.
  THorse.Post('/auth/token', PostToken);
  // Só administradores criam contas da equipe.
  THorse.AddCallbacks(Protect([ROLE_ADMIN])).Post('/users', PostUser);
end;

end.
