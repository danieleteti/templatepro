program templateprotestbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections,
  System.IOUtils,
  TemplatePro in '..\TemplatePro.pas',
  System.Classes,
  UtilsU in 'UtilsU.pas',
  Data.DB,
  TemplatePro.Utils in '..\TemplatePro.Utils.pas', System.Rtti;

procedure Main;
var
  lTPro: TTProCompiler;
  lInput: string;
  lItems: TObjectList<TDataItem>;
  lOutput: String;
  lCustomers: TDataSet;
const
  FILENAME = 'testbed70';
begin
  try
    lTPro := TTProCompiler.Create();
    try
      lInput := TFile.ReadAllText(FILENAME + '.tpro');
      var lCompiledTemplate := lTPro.Compile(lInput);
      try
        lCompiledTemplate.ForEachToken(
          procedure(const Index: Integer; const Token: TToken)
          begin
            WriteLn('[' + Index.ToString.PadLeft(3, '0') + '] ' +
                          Token.TokenTypeAsString.PadRight(20) + ' - VALUE = ' +
                          String(Token.Value).PadRight(30) +
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
        lCompiledTemplate.SetData('valuedate', EncodeDate(2024,8,20));
        lCompiledTemplate.AddTemplateFunction('sayhello',
          function(const aValue: TValue; const aParameters: TArray<string>): string
          begin
            Result := 'Hello There';
          end);
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
  except
    on E: Exception do
    begin
      Writeln(E.Message);
    end;
  end;

end;


begin
  try
    Main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  Writeln;
  Write('Press return to EXIT');
  ReadLn;
end.

