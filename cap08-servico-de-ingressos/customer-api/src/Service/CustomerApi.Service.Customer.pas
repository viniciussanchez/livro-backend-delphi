unit CustomerApi.Service.Customer;

{ Regras de negócio dos participantes. }

interface

uses
  System.Generics.Collections,
  CustomerApi.Entity.Customer,
  CustomerApi.DTO.Customer,
  CustomerApi.Repository.Customer;

type
  ICustomerService = interface
    ['{3E8D5B12-0A6F-4C97-B2E4-8F1A7D6C0B95}']
    function FindById(const AId: Integer): TCustomer;
    function Search(const ACpf, AEmail: string): TObjectList<TCustomer>;
    function Add(const ARequest: TCustomerRequest): TCustomer;
    function Update(const AId: Integer; const ARequest: TCustomerRequest): TCustomer;
    procedure Remove(const AId: Integer);
  end;

  TCustomerService = class(TInterfacedObject, ICustomerService)
  private
    FRepository: ICustomerRepository;
    // Valida e normaliza os campos que podem mudar (nome, e-mail, telefone, nascimento).
    procedure ApplyCommonFields(const ARequest: TCustomerRequest; const ACustomer: TCustomer);
  public
    constructor Create(const ARepository: ICustomerRepository);
    function FindById(const AId: Integer): TCustomer;
    function Search(const ACpf, AEmail: string): TObjectList<TCustomer>;
    function Add(const ARequest: TCustomerRequest): TCustomer;
    function Update(const AId: Integer; const ARequest: TCustomerRequest): TCustomer;
    procedure Remove(const AId: Integer);
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.RegularExpressions,
  Platform.Exceptions,
  Platform.Dates,
  CustomerApi.Cpf;

const
  // Simples de propósito: confere o formato geral, não se o e-mail existe.
  // A confirmação real de um e-mail é feita enviando uma mensagem para ele.
  EMAIL_PATTERN = '^[^@\s]+@[^@\s]+\.[^@\s]+$';

constructor TCustomerService.Create(const ARepository: ICustomerRepository);
begin
  inherited Create;
  FRepository := ARepository;
end;

procedure TCustomerService.ApplyCommonFields(const ARequest: TCustomerRequest; const ACustomer: TCustomer);
var
  LPhone: string;
  LBirthDate: TDate;
begin
  if ARequest.Name.IsEmpty then
    raise EValidationException.Create('Informe o nome do participante.');
  if ARequest.Name.Length > 150 then
    raise EValidationException.Create('O nome deve ter no máximo 150 caracteres.');

  if ARequest.Email.IsEmpty then
    raise EValidationException.Create('Informe o e-mail do participante.');
  if (ARequest.Email.Length > 254) or not TRegEx.IsMatch(ARequest.Email, EMAIL_PATTERN) then
    raise EValidationException.Create('O e-mail informado não é válido.');

  // Aceita '(31) 99999-8888' e guarda só os dígitos.
  LPhone := TCpf.OnlyDigits(ARequest.Phone);
  if not ARequest.Phone.IsEmpty and not ((LPhone.Length = 10) or (LPhone.Length = 11)) then
    raise EValidationException.Create('Informe o telefone com DDD, por exemplo (31) 99999-8888.');

  LBirthDate := 0;
  if not ARequest.BirthDate.IsEmpty then
  begin
    if not TryParseISODate(ARequest.BirthDate, LBirthDate) then
      raise EValidationException.Create('Informe a data de nascimento no formato aaaa-mm-dd.');
    if LBirthDate > Today then
      raise EValidationException.Create('A data de nascimento não pode estar no futuro.');
  end;

  ACustomer.Name := ARequest.Name;
  ACustomer.Email := ARequest.Email;
  ACustomer.Phone := LPhone;
  ACustomer.BirthDate := LBirthDate;
end;

function TCustomerService.FindById(const AId: Integer): TCustomer;
begin
  Result := FRepository.FindById(AId);
  if not Assigned(Result) then
    raise ENotFoundException.Create('Participante não encontrado.');
end;

function TCustomerService.Search(const ACpf, AEmail: string): TObjectList<TCustomer>;
var
  LCustomer: TCustomer;
begin
  // Não existe "listar todos": buscar dados pessoais exige saber o que se procura.
  if ACpf.IsEmpty and AEmail.IsEmpty then
    raise EValidationException.Create('Informe o CPF ou o e-mail para a busca.');

  if not ACpf.IsEmpty then
    LCustomer := FRepository.FindByCpf(TCpf.OnlyDigits(ACpf))
  else
    LCustomer := FRepository.FindByEmail(AEmail.Trim);

  Result := TObjectList<TCustomer>.Create(True);
  if Assigned(LCustomer) then
    Result.Add(LCustomer);
end;

function TCustomerService.Add(const ARequest: TCustomerRequest): TCustomer;
var
  LCpf: string;
begin
  LCpf := TCpf.OnlyDigits(ARequest.Cpf);
  if ARequest.Cpf.IsEmpty then
    raise EValidationException.Create('Informe o CPF do participante.');
  if not TCpf.IsValid(LCpf) then
    raise EValidationException.Create('O CPF informado não é válido.');

  Result := TCustomer.Create;
  try
    ApplyCommonFields(ARequest, Result);
    Result.Cpf := LCpf;

    if FRepository.CpfInUse(Result.Cpf) then
      raise EConflictException.Create('Já existe um participante com este CPF.');
    if FRepository.EmailInUse(Result.Email) then
      raise EConflictException.Create('Já existe um participante com este e-mail.');

    Result.CreatedAt := Now;
    Result.UpdatedAt := Result.CreatedAt;
    FRepository.Insert(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TCustomerService.Update(const AId: Integer; const ARequest: TCustomerRequest): TCustomer;
begin
  Result := FindById(AId);
  try
    // O CPF identifica a pessoa e não pode ser trocado: ARequest.Cpf é ignorado.
    ApplyCommonFields(ARequest, Result);

    if FRepository.EmailInUse(Result.Email, AId) then
      raise EConflictException.Create('Já existe um participante com este e-mail.');

    Result.UpdatedAt := Now;
    FRepository.Update(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TCustomerService.Remove(const AId: Integer);
begin
  if not FRepository.Anonymize(AId, Now) then
    raise ENotFoundException.Create('Participante não encontrado.');
end;

end.
