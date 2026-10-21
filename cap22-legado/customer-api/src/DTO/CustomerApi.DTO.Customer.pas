unit CustomerApi.DTO.Customer;

interface

uses
  System.JSON,
  System.Generics.Collections,
  CustomerApi.Entity.Customer;

type
  // Usado no cadastro e na atualização. Na atualização, o CPF é ignorado.
  TCustomerRequest = record
    Name: string;
    Cpf: string;
    Email: string;
    Phone: string;
    BirthDate: string;
    // Só no cadastro (capítulo 13). Nunca devolvida nas respostas.
    Password: string;
    class function FromJSON(const AJSON: TJSONObject): TCustomerRequest; static;
  end;

  TCustomerMapper = class
  public
    class function ToJSON(const ACustomer: TCustomer): TJSONObject; static;
    class function ToJSONArray(const ACustomers: TObjectList<TCustomer>): TJSONArray; static;
  end;

implementation

uses
  System.SysUtils,
  Platform.Dates,
  CustomerApi.Cpf;

class function TCustomerRequest.FromJSON(const AJSON: TJSONObject): TCustomerRequest;
begin
  Result.Name := AJSON.GetValue<string>('name', '').Trim;
  Result.Cpf := AJSON.GetValue<string>('cpf', '').Trim;
  Result.Email := AJSON.GetValue<string>('email', '').Trim.ToLower;
  Result.Phone := AJSON.GetValue<string>('phone', '').Trim;
  Result.BirthDate := AJSON.GetValue<string>('birthDate', '').Trim;
  Result.Password := AJSON.GetValue<string>('password', '');
end;

class function TCustomerMapper.ToJSON(const ACustomer: TCustomer): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(ACustomer.Id));
  Result.AddPair('name', ACustomer.Name);
  // O CPF completo nunca sai da API: devolvemos apenas a versão mascarada.
  Result.AddPair('cpf', TCpf.Mask(ACustomer.Cpf));
  // Capítulo 22: participantes vindos do sistema antigo podem não ter e-mail.
  if ACustomer.Email.IsEmpty then
    Result.AddPair('email', TJSONNull.Create)
  else
    Result.AddPair('email', ACustomer.Email);
  if ACustomer.Phone.IsEmpty then
    Result.AddPair('phone', TJSONNull.Create)
  else
    Result.AddPair('phone', ACustomer.Phone);
  if ACustomer.BirthDate = 0 then
    Result.AddPair('birthDate', TJSONNull.Create)
  else
    Result.AddPair('birthDate', FormatISODate(ACustomer.BirthDate));
  Result.AddPair('createdAt', FormatISODateTime(ACustomer.CreatedAt));
  Result.AddPair('updatedAt', FormatISODateTime(ACustomer.UpdatedAt));
  if ACustomer.LegacyCode > 0 then
    Result.AddPair('legacyCode', TJSONNumber.Create(ACustomer.LegacyCode));
end;

class function TCustomerMapper.ToJSONArray(const ACustomers: TObjectList<TCustomer>): TJSONArray;
var
  LCustomer: TCustomer;
begin
  Result := TJSONArray.Create;
  for LCustomer in ACustomers do
    Result.AddElement(ToJSON(LCustomer));
end;

end.
