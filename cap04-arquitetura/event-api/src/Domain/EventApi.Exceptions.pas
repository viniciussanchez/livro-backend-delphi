unit EventApi.Exceptions;

{ Exceções de domínio. Elas não sabem nada de HTTP: quem decide
  qual status devolver para cada uma é a camada de Controller. }

interface

uses
  System.SysUtils;

type
  EDomainException = class(Exception);

  EValidationException = class(EDomainException);

  ENotFoundException = class(EDomainException);

implementation

end.
