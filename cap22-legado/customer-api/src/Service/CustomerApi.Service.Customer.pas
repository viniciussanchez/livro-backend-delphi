unit CustomerApi.Service.Customer;

{ Regras de negócio dos participantes. }

interface

uses
  System.Generics.Collections,
  Platform.Validation,
  Platform.Transactions,
  CustomerApi.Repository.User,
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
    // Capítulo 22: cria ou atualiza o participante que veio do sistema
    // antigo, identificado pelo código que ele tinha lá (ALegacyCode).
    // ACreated diz qual dos dois aconteceu.
    function ImportFromLegacy(const ALegacyCode: Integer; const ARequest: TCustomerRequest;
      out ACreated: Boolean): TCustomer;
  end;

  TCustomerService = class(TInterfacedObject, ICustomerService)
  private
    FRepository: ICustomerRepository;
    FUsers: IUserRepository;
    FTransaction: ITransactionScope;
    // Valida e normaliza os campos que podem mudar (nome, e-mail, telefone, nascimento).
    // Os problemas encontrados vão para AValidation; quem chama decide quando parar.
    procedure ApplyCommonFields(const ARequest: TCustomerRequest; const ACustomer: TCustomer;
      var AValidation: TValidation; const AEmailRequired: Boolean = True);
  public
    constructor Create(const ARepository: ICustomerRepository; const AUsers: IUserRepository;
      const ATransaction: ITransactionScope);
    function FindById(const AId: Integer): TCustomer;
    function Search(const ACpf, AEmail: string): TObjectList<TCustomer>;
    function Add(const ARequest: TCustomerRequest): TCustomer;
    function Update(const AId: Integer; const ARequest: TCustomerRequest): TCustomer;
    procedure Remove(const AId: Integer);
    function ImportFromLegacy(const ALegacyCode: Integer; const ARequest: TCustomerRequest;
      out ACreated: Boolean): TCustomer;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.RegularExpressions,
  Platform.Exceptions,
  Platform.Auth,
  CustomerApi.Service.Auth,
  Platform.Dates,
  CustomerApi.Cpf;

const
  // Simples de propósito: confere o formato geral, não se o e-mail existe.
  // A confirmação real de um e-mail é feita enviando uma mensagem para ele.
  EMAIL_PATTERN = '^[^@\s]+@[^@\s]+\.[^@\s]+$';

constructor TCustomerService.Create(const ARepository: ICustomerRepository; const AUsers: IUserRepository;
  const ATransaction: ITransactionScope);
begin
  inherited Create;
  FRepository := ARepository;
  FUsers := AUsers;
  FTransaction := ATransaction;
end;

procedure TCustomerService.ApplyCommonFields(const ARequest: TCustomerRequest; const ACustomer: TCustomer;
  var AValidation: TValidation; const AEmailRequired: Boolean);
var
  LPhone: string;
  LBirthDate: TDate;
begin
  if AValidation.Check(not ARequest.Name.IsEmpty, 'name', 'Informe o nome do participante.') then
    AValidation.Check(ARequest.Name.Length <= 150, 'name', 'O nome deve ter no máximo 150 caracteres.');

  if ARequest.Email.IsEmpty then
    AValidation.Check(not AEmailRequired, 'email', 'Informe o e-mail do participante.')
  else
    AValidation.Check((ARequest.Email.Length <= 254) and TRegEx.IsMatch(ARequest.Email, EMAIL_PATTERN),
      'email', 'O e-mail informado não é válido.');

  // Aceita '(31) 99999-8888' e guarda só os dígitos.
  LPhone := TCpf.OnlyDigits(ARequest.Phone);
  AValidation.Check(ARequest.Phone.IsEmpty or (LPhone.Length = 10) or (LPhone.Length = 11),
    'phone', 'Informe o telefone com DDD, por exemplo (31) 99999-8888.');

  LBirthDate := 0;
  if not ARequest.BirthDate.IsEmpty then
    if AValidation.Check(TryParseISODate(ARequest.BirthDate, LBirthDate),
      'birthDate', 'Informe a data de nascimento no formato aaaa-mm-dd.') then
      AValidation.Check(LBirthDate <= Today, 'birthDate', 'A data de nascimento não pode estar no futuro.');

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
    raise EValidationException.CreateForField('cpf', 'Informe o CPF ou o e-mail para a busca.');

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
  LCpf, LPassword: string;
  LValidation: TValidation;
  LCustomer: TCustomer;
