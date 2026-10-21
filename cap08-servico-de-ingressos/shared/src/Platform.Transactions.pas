unit Platform.Transactions;

{ Contrato de transação para a camada de serviço.

  O Service decide o que precisa acontecer "tudo ou nada", mas não deve
  conhecer o FireDAC. Por isso ele depende só desta interface. }

interface

uses
  System.SysUtils;

type
  ITransactionScope = interface
    ['{0C7E2A95-41B3-4D68-9F05-B3E8D1A6C724}']
    // Executa AProc em uma transação: commit se der certo, rollback se falhar.
    procedure InTransaction(const AProc: TProc);
  end;

implementation

end.
