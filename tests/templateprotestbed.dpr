program templateprotestbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections,
  System.IOUtils,
  TemplateProU in '..\TemplateProU.pas',
  System.Classes,
  UtilsU in 'UtilsU.pas',
  Data.DB;

procedure Main;
var
  lTPro: TTemplateProEngine;
  lInput: string;
  lItems: TObjectList<TDataItem>;
  lOutput: String;
  lCustomers: TDataSet;
const
  FILENAME = 'testbed40';
begin
  lTPro := TTemplateProEngine.Create();
  try
    lInput := TFile.ReadAllText(FILENAME + '.tpro');
    var lCompiledTemplate := lTPro.Compile(lInput);
    try
      lCompiledTemplate.ForEachToken(
        procedure(const Index: Integer; const Token: TToken)
        begin
          WriteLn('[' + Index.ToString.PadLeft(3, '0') + '] ' +
                        Token.TokenTypeAsString.PadRight(20) + ' - VALUE = ' +
                        Token.Value.PadRight(30) +
                        ' - REF1 = ' + Token.Ref1.ToString +
                        ' - REF2 = ' + Token.Ref2.ToString);
        end);
      //Readln;
      WriteLn('-------------------------------');
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
        lCustomers := GetCustomersDataset;
        try
          lCompiledTemplate.SetData('customers', lCustomers);
          lCompiledTemplate.SetData('objects', lItems);
          lOutput := lCompiledTemplate.Render;
          TFile.WriteAllText(FILENAME + '.txt', lOutput);
        finally
          lCustomers.Free;
        end;
      finally
        lItems.Free;
      end;
    finally
      lCompiledTemplate.Free;
    end;
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

