program templateprounittests;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.Generics.Collections,
  System.IOUtils,
  System.Rtti,
  System.Classes,
  System.DateUtils,
  UtilsU in 'UtilsU.pas',
  TemplatePro in '..\TemplatePro.pas',
  JsonDataObjects in '..\JsonDataObjects.pas',
  MVCFramework.Nullables in '..\MVCFramework.Nullables.pas', System.SysUtils;

const
  TestFileNameFilter = '*'; // '*' means "all files'

function SayHelloFilter(const aValue: TValue; const aParameters: TArray<TFilterParameter>): TValue;
begin
  Result := 'Hello ' + aValue.AsString;
end;

procedure TestTokenWriteReadFromFile;
var
  lBW: TBinaryWriter;
  lToken: TToken;
  lBR: TBinaryReader;
  lToken2: TToken;
begin
  lBW := TBinaryWriter.Create(TFileStream.Create('output.tp', fmCreate or fmShareDenyNone), nil, True);
  try
    lToken := TToken.Create(ttFor, 'value1', 'value2', -1, 2);
    lToken.SaveToBytes(lBW);
  finally
    lBW.Free;
  end;

  lBR := TBinaryReader.Create(TFileStream.Create('output.tp', fmOpenRead or fmShareDenyNone), nil, True);
  try
    lToken2 := TToken.CreateFromBytes(lBR);
  finally
    lBR.Free;
  end;

  Assert(lToken.TokenType = lToken2.TokenType);
  Assert(lToken.Value1 = lToken2.Value1);
  Assert(lToken.Value2 = lToken2.Value2);
  Assert(lToken.Ref1 = lToken2.Ref1);
  Assert(lToken.Ref2 = lToken2.Ref2);
  WriteLn('TestTokenWriteReadFromFile       : OK');
end;

procedure TestWriteReadFromFile;
var
  lCompiler: TTProCompiler;
  lCompiledTmpl: ITProCompiledTemplate;
  lOutput1: string;
  lOutput2: string;
begin
  lCompiler := TTProCompiler.Create();
  try
    lCompiledTmpl := lCompiler.Compile('{{:value1}} hello world {{:value2}}');
    lCompiledTmpl.SaveToFile('output.tpc');
  finally
    lCompiler.Free;
  end;

  lCompiledTmpl := TTProCompiledTemplate.CreateFromFile('output.tpc');
  lCompiledTmpl.SetData('value1', 'Daniele');
  lCompiledTmpl.SetData('value2', 'Teti');
  lOutput1 := lCompiledTmpl.Render;

  lCompiledTmpl.ClearData;
  lCompiledTmpl.SetData('value1', 'Bruce');
  lCompiledTmpl.SetData('value2', 'Banner');
  lOutput2 := lCompiledTmpl.Render;

  Assert('Daniele hello world Teti' = lOutput1);
  Assert('Bruce hello world Banner' = lOutput2);

  WriteLn('TestWriteReadFromFile            : OK');
end;

procedure Main;
var
  lTPro: TTProCompiler;
  lInput: string;
  lItems, lItemsWithFalsy: TObjectList<TDataItem>;
