program templateprounittests;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections,
  System.IOUtils,
  System.Classes,
  UtilsU in 'UtilsU.pas',
  TemplatePro in '..\TemplatePro.pas';

procedure Main;
var
  lTPro: TTProCompiler;
  lInput: string;
  lItems: TObjectList<TDataItem>;
begin
  var lFailed := False;
  lTPro := TTProCompiler.Create;
  try
    var lInputFileNames := TDirectory.GetFiles('..\test_scripts\', '*.tpro');
    for var lFile in lInputFileNames do
    begin
      lInput := TFile.ReadAllText(lFile);
      Write(TPath.GetFileName(lFile));
      var lCompiledTemplate := lTPro.Compile(lInput);
      try
        lCompiledTemplate.SetData('value0','true');
        lCompiledTemplate.SetData('value1','true');
        lCompiledTemplate.SetData('value2','DANIELE2');
        lCompiledTemplate.SetData('value3','DANIELE3');
        lCompiledTemplate.SetData('value4','DANIELE4');
        lCompiledTemplate.SetData('value5','DANIELE5');
        lCompiledTemplate.SetData('value6','DANIELE6');
        lItems := GetItems;
        try
          lCompiledTemplate.SetData('obj', lItems[0]);
          var lCustomers := GetCustomersDataset;
          try
            lCompiledTemplate.SetData('customers', lCustomers);
            lCompiledTemplate.SetData('objects', lItems);
            var lActualOutput := lCompiledTemplate.Render;
            var lExpectedOutput := TFile.ReadAllText(lFile + '.expected.txt');
            if lActualOutput <> lExpectedOutput then
            begin
              WriteLn(': FAILED');
              TFile.WriteAllText(lFile + '.failed.txt', lActualOutput);
              lFailed := True;
            end
            else
            begin
              if TFile.Exists(lFile + '.failed.txt') then
              begin
                TFile.Delete(lFile + '.failed.txt');
              end;
              WriteLn(': OK');
            end;
          finally
            lCustomers.Free;
          end;
        finally
          lItems.Free;
        end;
      finally
        lCompiledTemplate.Free;
      end;
    end;
  finally
    lTPro.Free;
  end;
  if lFailed or (DebugHook <> 0) then
  begin
    Readln;
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
