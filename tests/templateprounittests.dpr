// ***************************************************************************
//
// Copyright (c) 2016-2025 Daniele Teti
//
// https://github.com/danieleteti/templatepro
//
// ***************************************************************************
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// ***************************************************************************

program templateprounittests;

{$APPTYPE CONSOLE}
{$WARN SYMBOL_PLATFORM OFF}
{$R *.res}

uses
  System.Generics.Collections,
  System.IOUtils,
  System.Rtti,
  System.Classes,
  System.SysUtils,
  System.StrUtils,
  System.DateUtils,
  UtilsU in 'UtilsU.pas',
  TemplatePro in '..\TemplatePro.pas',
  JsonDataObjects in '..\JsonDataObjects.pas',
  MVCFramework.Nullables in '..\MVCFramework.Nullables.pas';

const
  TestFileNameFilter = '*'; // '*' means "all files', '' means no file-based tests

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
  WriteLn('TestTokenWriteReadFromFile             : OK');
end;

procedure TestHTMLEntities;
begin
  Assert(HTMLEncode('daniele') = 'daniele', '1000');
  Assert(HTMLEncode('<div>hello</div>') = '&lt;div&gt;hello&lt;/div&gt;', '1010');
  Assert(HTMLEncode('řšč') = '&#345;&#353;&#269;', '1020'); // https://r12a.github.io/app-conversion/
  Assert(HTMLEncode('¢') = '&cent;', '1030');
  Assert(HTMLEncode('£') = '&pound;', '1040');
  Assert(HTMLEncode('€') = '&euro;', '1050');
  Assert(HTMLEncode('©') = '&copy;', '1060');
  Assert(HTMLEncode('®') = '&reg;', '1070'); // https://home.unicode.org/
  Assert(HTMLEncode('ab😀cd') = 'ab&#128512;cd', '1080'); // https://home.unicode.org/
  Assert(HTMLEncode('✌') = '&#9996;', HTMLEncode('✌')); // https://home.unicode.org/
  Assert(HTMLEncode('👍') = '&#128077;', HTMLEncode('👍')); // https://home.unicode.org/
  WriteLn('TestHTMLEntities                       : OK');
end;

procedure TestGetTValueFromPath;
  procedure SimpleObject;
  begin
    var lObj := TDataItem.Create('Value1', 'Value2', 'Value3', 4);
    try
      var lValue := GetTValueFromPath(lObj, 'Prop1');
      lValue := GetTValueFromPath(lObj, 'Prop2');
      lValue := GetTValueFromPath(lObj, 'Prop3');
      lValue := GetTValueFromPath(lObj, 'PropInt');
    finally
      lObj.Free;
    end;
  end;
  procedure ListOfObjects;
  begin
    var lList := TObjectList<TDataItem>.Create(True);
    try
      lList.Add(TDataItem.Create('Value1.1', 'Value2.1', 'Value3.1', 4));
      lList.Add(TDataItem.Create('Value1.2', 'Value2.2', 'Value3.2', 5));
      lList.Add(TDataItem.Create('Value1.3', 'Value2.2', 'Value3.2', 6));

      var lValue := GetTValueFromPath(lList, '[0].Prop1');
      lValue := GetTValueFromPath(lList, '[0].Prop1');
      lValue := GetTValueFromPath(lList, '[1].Prop1');
      lValue := GetTValueFromPath(lList, '[2].Prop1');
    finally
      lList.Free;
    end;
  end;
  procedure ListOfListOfObjects;
  begin
    var lList := TObjectList<TObjectList<TDataItem>>.Create(True);
    try
      lList.Add(TObjectList<TDataItem>.Create(True));
      lList.Last.Add(TDataItem.Create('Value1.1', 'Value2.1', 'Value3.1', 1));

      lList.Add(TObjectList<TDataItem>.Create(True));
      lList.Last.Add(TDataItem.Create('Value2.1', 'Value2.2', 'Value2.3', 2));
      lList.Last.Add(TDataItem.Create('Value2.2', 'Value2.2', 'Value2.3', 3));

      lList.Add(TObjectList<TDataItem>.Create(True));
      lList.Last.Add(TDataItem.Create('Value3.1', 'Value3.2', 'Value3.3', 4));
      lList.Last.Add(TDataItem.Create('Value3.2', 'Value3.2', 'Value3.3', 5));
      lList.Last.Add(TDataItem.Create('Value3.2', 'Value3.2', 'Value3.3', 6));

      var lValue := GetTValueFromPath(lList, '[0][0].Prop1');
      lValue := GetTValueFromPath(lList, '[1][0].Prop1');
      lValue := GetTValueFromPath(lList, '[1][1].Prop1');
      lValue := GetTValueFromPath(lList, '[2][0].Prop1');
      lValue := GetTValueFromPath(lList, '[2][1].Prop1');
      lValue := GetTValueFromPath(lList, '[2][2].Prop1');
    finally
      lList.Free;
    end;
  end;

begin
  SimpleObject;
  ListOfObjects;
  ListOfListOfObjects;
  WriteLn('TestGetTValueFromPath                  : OK');
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

  Assert('Daniele hello world Teti' = lOutput1, lOutput1);
  Assert('Bruce hello world Banner' = lOutput2, lOutput2);

  WriteLn('TestWriteReadFromFile                  : OK');
end;

procedure Main;
var
  lTPro: TTProCompiler;
  lInput: string;
  lItems, lItemsWithFalsy: TObjectList<TDataItem>;
