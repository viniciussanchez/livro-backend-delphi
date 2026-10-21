unit Platform.Repository;

{ Base comum dos repositórios FireDAC.

  O repositório não abre conexão: ele recebe a sessão da requisição.
  Assim, vários repositórios usados na mesma requisição compartilham
  a mesma conexão (e, se preciso, a mesma transação). }

interface

uses
  FireDAC.Comp.Client,
  Platform.Database;

type
  TFireDACRepository = class(TInterfacedObject)
  private
    FSession: IDbSession;
  protected
    function Connection: TFDConnection;
    property Session: IDbSession read FSession;
    // Cria uma query ligada à conexão da sessão. Quem chama libera.
    function NewQuery(const ASQL: string): TFDQuery;
  public
    constructor Create(const ASession: IDbSession);
  end;

implementation

constructor TFireDACRepository.Create(const ASession: IDbSession);
begin
  inherited Create;
  FSession := ASession;
end;

function TFireDACRepository.Connection: TFDConnection;
begin
  Result := FSession.Connection;
end;

function TFireDACRepository.NewQuery(const ASQL: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := Connection;
  Result.SQL.Text := ASQL;
end;

end.
