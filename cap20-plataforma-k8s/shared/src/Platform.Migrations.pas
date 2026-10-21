unit Platform.Migrations;

{ Versionamento da estrutura do banco.

  Cada migração tem um número de versão e uma lista de comandos SQL.
  Na inicialização, o serviço aplica, em ordem, as migrações que ainda
  não foram aplicadas e registra cada uma na tabela schema_migration. }

interface

uses
  System.SysUtils;

type
  TMigration = record
    Version: Integer;
    Description: string;
    Statements: TArray<string>;
    class function New(const AVersion: Integer; const ADescription: string;
      const AStatements: TArray<string>): TMigration; static;
  end;

  TMigrator = class
  public
    class procedure Run(const AConnectionDefName: string; const AMigrations: TArray<TMigration>); overload; static;
    // Capítulo 20: AAfterMigrations roda ainda com o lock na mão. Serve para
    // tarefas de inicialização que só uma cópia do serviço pode fazer por vez,
    // como criar o administrador inicial.
    class procedure Run(const AConnectionDefName: string; const AMigrations: TArray<TMigration>;
      const AAfterMigrations: TProc); overload; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.Generics.Defaults,
  FireDAC.Comp.Client,
  Platform.Database;

class function TMigration.New(const AVersion: Integer; const ADescription: string;
  const AStatements: TArray<string>): TMigration;
begin
  Result.Version := AVersion;
  Result.Description := ADescription;
  Result.Statements := AStatements;
end;

class procedure TMigrator.Run(const AConnectionDefName: string; const AMigrations: TArray<TMigration>);
begin
  Run(AConnectionDefName, AMigrations, nil);
end;

class procedure TMigrator.Run(const AConnectionDefName: string; const AMigrations: TArray<TMigration>;
  const AAfterMigrations: TProc);
const
  // Número arbitrário que identifica o lock das migrações.
  MIGRATION_LOCK_ID = 20260001;
var
  LConnection: TFDConnection;
  LMigrations: TArray<TMigration>;
  LMigration: TMigration;
  LStatement: string;
  LCurrentVersion: Integer;
begin
  LMigrations := Copy(AMigrations);
  TArray.Sort<TMigration>(LMigrations, TComparer<TMigration>.Construct(
    function(const ALeft, ARight: TMigration): Integer
    begin
      Result := ALeft.Version - ARight.Version;
    end));

  LConnection := TDatabase.NewConnection(AConnectionDefName);
  try
    // Se várias cópias do serviço subirem ao mesmo tempo (capítulo 20),
    // só uma aplica as migrações; as outras esperam aqui.
    LConnection.ExecSQLScalar('select pg_advisory_lock(' + IntToStr(MIGRATION_LOCK_ID) + ')');
    try
      LConnection.ExecSQL(
        'create table if not exists schema_migration (' +
        '  version integer primary key,' +
        '  description varchar(200) not null,' +
        '  applied_at timestamp not null default now()' +
        ')');

      LCurrentVersion := LConnection.ExecSQLScalar('select coalesce(max(version), 0) from schema_migration');

      for LMigration in LMigrations do
      begin
        if LMigration.Version <= LCurrentVersion then
          Continue;

        // No PostgreSQL, comandos de estrutura (DDL) respeitam transação:
        // se um comando falhar, a migração inteira é desfeita.
        LConnection.StartTransaction;
        try
          for LStatement in LMigration.Statements do
            LConnection.ExecSQL(LStatement);
          LConnection.ExecSQL(
            'insert into schema_migration (version, description) values (:version, :description)',
            [LMigration.Version, LMigration.Description]);
          LConnection.Commit;
        except
          LConnection.Rollback;
          raise;
        end;

        Writeln(Format('Migração %d aplicada: %s', [LMigration.Version, LMigration.Description]));
      end;
      // Ainda dentro do lock: as outras cópias continuam esperando.
      if Assigned(AAfterMigrations) then
        AAfterMigrations();
    finally
      LConnection.ExecSQLScalar('select pg_advisory_unlock(' + IntToStr(MIGRATION_LOCK_ID) + ')');
    end;
  finally
    LConnection.Free;
  end;
end;

end.
