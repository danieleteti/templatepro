unit MainTestU;

interface

procedure Main;

implementation

uses
  TemplateProU,
  System.IOUtils,
  System.SysUtils,
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
    lOutputStream := TStringStream.Create;
    try
      lFileName := 'testcases\test10';
      lInput := TFile.ReadAllText(lFileName + '.input', TEncoding.UTF8);
      lOutput := TFile.ReadAllText(lFileName + '.output', TEncoding.UTF8);
      lTPro.Compile(lInput, lOutputStream);
      lOutputWithoutBOM := lOutputStream.DataString.Substring(3);
      if lOutputWithoutBOM <> lOutput then
      begin
        Writeln('** FAIL on file ', lFileName);
        Writeln('  > Expected: ');
        Writeln(lOutput);
        Writeln('  > Actual: ');
        Writeln(lOutputWithoutBOM);
      end;
    finally
      lOutputStream.Free;
    end;
  finally
    lTPro.Free;
  end;
  if DebugHook <> 0 then
  begin
    write('Finished');
    ReadLn;
  end;
end;

end.
