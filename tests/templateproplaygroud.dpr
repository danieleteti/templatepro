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
  lOutput: string;
  lOutputStream: TStringStream;
  lFileName: string;
  lOutputWithoutBOM: string;
begin
  lTPro := TTemplateProEngine.Create();
  try
    lInput := TFile.ReadAllText('test20.tpro');
    var lCompiledTemplate: ITemplateProCompiledTemplate := lTPro.Compile(lInput);
    lCompiledTemplate.ForEachToken(
      procedure(const Index: Integer; const Token: TToken)
      begin
        WriteLn('#' + Index.ToString.PadLeft(3) + ' ' +
          Token.TokenTypeAsString.PadLeft(13) + ' - VALUE = ' +
          Token.Value.PadRight(20) + ' - REF = ' + Token.Ref.ToString);
      end);

  finally
    lTPro.Free;
  end;
  if DebugHook <> 0 then
  begin
    write('Finished');
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