begin
  var lFailed := False;
  var lActualOutput: String := '';
  lTPro := TTProCompiler.Create;
  try
    var lInputFileNames := TDirectory.GetFiles('..\test_scripts\', '*.tpro',
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
        Write(TPath.GetFileName(lFile).PadRight(38));
        var lTestScriptsFolder := TPath.Combine(GetModuleName(HInstance), '..', '..', 'test_scripts');
        lActualOutput := '';
        var lCompiledTemplate: ITProCompiledTemplate;
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
        lCompiledTemplate.SetData('myhtml', '<div>this <strong>HTML</strong>řšč</div>');
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
                  var lCustomers := GetCustomersDataset;
                  try
                    var lCustomer := GetSingleCustomerDataset;
                    try
                      var lEmptyDataSet := GetEmptyDataset;
                      try
                        var lDataItemWithChild := TDataItemWithChild.Create('value1', 1);
                        try
                          var lDataItemWithChildList := TDataItemWithChildList.Create('value1','value2','value3',3);
                          try
                            var lDataItemAsObjectsList := TObjectList<TDataItemWithChild>.Create(True);
                            try
                              lDataItemAsObjectsList.Add(TDataItemWithChild.Create('Str0', 0));
                              lDataItemAsObjectsList.Add(TDataItemWithChild.Create('Str1', 1));
                              lDataItemAsObjectsList.Add(TDataItemWithChild.Create('Str2', 2));

                              var lUltraNestedList := TObjectList<TObjectList<TObjectList<TSimpleDataItem>>>.Create(True);
                              try
                                lUltraNestedList.Add(TObjectList<TObjectList<TSimpleDataItem>>.Create(True));
                                lUltraNestedList.Last.Add(TObjectList<TSimpleDataItem>.Create(True));

                                lUltraNestedList.Add(TObjectList<TObjectList<TSimpleDataItem>>.Create(True));
                                lUltraNestedList.Last.Add(TObjectList<TSimpleDataItem>.Create(True));
                                lUltraNestedList.Last.Last.Add(TSimpleDataItem.Create('Value1'));
                                lUltraNestedList.Last.Last.Add(TSimpleDataItem.Create('Value1.1'));

                                lUltraNestedList.Add(TObjectList<TObjectList<TSimpleDataItem>>.Create(True));
                                lUltraNestedList.Last.Add(TObjectList<TSimpleDataItem>.Create(True));
                                lUltraNestedList.Last.Last.Add(TSimpleDataItem.Create('Value2'));
                                lUltraNestedList.Last.Last.Add(TSimpleDataItem.Create('Value2.1'));

                                lUltraNestedList.Add(TObjectList<TObjectList<TSimpleDataItem>>.Create(True));
                                lUltraNestedList.Last.Add(TObjectList<TSimpleDataItem>.Create(True));
                                lUltraNestedList.Last.Last.Add(TSimpleDataItem.Create('Value3'));
                                lUltraNestedList.Last.Last.Add(TSimpleDataItem.Create('Value3.1'));

                                var lEmptyList := TObjectList<TObjectList<TObjectList<TSimpleDataItem>>>.Create(True);
                                try
                                  lEmptyList.Add(TObjectList<TObjectList<TSimpleDataItem>>.Create(True));
                                  lEmptyList.Last.Add(TObjectList<TSimpleDataItem>.Create(True));
                                  var lTestDataSet := GetTestDataset;
                                  try
                                    var lSimpleNested := TSimpleNested1.Create('ValueNested');
                                    try
                                      lCompiledTemplate.SetData('emptydataset', lEmptyDataSet);
                                      lCompiledTemplate.SetData('customer', lCustomer);
                                      lCompiledTemplate.SetData('customers', lCustomers);
                                      lCompiledTemplate.SetData('testdst', lTestDataSet);
                                      lCompiledTemplate.SetData('objects', lItems);
                                      lCompiledTemplate.SetData('dataitems', lDataItemWithChildList);
                                      lCompiledTemplate.SetData('dataitemsasobjectlist', lDataItemAsObjectsList);
                                      lCompiledTemplate.SetData('ultranestedlist', lUltraNestedList);
                                      lCompiledTemplate.SetData('emptylist', lEmptyList);
                                      lCompiledTemplate.SetData('nested', lSimpleNested);
                                      lCompiledTemplate.SetData('objectsb', lItemsWithFalsy);
                                      lCompiledTemplate.SetData('jsonobj', lJSONObj);
                                      lCompiledTemplate.SetData('json2', lJSONObj2);
                                      lCompiledTemplate.SetData('dataitem', lDataItemWithChild);
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
                                      lSimpleNested.Free;
                                    end;
                                  finally
                                    lTestDataSet.Free;
                                  end;
                                finally
                                  lEmptyList.Free;
                                end;
                              finally
                                lUltraNestedList.Free;
                              end;
                            finally
                              lDataItemAsObjectsList.Free;
                            end;
                          finally
                            lDataItemWithChildList.Free;
                          end;
                        finally
                          lDataItemWithChild.Free;
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

{$IF Defined(MSWINDOWS)}
  if DebugHook <> 0 then
  begin
    WriteLn('Press return to exit');
    Readln;
    Halt(1);
    Exit;
  end;
{$ENDIF}

  if lFailed then
  begin
    Readln;
    Halt(1);
  end
  else
  begin
    if DebugHook = 0 then
    begin
      Sleep(2000);
    end;
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
    if (TestFileNameFilter = '') or (TestFileNameFilter = '*') then
    begin
      TestTokenWriteReadFromFile;
      TestWriteReadFromFile;
      TestHTMLEntities;
      TestGetTValueFromPath;
    end;
    Main;
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      if DebugHook <> 0 then
      begin
        Write(E.Message);
        ReadLn;
      end;
      Halt(1);
    end;
  end;

end.
