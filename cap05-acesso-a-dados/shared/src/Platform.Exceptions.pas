unit Platform.Exceptions;

{ Exceções de domínio compartilhadas pelos serviços da plataforma.
  Nenhuma delas sabe o que é HTTP: a tradução para status fica em Platform.Http. }

interface

uses
  System.SysUtils;

type
  EDomainException = class(Exception);

  // Dados de entrada inválidos (campo vazio, formato errado...).
  EValidationException = class(EDomainException);

  // O registro procurado não existe.
  ENotFoundException = class(EDomainException);

  // A operação conflita com o estado atual (duplicidade, estado incompatível...).
  EConflictException = class(EDomainException);

  // Os dados são válidos, mas violam uma regra de negócio.
  EBusinessRuleException = class(EDomainException);

implementation

end.