begin
  LCpf := TCpf.OnlyDigits(ARequest.Cpf);
  if LValidation.Check(not ARequest.Cpf.IsEmpty, 'cpf', 'Informe o CPF do participante.') then
    LValidation.Check(TCpf.IsValid(LCpf), 'cpf', 'O CPF informado não é válido.');
  // Capítulo 13: o cadastro cria também o acesso do participante.
  LPassword := ARequest.Password;
  LValidation.Check(LPassword.Length >= MIN_PASSWORD_LENGTH, 'password',
    Format('A senha deve ter pelo menos %d caracteres.', [MIN_PASSWORD_LENGTH]));

  LCustomer := TCustomer.Create;
  try
    ApplyCommonFields(ARequest, LCustomer, LValidation);
    LValidation.RaiseIfInvalid;
    LCustomer.Cpf := LCpf;

    if FRepository.CpfInUse(LCustomer.Cpf) then
      raise EConflictException.Create('Já existe um participante com este CPF.');
    // Confere participantes e equipe: o e-mail é o login.
    if FUsers.EmailInUse(LCustomer.Email) then
      raise EConflictException.Create('Já existe um participante com este e-mail.');

    LCustomer.CreatedAt := Now;
    LCustomer.UpdatedAt := LCustomer.CreatedAt;
    // Participante e acesso nascem juntos, ou nenhum dos dois.
    FTransaction.InTransaction(
      procedure
      begin
        FRepository.Insert(LCustomer);
        FUsers.Insert('', LPassword, ROLE_CUSTOMER, LCustomer.Id, LCustomer.CreatedAt);
      end);
    Result := LCustomer;
  except
    LCustomer.Free;
    raise;
  end;
end;

function TCustomerService.Update(const AId: Integer; const ARequest: TCustomerRequest): TCustomer;
var
  LValidation: TValidation;
begin
  Result := FindById(AId);
  try
    // O CPF identifica a pessoa e não pode ser trocado: ARequest.Cpf é ignorado.
    ApplyCommonFields(ARequest, Result, LValidation);
    LValidation.RaiseIfInvalid;

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

function TCustomerService.ImportFromLegacy(const ALegacyCode: Integer; const ARequest: TCustomerRequest;
  out ACreated: Boolean): TCustomer;
var
  LValidation: TValidation;
  LIncoming, LCustomer: TCustomer;
  LCpf: string;
  LOtherCode: Integer;
begin
  // As mesmas regras do cadastro, com duas diferenças combinadas com o
  // negócio: o e-mail é opcional (muita gente comprou no balcão sem dar
  // e-mail) e não há senha (o acesso ao aplicativo vem depois).
  LCpf := TCpf.OnlyDigits(ARequest.Cpf);
  if LValidation.Check(not ARequest.Cpf.IsEmpty, 'cpf', 'Informe o CPF do participante.') then
    LValidation.Check(TCpf.IsValid(LCpf), 'cpf', 'O CPF informado não é válido.');
  LIncoming := TCustomer.Create;
  try
    ApplyCommonFields(ARequest, LIncoming, LValidation, False);
    LValidation.RaiseIfInvalid;

    // 1. Já sincronizado antes: o código do sistema antigo o identifica.
    LCustomer := FRepository.FindByLegacyCode(ALegacyCode);
    // 2. Ainda não, mas a pessoa já se cadastrou na plataforma nova com o
    //    mesmo CPF: ligamos os dois cadastros em vez de criar um segundo.
    if not Assigned(LCustomer) then
    begin
      LCustomer := FRepository.FindByCpf(LCpf);
      if Assigned(LCustomer) and (LCustomer.LegacyCode <> 0) then
      begin
        // O mesmo CPF já está ligado a OUTRO código do sistema antigo:
        // a pessoa foi cadastrada duas vezes lá. Só um humano decide qual
        // cadastro vale.
        LOtherCode := LCustomer.LegacyCode;
        LCustomer.Free;
        raise EConflictException.CreateFmt(
          'O CPF já pertence ao cliente de código %d do sistema antigo.', [LOtherCode]);
      end;
    end;

    try
      ACreated := not Assigned(LCustomer);
      if ACreated then
        LCustomer := TCustomer.Create;
      // O sistema antigo é o dono destes dados nesta fase da migração:
      // o que vem de lá prevalece. Mas um campo vazio lá não apaga o
      // que já existe aqui.
      LCustomer.LegacyCode := ALegacyCode;
      LCustomer.Name := LIncoming.Name;
      LCustomer.Cpf := LCpf;
      if not LIncoming.Email.IsEmpty then
        LCustomer.Email := LIncoming.Email;
      if not LIncoming.Phone.IsEmpty then
        LCustomer.Phone := LIncoming.Phone;
      if LIncoming.BirthDate <> 0 then
        LCustomer.BirthDate := LIncoming.BirthDate;

      if FRepository.CpfInUse(LCustomer.Cpf, LCustomer.Id) then
        raise EConflictException.Create('Já existe outro participante com este CPF.');
      if not LCustomer.Email.IsEmpty and FRepository.EmailInUse(LCustomer.Email, LCustomer.Id) then
        raise EConflictException.Create('Já existe outro participante com este e-mail.');

      LCustomer.UpdatedAt := Now;
      if ACreated then
      begin
        LCustomer.CreatedAt := LCustomer.UpdatedAt;
        FRepository.Insert(LCustomer);
      end
      else
        FRepository.UpdateFromLegacy(LCustomer);
      Result := LCustomer;
    except
      LCustomer.Free;
      raise;
    end;
  finally
    LIncoming.Free;
  end;
end;

end.
