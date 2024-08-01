program templateproplaygroud;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.IOUtils,
  TemplateProU in '..\TemplateProU.pas',
  System.Classes;

procedure Main;
var
  lTPro: TTemplateProEngine;
  lInput: string;
begin
  lTPro := TTemplateProEngine.Create();
  try
    lInput := TFile.ReadAllText('test40.tpro');
    var lCompiledTemplate: ITemplateProCompiledTemplate := lTPro.Compile(lInput);
    lCompiledTemplate.ForEachToken(
      procedure(const Index: Integer; const Token: TToken)
      begin
        WriteLn('[' + Index.ToString.PadLeft(3, '0') + '] ' +
                      Token.TokenTypeAsString.PadRight(20) + ' - VALUE = ' +
                      Token.Value.PadRight(30) + ' - REF = ' +
                      Token.Ref.ToString);
      end);

  finally
    lTPro.Free;
  end;
  if DebugHook <> 0 then
  begin
    Writeln;
    Write('Finished');
    ReadLn;
  end;
end;


begin
  try
    Main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