begin
  var
  lFailed := False;
  var
    lActualOutput: String := '';
  lTPro := TTProCompiler.Create;
  try
    var
    lInputFileNames := TDirectory.GetFiles('..\test_scripts\', '*.tpro',
      function(const Path: string; const SearchRec: TSearchRec): Boolean
      begin
        Result := (not String(SearchRec.Name).StartsWith('included')) and
          (not String(SearchRec.Name).StartsWith('layout')) and ((TestFileNameFilter = '*') or String(SearchRec.Name)
          .Contains(TestFileNameFilter));
        Result := Result and not(String(SearchRec.Name).StartsWith('_'));
      end);
    for var lFile in lInputFileNames do
    begin
      try
        if TFile.Exists(lFile + '.failed.txt') then
        begin
          TFile.Delete(lFile + '.failed.txt');
        end;

        lInput := TFile.ReadAllText(lFile, TEncoding.UTF8);
        Write(TPath.GetFileName(lFile).PadRight(32));
        var
        lTestScriptsFolder := TPath.Combine(GetModuleName(HInstance), '..', '..', 'test_scripts');
        lActualOutput := '';
        var
          lCompiledTemplate: ITProCompiledTemplate;
        try
          lCompiledTemplate := lTPro.Compile(lInput, lFile);
        except
          on E: Exception do
          begin
            lActualOutput := E.Message;
          end;
        end;

        if not lActualOutput.IsEmpty then
        begin
          // compilation failed, check the expected exception message
          var lExpectedExceptionMessage := TFile.ReadAllText(lFile + '.expected.exception.txt', TEncoding.UTF8);
          if lActualOutput <> lExpectedExceptionMessage then
          begin
            lFailed := True;
            WriteLn(' : WRONG EXCEPTION');
            TFile.WriteAllText(lFile + '.failed.txt', lActualOutput, TEncoding.UTF8);
          end
          else
          begin
            WriteLn(' : OK');
          end;
          Continue;
        end;
        // lCompiledTemplate.FormatSettings.DateSeparator := '-';
        // lCompiledTemplate.FormatSettings.TimeSeparator := ':';
        // lCompiledTemplate.FormatSettings.DecimalSeparator := '.';
        // lCompiledTemplate.FormatSettings.ThousandSeparator := ',';
        // lCompiledTemplate.FormatSettings.ShortDateFormat := 'yyyy-mm-dd';
        // lCompiledTemplate.FormatSettings^ := TFormatSettings.Create('en-US');
        lCompiledTemplate.SetData('value0', 'true');
        lCompiledTemplate.SetData('value1', 'true');
        lCompiledTemplate.SetData('value2', 'DANIELE2');
        lCompiledTemplate.SetData('value3', 'DANIELE3');
        lCompiledTemplate.SetData('value4', 'DANIELE4');
        lCompiledTemplate.SetData('value5', 'DANIELE5');
        lCompiledTemplate.SetData('value6', 'DANIELE6');
        lCompiledTemplate.SetData('intvalue0', 0);
        lCompiledTemplate.SetData('intvalue1', 1);
        lCompiledTemplate.SetData('intvalue2', 2);
        lCompiledTemplate.SetData('intvalue10', 10);
        lCompiledTemplate.SetData('floatvalue', 1234.5678);
        lCompiledTemplate.SetData('myhtml', '<div>this <strong>HTML</strong></div>');
        lCompiledTemplate.SetData('valuedate', EncodeDate(2024, 8, 20));
        lCompiledTemplate.SetData('valuedatetime', EncodeDateTime(2024, 8, 20, 10, 20, 30, 0));
        lCompiledTemplate.SetData('valuetime', EncodeTime(10, 20, 30, 0));
        lCompiledTemplate.SetData('phrasewithquotes', 'This "and that" with ''this and that''');
        lCompiledTemplate.AddFilter('sayhello', SayHelloFilter);
        lCompiledTemplate.OnGetValue :=
            procedure(const DataSource, Members: string; var Value: TValue; var Handled: Boolean)
          begin
            if SameText(DataSource, 'external') then
            begin
              if Members.IsEmpty then
              begin
                Value := 'this is an external value';
              end
              else
              begin
                if SameText(Members, 'proptrue') then
                begin
                  Value := True;
                end
                else if SameText(Members, 'propfalse') then
                begin
                  Value := False;
                end
                else
                begin
                  Value := TValue.Empty;
                end;
              end;
              Handled := True;
            end;
          end;

        var
        lJSONArr := TJsonBaseObject.ParseFromFile(TPath.Combine(lTestScriptsFolder, 'people.json')) as TJsonArray;
        try
          var
          lJSONObj := TJsonObject.Create;
          try
            lJSONObj.A['people'] := lJSONArr.Clone;
            var
            lJSONObj2 := TJsonBaseObject.ParseFromFile(TPath.Combine(lTestScriptsFolder, 'test.json')) as TJsonObject;
            try
              lItems := GetItems;
              try
                lItemsWithFalsy := GetItems(True);
                try
                  lCompiledTemplate.SetData('obj', lItems[0]);
                  var
                  lCustomers := GetCustomersDataset;
                  try
                    var
                    lCustomer := GetSingleCustomerDataset;
                    try
                      var
                      lEmptyDataSet := GetEmptyDataset;
                      try
                        lCompiledTemplate.SetData('emptydataset', lEmptyDataSet);
                        lCompiledTemplate.SetData('customer', lCustomer);
                        lCompiledTemplate.SetData('customers', lCustomers);
                        lCompiledTemplate.SetData('objects', lItems);
                        lCompiledTemplate.SetData('objectsb', lItemsWithFalsy);
                        lCompiledTemplate.SetData('jsonobj', lJSONObj);
                        lCompiledTemplate.SetData('json2', lJSONObj2);
                        lActualOutput := '';
                        try
                          lActualOutput := lCompiledTemplate.Render;
                        except
                          on E: Exception do
                          begin
                            lActualOutput := E.Message;
                          end;
                        end;
                        var
                        lExpectedOutput := TFile.ReadAllText(lFile + '.expected.txt', TEncoding.UTF8);
                        if lActualOutput <> lExpectedOutput then
                        begin
                          WriteLn(' : FAILED');
                          // lCompiledTemplate.DumpToFile(lFile + '.failed.dump.txt');
                          TFile.WriteAllText(lFile + '.failed.txt', lActualOutput, TEncoding.UTF8);
                          lFailed := True;
                        end
                        else
                        begin
                          if TFile.Exists(lFile + '.failed.txt') then
                          begin
                            TFile.Delete(lFile + '.failed.txt');
                          end;
                          if TFile.Exists(lFile + '.failed.dump.txt') then
                          begin
                            TFile.Delete(lFile + '.failed.dump.txt');
                          end;
                          WriteLn(' : OK');
                        end;
                      finally
                        lEmptyDataSet.Free;
                      end;
                    finally
                      lCustomer.Free;
                    end;
                  finally
                    lCustomers.Free;
                  end;
                finally
                  lItemsWithFalsy.Free;
                end;
              finally
                lItems.Free;
              end;
            finally
              lJSONObj2.Free;
            end;
          finally
            lJSONObj.Free;
          end;
        finally
          lJSONArr.Free;
        end;
      except
        on E: Exception do
        begin
          WriteLn(' : FAIL - ' + E.Message);
          lFailed := True;
        end;
      end;
    end;
  finally
    lTPro.Free;
  end;

  if DebugHook <> 0 then
    Readln;

  if lFailed then
  begin
    Halt(1);
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    TDirectory.CreateDirectory('output');
    WriteLn('   |----------------------------------|');
    WriteLn('---| TEMPLATE PRO ' + TEMPLATEPRO_VERSION + '  - UNIT TESTS |---');
    WriteLn('   |----------------------------------|');
    WriteLn;
    if TestFileNameFilter = '*' then
    begin
      TestTokenWriteReadFromFile;
      TestWriteReadFromFile;
    end;
    Main;
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;

end.
