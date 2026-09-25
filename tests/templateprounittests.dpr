// ***************************************************************************
//
// Copyright (c) 2016-2026 Daniele Teti
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
  System.StrUtils,
  System.RegularExpressions,
  System.DateUtils,
  System.Diagnostics,
  Data.DB,
  UtilsU in 'UtilsU.pas',
  TemplatePro in '..\TemplatePro.pas',
  TemplatePro.Types in '..\TemplatePro.Types.pas',
  JsonDataObjects in '..\JsonDataObjects.pas',
  MVCFramework.Nullables in '..\MVCFramework.Nullables.pas',
  System.SysUtils,
  ExprEvaluator in '..\ExprEvaluator.pas';

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
  WriteLn('TestTokenWriteReadFromFile'.PadRight(45) + ' : OK');
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
  // Test ampersand encoding (critical for XSS prevention)
  Assert(HTMLEncode('&') = '&amp;', '1090');
  Assert(HTMLEncode('Tom & Jerry') = 'Tom &amp; Jerry', '1091');
  // Test quote encoding
  Assert(HTMLEncode('"') = '&quot;', '1100');
  Assert(HTMLEncode('say "hello"') = 'say &quot;hello&quot;', '1101');
  Assert(HTMLEncode('''') = '&#39;', '1110');
  // Test plus sign is NOT encoded (was incorrectly encoded as &quot; before fix)
  Assert(HTMLEncode('+') = '+', '1120');
  Assert(HTMLEncode('1+1=2') = '1+1=2', '1121');
  // Test combined special chars
  Assert(HTMLEncode('<script>alert("XSS")</script>') = '&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;', '1130');
  Assert(HTMLEncode('a < b & c > d') = 'a &lt; b &amp; c &gt; d', '1131');
  WriteLn('TestHTMLEntities'.PadRight(45) + ' : OK');
end;

procedure TestExpressionEvaluator;
var
  lCompiler: TTProCompiler;
  lCompiledTmpl: ITProCompiledTemplate;
  lResult: TValue;
  lIntVal: Integer;
  lDblVal: Double;
begin
  lCompiler := TTProCompiler.Create();
  try
    lCompiledTmpl := lCompiler.Compile('dummy template');

    // Set up template variables
    lCompiledTmpl.SetData('price', 100);
    lCompiledTmpl.SetData('qty', 5);
    lCompiledTmpl.SetData('discount', 0.1);
    lCompiledTmpl.SetData('name', 'John');

    // Test basic arithmetic with template variables
    lResult := lCompiledTmpl.EvaluateExpression('price * qty');
    lIntVal := lResult.AsVariant;
    Assert(lIntVal = 500, 'price * qty should be 500, got: ' + IntToStr(lIntVal));

    // Test complex expression
    lResult := lCompiledTmpl.EvaluateExpression('price * qty * (1 - discount)');
    lDblVal := lResult.AsVariant;
    Assert(Abs(lDblVal - 450.0) < 0.001, 'price * qty * (1 - discount) should be 450');

    // Test string functions
    lResult := lCompiledTmpl.EvaluateExpression('Length(name)');
    lIntVal := lResult.AsVariant;
    Assert(lIntVal = 4, 'Length(name) should be 4');

    lResult := lCompiledTmpl.EvaluateExpression('Upper(name)');
    Assert(lResult.AsString = 'JOHN', 'Upper(name) should be JOHN');

    // Test conditional expressions
    lResult := lCompiledTmpl.EvaluateExpression('if price > 50 then "expensive" else "cheap"');
    Assert(lResult.AsString = 'expensive', 'Conditional should return expensive');

    // Test comparison operators
    lResult := lCompiledTmpl.EvaluateExpression('price > 50');
    Assert(Boolean(lResult.AsVariant) = True, 'price > 50 should be True');

    lResult := lCompiledTmpl.EvaluateExpression('qty >= 5');
    Assert(Boolean(lResult.AsVariant) = True, 'qty >= 5 should be True');

    // Test logical operators
    lResult := lCompiledTmpl.EvaluateExpression('price > 50 and qty > 3');
    Assert(Boolean(lResult.AsVariant) = True, 'price > 50 and qty > 3 should be True');

    // Test pure expressions (without template variables)
    lResult := lCompiledTmpl.EvaluateExpression('10 + 20 * 2');
    lIntVal := lResult.AsVariant;
    Assert(lIntVal = 50, '10 + 20 * 2 should be 50');

    lResult := lCompiledTmpl.EvaluateExpression('sqrt(16)');
    lIntVal := lResult.AsVariant;
    Assert(lIntVal = 4, 'sqrt(16) should be 4');

    WriteLn('TestExpressionEvaluator'.PadRight(45) + ' : OK');
  finally
    lCompiler.Free;
  end;
end;

procedure TestExpressionInTemplate;
var
  lCompiler: TTProCompiler;
  lCompiledTmpl: ITProCompiledTemplate;
  lOutput: string;
begin
  lCompiler := TTProCompiler.Create();
  try
    // Test basic expression in template
    lCompiledTmpl := lCompiler.Compile('Total: {{@price * qty}}');
    lCompiledTmpl.SetData('price', 100);
    lCompiledTmpl.SetData('qty', 5);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'Total: 500', 'Expected "Total: 500", got: ' + lOutput);

    // Test expression with space after @
    lCompiledTmpl := lCompiler.Compile('Total: {{@ price * qty}}');
    lCompiledTmpl.SetData('price', 100);
    lCompiledTmpl.SetData('qty', 5);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'Total: 500', 'Expected "Total: 500" with space, got: ' + lOutput);

    // Test complex expression
    lCompiledTmpl := lCompiler.Compile('Discounted: {{@price * qty * (1 - discount)}}');
    lCompiledTmpl.SetData('price', 100);
    lCompiledTmpl.SetData('qty', 5);
    lCompiledTmpl.SetData('discount', 0.1);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'Discounted: 450', 'Expected "Discounted: 450", got: ' + lOutput);

    // Test string expression
    lCompiledTmpl := lCompiler.Compile('Name: {{@Upper(name)}}');
    lCompiledTmpl.SetData('name', 'john');
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'Name: JOHN', 'Expected "Name: JOHN", got: ' + lOutput);

    // Test conditional expression
    lCompiledTmpl := lCompiler.Compile('Status: {{@if price > 50 then "expensive" else "cheap"}}');
    lCompiledTmpl.SetData('price', 100);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'Status: expensive', 'Expected "Status: expensive", got: ' + lOutput);

    // Test mixed template with regular variables and expressions
    lCompiledTmpl := lCompiler.Compile('Item: {{:name}}, Total: {{@price * qty}}');
    lCompiledTmpl.SetData('name', 'Widget');
    lCompiledTmpl.SetData('price', 25);
    lCompiledTmpl.SetData('qty', 4);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'Item: Widget, Total: 100', 'Expected "Item: Widget, Total: 100", got: ' + lOutput);
    WriteLn('TestExpressionInTemplate'.PadRight(45) + ' : OK');
  finally
    lCompiler.Free;
  end;
end;

procedure TestExpressionWithFilters;
var
  lCompiler: TTProCompiler;
  lCompiledTmpl: ITProCompiledTemplate;
  lOutput: string;
  lExpected: string;
begin
  lCompiler := TTProCompiler.Create();
  try
    // Test expression with single filter (use template's FormatSettings)
    lCompiledTmpl := lCompiler.Compile('Total: {{@price * qty|formatfloat,"0.00"}}');
    lCompiledTmpl.SetData('price', 100);
    lCompiledTmpl.SetData('qty', 3);
    lOutput := lCompiledTmpl.Render;
    lExpected := 'Total: ' + FormatFloat('0.00', 300, lCompiledTmpl.FormatSettings^);
    Assert(lOutput = lExpected, 'Expected "' + lExpected + '", got: ' + lOutput);

    // Test expression with multiple chained filters
    lCompiledTmpl := lCompiler.Compile('Code: {{@value * 10|formatfloat,"0"|lpad,8,"0"}}');
    lCompiledTmpl.SetData('value', 12);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'Code: 00000120', 'Expected "Code: 00000120", got: ' + lOutput);

    // Test expression with uppercase filter
    lCompiledTmpl := lCompiler.Compile('Name: {{@Upper(name)|lpad,10}}');
    lCompiledTmpl.SetData('name', 'test');
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'Name:       TEST', 'Expected "Name:       TEST", got: ' + lOutput);

    // Test expression without filter (regression test)
    lCompiledTmpl := lCompiler.Compile('Sum: {{@a + b}}');
    lCompiledTmpl.SetData('a', 10);
    lCompiledTmpl.SetData('b', 20);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'Sum: 30', 'Expected "Sum: 30", got: ' + lOutput);

    WriteLn('TestExpressionWithFilters'.PadRight(45) + ' : OK');
  finally
    lCompiler.Free;
  end;
end;

procedure TestExpressionInIf;
var
  lCompiler: TTProCompiler;
  lCompiledTmpl: ITProCompiledTemplate;
  lOutput: string;
begin
  lCompiler := TTProCompiler.Create();
  try
    // Test expression in if condition
    lCompiledTmpl := lCompiler.Compile('{{if @(price > 100)}}expensive{{endif}}');
    lCompiledTmpl.SetData('price', 150);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'expensive', 'Expected "expensive", got: ' + lOutput);

    // Test expression evaluating to false
    lCompiledTmpl := lCompiler.Compile('{{if @(price > 100)}}expensive{{endif}}');
    lCompiledTmpl.SetData('price', 50);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = '', 'Expected empty, got: ' + lOutput);

    // Test complex expression in if
    lCompiledTmpl := lCompiler.Compile('{{if @(price * qty > 500)}}big order{{else}}small order{{endif}}');
    lCompiledTmpl.SetData('price', 100);
    lCompiledTmpl.SetData('qty', 10);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'big order', 'Expected "big order", got: ' + lOutput);

    // Test with else branch
    lCompiledTmpl := lCompiler.Compile('{{if @(price * qty > 500)}}big order{{else}}small order{{endif}}');
    lCompiledTmpl.SetData('price', 10);
    lCompiledTmpl.SetData('qty', 2);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'small order', 'Expected "small order", got: ' + lOutput);

    // Test logical operators
    lCompiledTmpl := lCompiler.Compile('{{if @(price > 50 and qty >= 5)}}discount{{else}}no discount{{endif}}');
    lCompiledTmpl.SetData('price', 100);
    lCompiledTmpl.SetData('qty', 10);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'discount', 'Expected "discount", got: ' + lOutput);

    // Test with string comparison
    lCompiledTmpl := lCompiler.Compile('{{if @(status = "active")}}active user{{else}}inactive{{endif}}');
    lCompiledTmpl.SetData('status', 'active');
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'active user', 'Expected "active user", got: ' + lOutput);

    // Test nested parentheses in expression
    lCompiledTmpl := lCompiler.Compile('{{if @((price + tax) * qty > 100)}}over budget{{endif}}');
    lCompiledTmpl.SetData('price', 10);
    lCompiledTmpl.SetData('tax', 2);
    lCompiledTmpl.SetData('qty', 10);
    lOutput := lCompiledTmpl.Render;
    Assert(lOutput = 'over budget', 'Expected "over budget", got: ' + lOutput);
    WriteLn('TestExpressionInIf'.PadRight(45) + ' : OK');
  finally
    lCompiler.Free;
  end;
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
  WriteLn('TestGetTValueFromPath'.PadRight(45) + ' : OK');
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

  WriteLn('TestWriteReadFromFile'.PadRight(45) + ' : OK');
end;

procedure TestCompiledTemplateOutputIdentical;
// Verifies that a template loaded from compiled file produces
// EXACTLY the same output (byte-for-byte) as the original compiled template
var
  lCompiler: TTProCompiler;
  lOriginalTmpl: ITProCompiledTemplate;
  lLoadedTmpl: ITProCompiledTemplate;
  lOutputOriginal: string;
  lOutputLoaded: string;
  lOutputBytesOriginal: TBytes;
  lOutputBytesLoaded: TBytes;
  I: Integer;
  lTemplateSource: string;
begin
  // Test with a complex template containing various features
  lTemplateSource :=
    '<!DOCTYPE html>'#13#10 +
    '<html><head><title>{{:title}}</title></head>'#13#10 +
    '<body>'#13#10 +
    '  <h1>{{:title|uppercase}}</h1>'#13#10 +
    '  {{if showContent}}'#13#10 +
    '  <p>Value: {{:value1}} - {{:value2|lowercase}}</p>'#13#10 +
    '  {{for item in items}}'#13#10 +
    '  <li>{{:item.@@index}}: {{:item.Prop1}} = {{:item.Prop2}}</li>'#13#10 +
    '  {{endfor}}'#13#10 +
    '  {{endif}}'#13#10 +
    '  <footer>Generated: {{:timestamp}}</footer>'#13#10 +
    '</body></html>';

  lCompiler := TTProCompiler.Create();
  try
    // Compile original template
    lOriginalTmpl := lCompiler.Compile(lTemplateSource);

    // Save to file
    lOriginalTmpl.SaveToFile('output_test_identical.tpc');

    // Set data and render original
    lOriginalTmpl.SetData('title', 'Test Page');
    lOriginalTmpl.SetData('showContent', True);
    lOriginalTmpl.SetData('value1', 'First Value');
    lOriginalTmpl.SetData('value2', 'SECOND VALUE');
    lOriginalTmpl.SetData('timestamp', '2024-01-15 10:30:00');

    var lItems := TObjectList<TDataItem>.Create(True);
    try
      lItems.Add(TDataItem.Create('Item1', 'Val1', 'Extra1', 1));
      lItems.Add(TDataItem.Create('Item2', 'Val2', 'Extra2', 2));
      lItems.Add(TDataItem.Create('Item3', 'Val3', 'Extra3', 3));
      lOriginalTmpl.SetData('items', lItems);

      lOutputOriginal := lOriginalTmpl.Render;

      // Load from file
      lLoadedTmpl := TTProCompiledTemplate.CreateFromFile('output_test_identical.tpc');

      // Set EXACT same data
      lLoadedTmpl.SetData('title', 'Test Page');
      lLoadedTmpl.SetData('showContent', True);
      lLoadedTmpl.SetData('value1', 'First Value');
      lLoadedTmpl.SetData('value2', 'SECOND VALUE');
      lLoadedTmpl.SetData('timestamp', '2024-01-15 10:30:00');
      lLoadedTmpl.SetData('items', lItems);

      lOutputLoaded := lLoadedTmpl.Render;

      // Verify string equality
      Assert(lOutputOriginal = lOutputLoaded,
        'String output mismatch: Original length=' + Length(lOutputOriginal).ToString +
        ', Loaded length=' + Length(lOutputLoaded).ToString);

      // Verify byte-for-byte equality
      lOutputBytesOriginal := TEncoding.UTF8.GetBytes(lOutputOriginal);
      lOutputBytesLoaded := TEncoding.UTF8.GetBytes(lOutputLoaded);

      Assert(Length(lOutputBytesOriginal) = Length(lOutputBytesLoaded),
        'Byte length mismatch: Original=' + Length(lOutputBytesOriginal).ToString +
        ', Loaded=' + Length(lOutputBytesLoaded).ToString);

      for I := 0 to Length(lOutputBytesOriginal) - 1 do
      begin
        Assert(lOutputBytesOriginal[I] = lOutputBytesLoaded[I],
          'Byte mismatch at position ' + I.ToString +
          ': Original=$' + IntToHex(lOutputBytesOriginal[I], 2) +
          ', Loaded=$' + IntToHex(lOutputBytesLoaded[I], 2));
      end;
    finally
      lItems.Free;
    end;
  finally
    lCompiler.Free;
  end;

  WriteLn('TestCompiledTemplateOutputIdentical'.PadRight(45) + ' : OK');
end;

procedure TestCompiledTemplateTokensPreserved;
// Verifies that all token fields are correctly preserved after save/load
var
  lCompiler: TTProCompiler;
  lOriginalTmpl: ITProCompiledTemplate;
  lLoadedTmpl: ITProCompiledTemplate;
  lTemplateSource: string;
  lOutput1, lOutput2: string;
  lList1, lList2: TObjectList<TDataItem>;
begin
  // Template with various token types
  lTemplateSource :=
    '{{if condition}}TRUE{{else}}FALSE{{endif}}' +
    '{{for x in list}}[{{:x.Prop1}}]{{endfor}}' +
    '{{:value|uppercase|lpad,20}}' +
    '{{@price * qty}}';

  lCompiler := TTProCompiler.Create();
  try
    lOriginalTmpl := lCompiler.Compile(lTemplateSource);
    lOriginalTmpl.SaveToFile('output_test_tokens.tpc');

    // Test with condition=True
    lList1 := TObjectList<TDataItem>.Create(True);
    try
      lList1.Add(TDataItem.Create('A', '', '', 0));
      lList1.Add(TDataItem.Create('B', '', '', 0));
      lOriginalTmpl.SetData('condition', True);
      lOriginalTmpl.SetData('list', lList1);
      lOriginalTmpl.SetData('value', 'test');
      lOriginalTmpl.SetData('price', 10);
      lOriginalTmpl.SetData('qty', 5);
      lOutput1 := lOriginalTmpl.Render;
    finally
      lList1.Free;
    end;

    // Load and test with same data
    lLoadedTmpl := TTProCompiledTemplate.CreateFromFile('output_test_tokens.tpc');
    lList2 := TObjectList<TDataItem>.Create(True);
    try
      lList2.Add(TDataItem.Create('A', '', '', 0));
      lList2.Add(TDataItem.Create('B', '', '', 0));
      lLoadedTmpl.SetData('condition', True);
      lLoadedTmpl.SetData('list', lList2);
      lLoadedTmpl.SetData('value', 'test');
      lLoadedTmpl.SetData('price', 10);
      lLoadedTmpl.SetData('qty', 5);
      lOutput2 := lLoadedTmpl.Render;

      Assert(lOutput1 = lOutput2, 'Output mismatch with condition=True: ' + lOutput1 + ' vs ' + lOutput2);
    finally
      lList2.Free;
    end;
  finally
    lCompiler.Free;
  end;

  WriteLn('TestCompiledTemplateTokensPreserved'.PadRight(45) + ' : OK');
end;

procedure TestCompiledTemplateUnicodePreserved;
// Verifies that Unicode strings are correctly preserved in compiled templates
var
  lCompiler: TTProCompiler;
  lOriginalTmpl: ITProCompiledTemplate;
  lLoadedTmpl: ITProCompiledTemplate;
  lTemplateSource: string;
  lOutputOriginal, lOutputLoaded: string;
  lOutputBytesOriginal, lOutputBytesLoaded: TBytes;
  I: Integer;
begin
  // Template with Euro symbol (common Unicode char) and variable
  lTemplateSource :=
    'Price: '#226#130#172'100'#13#10 +  // Euro symbol as UTF-8 bytes
    'Variable: {{:myvar}}'#13#10 +
    'Upper: {{:myvar|uppercase}}';

  lCompiler := TTProCompiler.Create();
  try
    lOriginalTmpl := lCompiler.Compile(lTemplateSource);
    lOriginalTmpl.SetData('myvar', 'TestValue');
    lOutputOriginal := lOriginalTmpl.Render;

    lOriginalTmpl.SaveToFile('output_test_unicode.tpc');

    lLoadedTmpl := TTProCompiledTemplate.CreateFromFile('output_test_unicode.tpc');
    lLoadedTmpl.SetData('myvar', 'TestValue');
    lOutputLoaded := lLoadedTmpl.Render;

    // Main test: outputs must be identical
    Assert(lOutputOriginal = lOutputLoaded,
      'Unicode output mismatch: lengths ' + Length(lOutputOriginal).ToString +
      ' vs ' + Length(lOutputLoaded).ToString);

    // Verify byte-for-byte equality
    lOutputBytesOriginal := TEncoding.UTF8.GetBytes(lOutputOriginal);
    lOutputBytesLoaded := TEncoding.UTF8.GetBytes(lOutputLoaded);

    Assert(Length(lOutputBytesOriginal) = Length(lOutputBytesLoaded),
      'Byte lengths differ');

    for I := 0 to Length(lOutputBytesOriginal) - 1 do
    begin
      Assert(lOutputBytesOriginal[I] = lOutputBytesLoaded[I],
        'Byte ' + I.ToString + ' differs');
    end;

    // Verify variable values
    Assert(Pos('TestValue', lOutputLoaded) > 0, 'Variable value not found');
    Assert(Pos('TESTVALUE', lOutputLoaded) > 0, 'Uppercase value not found');
  finally
    lCompiler.Free;
  end;

  WriteLn('TestCompiledTemplateUnicodePreserved'.PadRight(45) + ' : OK');
end;

procedure TestCompiledTemplateMultipleRenders;
// Verifies that multiple renders from loaded template produce consistent output
var
  lLoadedTmpl: ITProCompiledTemplate;
  lCompiler: TTProCompiler;
  lOutput1, lOutput2, lOutput3: string;
begin
  lCompiler := TTProCompiler.Create();
  try
    var lTmpl := lCompiler.Compile('Hello {{:name}}, count={{:count}}');
    lTmpl.SaveToFile('output_test_multi.tpc');
  finally
    lCompiler.Free;
  end;

  lLoadedTmpl := TTProCompiledTemplate.CreateFromFile('output_test_multi.tpc');

  // First render
  lLoadedTmpl.SetData('name', 'World');
  lLoadedTmpl.SetData('count', 1);
  lOutput1 := lLoadedTmpl.Render;

  // Clear and second render with different data
  lLoadedTmpl.ClearData;
  lLoadedTmpl.SetData('name', 'Delphi');
  lLoadedTmpl.SetData('count', 2);
  lOutput2 := lLoadedTmpl.Render;

  // Third render with same data as first
  lLoadedTmpl.ClearData;
  lLoadedTmpl.SetData('name', 'World');
  lLoadedTmpl.SetData('count', 1);
  lOutput3 := lLoadedTmpl.Render;

  Assert(lOutput1 = 'Hello World, count=1', 'First render mismatch: ' + lOutput1);
  Assert(lOutput2 = 'Hello Delphi, count=2', 'Second render mismatch: ' + lOutput2);
  Assert(lOutput1 = lOutput3, 'Third render should match first');

  WriteLn('TestCompiledTemplateMultipleRenders'.PadRight(45) + ' : OK');
end;

procedure TestCompiledFileBinaryEquality;
// Verifies that saving twice produces identical binary files
var
  lCompiler: TTProCompiler;
  lTmpl: ITProCompiledTemplate;
  lBytes1, lBytes2: TBytes;
  I: Integer;
begin
  lCompiler := TTProCompiler.Create();
  try
    lTmpl := lCompiler.Compile(
      '{{if x}}{{for y in list}}{{:y.Name}}{{endfor}}{{endif}}' +
      '{{:value|uppercase|lpad,15}}');

    lTmpl.SaveToFile('output_binary1.tpc');
    lTmpl.SaveToFile('output_binary2.tpc');

    lBytes1 := TFile.ReadAllBytes('output_binary1.tpc');
    lBytes2 := TFile.ReadAllBytes('output_binary2.tpc');

    Assert(Length(lBytes1) = Length(lBytes2),
      'Binary file lengths differ: ' + Length(lBytes1).ToString + ' vs ' + Length(lBytes2).ToString);

    for I := 0 to Length(lBytes1) - 1 do
    begin
      Assert(lBytes1[I] = lBytes2[I],
        'Binary files differ at byte ' + I.ToString);
    end;
  finally
    lCompiler.Free;
  end;

  WriteLn('TestCompiledFileBinaryEquality'.PadRight(45) + ' : OK');
end;

procedure TestOnGetIncludedTemplate_StaticInclude;
// Tests OnGetIncludedTemplate callback for static includes at compile time
var
  lCompiler: TTProCompiler;
  lCompiledTmpl: ITProCompiledTemplate;
  lOutput: string;
  lCallbackCalled: Boolean;
  lRequestedTemplate: string;
begin
  lCallbackCalled := False;
  lRequestedTemplate := '';

  lCompiler := TTProCompiler.Create();
  try
    // Set up callback to provide template content from memory
    lCompiler.OnGetIncludedTemplate :=
      procedure(const TemplateName: string; var TemplateContent: string; var Handled: Boolean)
      begin
        lCallbackCalled := True;
        lRequestedTemplate := TemplateName;
        if TemplateName = 'header.tpro' then
        begin
          TemplateContent := '<header>{{:title}}</header>';
          Handled := True;
        end
        else
          Handled := False;
      end;

    // Template with static include
    lCompiledTmpl := lCompiler.Compile('{{include "header.tpro"}}<body>Content</body>');
    lCompiledTmpl.SetData('title', 'My Page');
    lOutput := lCompiledTmpl.Render;

    Assert(lCallbackCalled, 'Callback should have been called');
    Assert(lRequestedTemplate = 'header.tpro', 'Wrong template name requested: ' + lRequestedTemplate);
    Assert(lOutput = '<header>My Page</header><body>Content</body>',
      'Unexpected output: ' + lOutput);
  finally
    lCompiler.Free;
  end;

  WriteLn('TestOnGetIncludedTemplate_StaticInclude'.PadRight(45) + ' : OK');
end;

procedure TestOnGetIncludedTemplate_NestedIncludes;
// Tests that callback is propagated to nested includes
var
  lCompiler: TTProCompiler;
  lCompiledTmpl: ITProCompiledTemplate;
  lOutput: string;
  lTemplatesRequested: TArray<string>;
begin
  SetLength(lTemplatesRequested, 0);

  lCompiler := TTProCompiler.Create();
  try
    lCompiler.OnGetIncludedTemplate :=
      procedure(const TemplateName: string; var TemplateContent: string; var Handled: Boolean)
      begin
        SetLength(lTemplatesRequested, Length(lTemplatesRequested) + 1);
        lTemplatesRequested[High(lTemplatesRequested)] := TemplateName;

        if TemplateName = 'outer.tpro' then
        begin
          // This template includes another template
          TemplateContent := 'OUTER[{{include "inner.tpro"}}]OUTER';
          Handled := True;
        end
        else if TemplateName = 'inner.tpro' then
        begin
          TemplateContent := 'INNER';
          Handled := True;
        end
        else
          Handled := False;
      end;

    lCompiledTmpl := lCompiler.Compile('START{{include "outer.tpro"}}END');
    lOutput := lCompiledTmpl.Render;

    Assert(Length(lTemplatesRequested) = 2, 'Expected 2 template requests, got: ' + Length(lTemplatesRequested).ToString);
    Assert(lTemplatesRequested[0] = 'outer.tpro', 'First request should be outer.tpro');
    Assert(lTemplatesRequested[1] = 'inner.tpro', 'Second request should be inner.tpro');
    Assert(lOutput = 'STARTOUTER[INNER]OUTEREND', 'Unexpected output: ' + lOutput);
  finally
    lCompiler.Free;
  end;

  WriteLn('TestOnGetIncludedTemplate_NestedIncludes'.PadRight(45) + ' : OK');
end;

procedure TestOnGetIncludedTemplate_NotHandled;
// Tests that when callback sets Handled=False, the system falls back to file loading
// This test will fail gracefully since we don't have the file, but it verifies the callback behavior
var
  lCompiler: TTProCompiler;
  lCallbackCalled: Boolean;
  lHandledValue: Boolean;
begin
  lCallbackCalled := False;
  lHandledValue := False;

  lCompiler := TTProCompiler.Create();
  try
    lCompiler.OnGetIncludedTemplate :=
      procedure(const TemplateName: string; var TemplateContent: string; var Handled: Boolean)
      begin
        lCallbackCalled := True;
        // Don't handle - let it fall back to file system
        Handled := False;
        lHandledValue := Handled;
      end;

    // This should call the callback, then try to load from file (which will fail)
    try
      lCompiler.Compile('{{include "nonexistent.tpro"}}');
      Assert(False, 'Should have raised an exception for missing file');
    except
      on E: Exception do
      begin
        Assert(lCallbackCalled, 'Callback should have been called before file fallback');
        Assert(not lHandledValue, 'Handled should be False');
        Assert(Pos('nonexistent.tpro', E.Message) > 0, 'Error should mention the file name');
      end;
    end;
  finally
    lCompiler.Free;
  end;

  WriteLn('TestOnGetIncludedTemplate_NotHandled'.PadRight(45) + ' : OK');
end;

procedure TestOnGetDynamicallyIncludedTemplate;
// Tests OnGetDynamicallyIncludedTemplate callback for dynamic includes at runtime
var
  lCompiler: TTProCompiler;
  lCompiledTmpl: ITProCompiledTemplate;
  lOutput: string;
  lCallbackCalled: Boolean;
  lRequestedTemplate: string;
begin
  lCallbackCalled := False;
  lRequestedTemplate := '';

  lCompiler := TTProCompiler.Create();
  try
    // Compile template with dynamic include
    lCompiledTmpl := lCompiler.Compile('Before{{include @(templateName)}}After');

    // Set up runtime callback for dynamic includes
    lCompiledTmpl.OnGetDynamicallyIncludedTemplate :=
      procedure(const TemplateName: string; var TemplateContent: string; var Handled: Boolean)
      begin
        lCallbackCalled := True;
        lRequestedTemplate := TemplateName;
        if TemplateName = 'dynamic_content.tpro' then
        begin
          TemplateContent := '[DYNAMIC:{{:value}}]';
          Handled := True;
        end
        else
          Handled := False;
      end;

    lCompiledTmpl.SetData('templateName', 'dynamic_content.tpro');
    lCompiledTmpl.SetData('value', 'Hello');
    lOutput := lCompiledTmpl.Render;

    Assert(lCallbackCalled, 'Dynamic callback should have been called');
    Assert(lRequestedTemplate = 'dynamic_content.tpro', 'Wrong template name: ' + lRequestedTemplate);
    Assert(lOutput = 'Before[DYNAMIC:Hello]After', 'Unexpected output: ' + lOutput);
  finally
    lCompiler.Free;
  end;

  WriteLn('TestOnGetDynamicallyIncludedTemplate'.PadRight(45) + ' : OK');
end;

procedure TestOnGetIncludedTemplate_WithExtends;
// Tests OnGetIncludedTemplate callback with extends directive
var
  lCompiler: TTProCompiler;
  lCompiledTmpl: ITProCompiledTemplate;
  lOutput: string;
  lTemplatesRequested: TArray<string>;
begin
  SetLength(lTemplatesRequested, 0);

  lCompiler := TTProCompiler.Create();
  try
    lCompiler.OnGetIncludedTemplate :=
      procedure(const TemplateName: string; var TemplateContent: string; var Handled: Boolean)
      begin
        SetLength(lTemplatesRequested, Length(lTemplatesRequested) + 1);
        lTemplatesRequested[High(lTemplatesRequested)] := TemplateName;

        if TemplateName = 'layout.tpro' then
        begin
          TemplateContent := '<html>{{block "content"}}DEFAULT{{endblock}}</html>';
          Handled := True;
        end
        else
          Handled := False;
      end;

    // Child template that extends a layout
    lCompiledTmpl := lCompiler.Compile('{{extends "layout.tpro"}}{{block "content"}}CHILD CONTENT{{endblock}}');
    lOutput := lCompiledTmpl.Render;

    Assert(Length(lTemplatesRequested) = 1, 'Expected 1 template request for extends');
    Assert(lTemplatesRequested[0] = 'layout.tpro', 'Should request layout.tpro');
    Assert(lOutput = '<html>CHILD CONTENT</html>', 'Unexpected output: ' + lOutput);
  finally
    lCompiler.Free;
  end;

  WriteLn('TestOnGetIncludedTemplate_WithExtends'.PadRight(45) + ' : OK');
end;

procedure TestOnGetIncludedTemplate_MultipleTemplates;
// Tests callback with multiple different templates
var
  lCompiler: TTProCompiler;
  lCompiledTmpl: ITProCompiledTemplate;
  lOutput: string;
begin
  lCompiler := TTProCompiler.Create();
  try
    lCompiler.OnGetIncludedTemplate :=
      procedure(const TemplateName: string; var TemplateContent: string; var Handled: Boolean)
      begin
        Handled := True;
        if TemplateName = 'header.tpro' then
          TemplateContent := '<header/>'
        else if TemplateName = 'footer.tpro' then
          TemplateContent := '<footer/>'
        else if TemplateName = 'sidebar.tpro' then
          TemplateContent := '<sidebar/>'
        else
          Handled := False;
      end;

    lCompiledTmpl := lCompiler.Compile(
      '{{include "header.tpro"}}' +
      '<main>{{include "sidebar.tpro"}}Content</main>' +
      '{{include "footer.tpro"}}');
    lOutput := lCompiledTmpl.Render;

    Assert(lOutput = '<header/><main><sidebar/>Content</main><footer/>',
      'Unexpected output: ' + lOutput);
  finally
    lCompiler.Free;
  end;

  WriteLn('TestOnGetIncludedTemplate_MultipleTemplates'.PadRight(45) + ' : OK');
end;

var
  gCallerObjectDestroyed: Boolean = False;

type
  TCallerOwnedObject = class
  public
    destructor Destroy; override;
  end;

destructor TCallerOwnedObject.Destroy;
begin
  gCallerObjectDestroyed := True;
  inherited;
end;

procedure TestRenderDoesNotFreeCallerObjects;
// The object passed with SetData belongs to the caller: rendering it through a filter
// that returns it unchanged (e.g. "default") must not destroy it.
var
  lCompiler: TTProCompiler;
  lTemplate: ITProCompiledTemplate;
  lObj: TCallerOwnedObject;
begin
  gCallerObjectDestroyed := False;
  lObj := TCallerOwnedObject.Create;
  try
    lCompiler := TTProCompiler.Create;
    try
      lTemplate := lCompiler.Compile('{{:obj|default,"none"}}');
      lTemplate.SetData('obj', lObj);
      lTemplate.Render;
      lTemplate := nil;
    finally
      lCompiler.Free;
    end;
    Assert(not gCallerObjectDestroyed, 'Render destroyed an object owned by the caller');
  finally
    if not gCallerObjectDestroyed then
      lObj.Free;
  end;
  WriteLn('TestRenderDoesNotFreeCallerObjects'.PadRight(45) + ' : OK');
end;

type
  TFilterCreatedObject = class
  public
    class var LiveCount: Integer;
    constructor Create;
    destructor Destroy; override;
    function ToString: string; override;
  end;

constructor TFilterCreatedObject.Create;
begin
  inherited;
  Inc(LiveCount);
end;

destructor TFilterCreatedObject.Destroy;
begin
  Dec(LiveCount);
  inherited;
end;

function TFilterCreatedObject.ToString: string;
begin
  Result := 'NEWOBJ';
end;

procedure TestFilterObjectOwnership;
// Objects created by a custom filter belong to the engine and must be freed (no leaks in long-running
// processes); objects coming from SetData belong to the caller and must never be freed.
var
  lCompiler: TTProCompiler;
  lObj: TCallerOwnedObject;

  procedure Check(const aTemplate, aExpected: string);
  var
    lTemplate: ITProCompiledTemplate;
    lOutput: string;
  begin
    TFilterCreatedObject.LiveCount := 0;
    gCallerObjectDestroyed := False;
    lTemplate := lCompiler.Compile(aTemplate);
    lTemplate.AddFilter('newobj',
      function(const aValue: TValue; const aParameters: TArray<TFilterParameter>): TValue
      begin
        Result := TFilterCreatedObject.Create;
      end);
    lTemplate.AddFilter('same',
      function(const aValue: TValue; const aParameters: TArray<TFilterParameter>): TValue
      begin
        Result := aValue;
      end);
    lTemplate.AddFilter('describe',
      function(const aValue: TValue; const aParameters: TArray<TFilterParameter>): TValue
      begin
        Result := 'described:' + aValue.AsObject.ToString;
      end);
    lTemplate.AddFilter('boom',
      function(const aValue: TValue; const aParameters: TArray<TFilterParameter>): TValue
      begin
        raise Exception.Create('boom');
      end);
    lTemplate.SetData('obj', lObj);
    lTemplate.SetData('n', 1);
    lTemplate.SetData('empty', '');
    try
      lOutput := lTemplate.Render;
    except
      on E: ETProRenderException do
        lOutput := 'ERROR';
    end;
    Assert(StartsStr(aExpected, lOutput), aTemplate + ' - expected "' + aExpected + '...", got "' + lOutput + '"');
    Assert(TFilterCreatedObject.LiveCount = 0,
      Format('%s - %d filter-created object(s) leaked after Render', [aTemplate, TFilterCreatedObject.LiveCount]));
    lTemplate := nil;
    Assert(not gCallerObjectDestroyed, aTemplate + ' - caller-owned object destroyed');
  end;

begin
  lObj := TCallerOwnedObject.Create;
  try
    lCompiler := TTProCompiler.Create;
    try
      // an object is rendered as "(TClassName @ address)", hence the prefix match
      Check('{{:n|newobj}}', '(TFilterCreatedObject @');                  // output
      Check('{{@n + 1|newobj}}', '(TFilterCreatedObject @');              // expression output
      Check('{{:n|newobj|describe}}', 'described:NEWOBJ');                // intermediate value in a chain
      Check('{{:n|newobj|same|describe}}', 'described:NEWOBJ');           // passed through, then consumed
      Check('{{if n|newobj}}yes{{endif}}', 'yes');                        // condition
      Check('{{set x := n|newobj}}{{:x|describe}}', 'described:NEWOBJ');  // set variable
      Check('{{macro m(p)}}{{:p|newobj}}{{endmacro}}{{>m(n)}}', '(TFilterCreatedObject @'); // macro body
      Check('{{:obj|same|describe}}', 'described:' + lObj.ToString);      // caller object through custom filter
      Check('{{:empty|default,obj|describe}}', 'described:' + lObj.ToString); // caller object from "default"
      Check('{{:n|newobj|boom}}', 'ERROR');                               // filter fails on an engine-owned value
      Check('{{set x := n|newobj}}{{:x|boom}}', 'ERROR');                 // render fails after a set
    finally
      lCompiler.Free;
    end;
  finally
    if not gCallerObjectDestroyed then
      lObj.Free;
  end;
  WriteLn('TestFilterObjectOwnership'.PadRight(45) + ' : OK');
end;

procedure TestRenderStateResetAfterFailure;
// A compiled template is reused across renders (caches, ViewCache): a render that fails inside
// {{autoescape false}} and inside a {{for}} must not leak that state into the next render.
var
  lCompiler: TTProCompiler;
  lTemplate: ITProCompiledTemplate;
  lItems: TObjectList<TObject>;
  lRaised: Boolean;
  lOutput: string;
begin
  lItems := TObjectList<TObject>.Create(True);
  try
    lItems.Add(TObject.Create);
    lCompiler := TTProCompiler.Create;
    try
      lTemplate := lCompiler.Compile(
        '[{{:v}}]{{autoescape false}}{{for c in items}}{{if fail}}{{:c|boom}}{{endif}}{{endfor}}{{endautoescape}}[{{:c}}]');
    finally
      lCompiler.Free;
    end;
    lTemplate.AddFilter('boom',
      function(const aValue: TValue; const aParameters: TArray<TFilterParameter>): TValue
      begin
        raise Exception.Create('boom');
      end);
    lTemplate.SetData('v', '<b>');
    lTemplate.SetData('items', lItems);

    lTemplate.SetData('fail', True);
    lRaised := False;
    try
      lTemplate.Render;
    except
      on E: ETProRenderException do
        lRaised := True;
    end;
    Assert(lRaised, 'First render should fail');

    lTemplate.SetData('fail', False);
    lOutput := lTemplate.Render;
    Assert(lOutput = '[&lt;b&gt;][]', 'State leaked from the failed render: "' + lOutput + '"');
    lTemplate := nil;
  finally
    lItems.Free;
  end;
  WriteLn('TestRenderStateResetAfterFailure'.PadRight(45) + ' : OK');
end;

procedure TestExpressionNestingLimit;
// Deeply nested expressions must fail with a normal exception instead of overflowing the stack
var
  lCompiler: TTProCompiler;
  lTemplate: ITProCompiledTemplate;
  lRaised: Boolean;

  function Nested(const aDepth: Integer; const aOpen, aInner, aClose: string): string;
  begin
    Result := DupeString(aOpen, aDepth) + aInner + DupeString(aClose, aDepth);
  end;

begin
  lCompiler := TTProCompiler.Create;
  try
    // reasonable nesting keeps working
    lTemplate := lCompiler.Compile('{{@' + Nested(50, '(', '1', ')') + '}}');
    Assert(lTemplate.Render = '1', 'Nesting of 50 must work');

    for var lExpr in [Nested(100000, '(', '1', ')'), Nested(100000, '-', '1', ''),
      Nested(100000, 'IF true THEN ', '1', ' ELSE 0')] do
    begin
      lTemplate := lCompiler.Compile('{{@' + lExpr + '}}');
      lRaised := False;
      try
        lTemplate.Render;
      except
        on E: Exception do
        begin
          lRaised := True;
          Assert(ContainsText(E.Message, 'nesting'), 'Unexpected message: ' + E.Message);
        end;
      end;
      Assert(lRaised, 'Deep nesting not rejected: ' + Copy(lExpr, 1, 20));
    end;
    lTemplate := nil;
  finally
    lCompiler.Free;
  end;
  WriteLn('TestExpressionNestingLimit'.PadRight(45) + ' : OK');
end;

procedure TestRenderNestingLimit;
// Unbounded recursion through macros or dynamic includes must fail with ETProRenderException,
// while legitimate recursion (e.g. rendering a tree) keeps working
var
  lCompiler: TTProCompiler;
  lTemplate: ITProCompiledTemplate;
  lRoot, lNode: TJDOJsonObject;
  I: Integer;
  lExpected: string;

  procedure AssertTooDeep(const aTemplate: ITProCompiledTemplate; const aCase: string);
  var
    lRaised: Boolean;
  begin
    lRaised := False;
    try
      aTemplate.Render;
    except
      on E: ETProRenderException do
      begin
        lRaised := True;
        Assert(ContainsText(E.Message, 'nesting'), aCase + ' - unexpected message: ' + E.Message);
      end;
    end;
    Assert(lRaised, aCase + ' - unbounded recursion not stopped');
  end;

begin
  lCompiler := TTProCompiler.Create;
  lRoot := TJDOJsonObject.Create;
  try
    // legitimate: a 50-level tree rendered by a recursive macro
    lNode := lRoot;
    lExpected := '';
    for I := 1 to 50 do
    begin
      lNode.S['name'] := I.ToString;
      lExpected := lExpected + I.ToString + ';';
      if I < 50 then
        lNode := lNode.O['child'];
    end;
    lTemplate := lCompiler.Compile(
      '{{macro node(n)}}{{:n.name}};{{if n.child}}{{>node(n.child)}}{{endif}}{{endmacro}}{{>node(root)}}');
    lTemplate.SetData('root', lRoot);
    Assert(lTemplate.Render = lExpected, 'A 50-level recursive macro must render');

    // a macro calling itself forever
    lTemplate := lCompiler.Compile('{{macro m()}}x{{>m()}}{{endmacro}}{{>m()}}');
    AssertTooDeep(lTemplate, 'Recursive macro');

    // a dynamic include including itself forever
    lTemplate := lCompiler.Compile('x{{include @(page)}}');
    lTemplate.OnGetDynamicallyIncludedTemplate :=
      procedure(const TemplateName: string; var TemplateContent: string; var Handled: Boolean)
      begin
        TemplateContent := 'x{{include @(page)}}';
        Handled := True;
      end;
    lTemplate.SetData('page', 'self.tpro');
    AssertTooDeep(lTemplate, 'Recursive dynamic include');
    lTemplate := nil;
  finally
    lRoot.Free;
    lCompiler.Free;
  end;
  WriteLn('TestRenderNestingLimit'.PadRight(45) + ' : OK');
end;

procedure TestCustomFilterOverridesBuiltIn;
// 1.2: a custom filter registered with the name of a built-in replaces the built-in
var
  lCompiler: TTProCompiler;
  lTemplate: ITProCompiledTemplate;
begin
  lCompiler := TTProCompiler.Create;
  try
    lTemplate := lCompiler.Compile('{{:v|uppercase}}-{{:v|lowercase}}');
    lTemplate.AddFilter('UpperCase',
      function(const aValue: TValue; const aParameters: TArray<TFilterParameter>): TValue
      begin
        Result := 'custom:' + aValue.AsString;
      end);
    lTemplate.SetData('v', 'Abc');
    Assert(lTemplate.Render = 'custom:Abc-abc', 'Custom filter must override the built-in: ' + lTemplate.Render);
    lTemplate := nil;
  finally
    lCompiler.Free;
  end;
  WriteLn('TestCustomFilterOverridesBuiltIn'.PadRight(45) + ' : OK');
end;

function CompileStr(const aTemplate: string): ITProCompiledTemplate;
var
  lCompiler: TTProCompiler;
begin
  lCompiler := TTProCompiler.Create;
  try
    Result := lCompiler.Compile(aTemplate);
  finally
    lCompiler.Free;
  end;
end;

procedure AssertRenderRaises(const aTemplate: ITProCompiledTemplate; const aMsgPart, aCase: string);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    aTemplate.Render;
  except
    on E: ETProRenderException do
    begin
      lRaised := True;
      Assert(ContainsText(E.Message, aMsgPart), aCase + ' - unexpected message: ' + E.Message);
    end;
    on E: Exception do
      Assert(False, aCase + ' - expected ETProRenderException, got ' + E.ClassName + ': ' + E.Message);
  end;
  Assert(lRaised, aCase + ' - no exception raised');
end;

procedure AssertCompileRaises(const aTemplateSrc, aMsgPart, aCase: string);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    CompileStr(aTemplateSrc);
  except
    on E: ETProCompilerException do
    begin
      lRaised := True;
      Assert(ContainsText(E.Message, aMsgPart), aCase + ' - unexpected message: ' + E.Message);
    end;
    on E: Exception do
      Assert(False, aCase + ' - expected ETProCompilerException, got ' + E.ClassName + ': ' + E.Message);
  end;
  Assert(lRaised, aCase + ' - no compile error raised');
end;

procedure TestExpressionErrorsAreRenderExceptions;
// 1.2: an error inside an expression surfaces as ETProRenderException carrying the original message
var
  lTemplate: ITProCompiledTemplate;
begin
  AssertRenderRaises(CompileStr('{{@1/0}}'), 'Error evaluating expression [1/0]', 'Output expression');
  AssertRenderRaises(CompileStr('{{if @(1/0)}}x{{endif}}'), 'Error evaluating expression [1/0]', 'If expression');
  AssertRenderRaises(CompileStr('{{set x := @(1/0)}}'), 'Error evaluating expression [1/0]', 'Set expression');
  AssertRenderRaises(CompileStr('{{include @(1/0)}}'), 'Error evaluating expression [1/0]', 'Dynamic include name');
  AssertRenderRaises(CompileStr('{{@1/0|uppercase}}'), 'Error evaluating expression [1/0]', 'Expression with filter');
  AssertRenderRaises(CompileStr('{{macro m()}}{{@1/0}}{{endmacro}}{{>m()}}'), 'Error evaluating expression [1/0]', 'Expression in macro');
  // the original message is kept
  lTemplate := CompileStr('{{@1/0}}');
  try
    lTemplate.Render;
  except
    on E: Exception do
      Assert(ContainsText(E.Message, 'zero'), 'Original message lost: ' + E.Message);
  end;
  WriteLn('TestExpressionErrorsAreRenderExceptions'.PadRight(45) + ' : OK');
end;

procedure TestDataSetFieldTypes;
// dataset fields of the less common types render with their value
var
  lTemplate: ITProCompiledTemplate;
  lDS: TDataSet;
  lExpected: string;
begin
  lDS := GetFieldTypesDataset;
  try
    lTemplate := CompileStr('{{for r in ds}}{{:r.SI}}|{{:r.BY}}|{{:r.LW}}|{{:r.EX}}|{{:r.GU}}|{{:r.FC}}|{{:r.FW}}' +
      {$IF CompilerVersion >= 37}'|{{:r.LU}}' +{$ENDIF} '{{endfor}}');
    lTemplate.SetData('ds', lDS);
    lExpected := '-5|200|4000000000|1.5|{11111111-2222-3333-4444-555555555555}|abc|xyz'
      {$IF CompilerVersion >= 37} + '|18000000000000000000'{$ENDIF};
    Assert(lTemplate.Render = lExpected, 'Unexpected: ' + lTemplate.Render);
  finally
    lDS.Free;
  end;
  // unsigned values above the signed maximum, in output and in expressions
  lTemplate := CompileStr('{{:c}}|{{:u}}|{{@c + 1}}|{{if @(c > 3000000000)}}big{{endif}}');
  lTemplate.SetData('c', TValue.From<Cardinal>(4000000000));
  lTemplate.SetData('u', TValue.From<UInt64>(18000000000000000000));
  Assert(lTemplate.Render = '4000000000|18000000000000000000|4000000001|big', 'Unsigned: ' + lTemplate.Render);
  WriteLn('TestDataSetFieldTypes'.PadRight(45) + ' : OK');
end;

procedure TestRoundUsesTemplateFormatSettings;
// 1.2: "round" formats with the template FormatSettings, not with the process-wide ones
var
  lTemplate: ITProCompiledTemplate;
  lSavedSeparator: Char;
begin
  lSavedSeparator := FormatSettings.DecimalSeparator;
  FormatSettings.DecimalSeparator := ',';
  try
    lTemplate := CompileStr('{{:v|round,-2}}');
    lTemplate.SetData('v', 19.5);
    Assert(lTemplate.Render = '19.50', 'round must use the template FormatSettings, got: ' + lTemplate.Render);
  finally
    FormatSettings.DecimalSeparator := lSavedSeparator;
  end;
  WriteLn('TestRoundUsesTemplateFormatSettings'.PadRight(45) + ' : OK');
end;

procedure AssertSurvivesSaveLoad(const aTemplateSrc: string; const aSetup: TProc<ITProCompiledTemplate>; const aCase: string);
// a compiled template saved to disk and loaded back must render the same
const
  TPC_FILE = 'output\roundtrip.tpc';
var
  lTemplate, lLoaded: ITProCompiledTemplate;
  lExpected, lActual: string;
begin
  lTemplate := CompileStr(aTemplateSrc);
  if Assigned(aSetup) then
    aSetup(lTemplate);
  lExpected := lTemplate.Render;
  lTemplate.SaveToFile(TPC_FILE);
  lLoaded := TTProCompiledTemplate.CreateFromFile(TPC_FILE);
  if Assigned(aSetup) then
    aSetup(lLoaded);
  lActual := lLoaded.Render;
  TFile.Delete(TPC_FILE);
  Assert(lActual = lExpected, aCase + ' - loaded template renders "' + lActual + '" instead of "' + lExpected + '"');
end;

procedure TestSwitchCase;
// 1.2: {{switch}} / {{case}} / {{default}} / {{endswitch}}
begin
  AssertCompileRaises('{{case "a"}}', '"case" without "switch"', 'Case outside switch');
  AssertCompileRaises('{{default}}', '"default" without "switch"', 'Default outside switch');
  AssertCompileRaises('{{endswitch}}', '"endswitch" without "switch"', 'Endswitch without switch');
  AssertCompileRaises('{{switch x}}{{case 1}}a', 'expected "endswitch"', 'Missing endswitch');
  AssertCompileRaises('{{switch x}}{{default}}d{{case 1}}a{{endswitch}}', '"case" after "default"', 'Case after default');
  AssertCompileRaises('{{switch x}}{{default}}d{{default}}e{{endswitch}}', 'Duplicated "default"', 'Two defaults');
  AssertCompileRaises('{{switch x}}text{{case 1}}a{{endswitch}}', 'between "switch" and the first "case"', 'Text before first case');
  AssertCompileRaises('{{switch x}}{{:y}}{{case 1}}a{{endswitch}}', 'between "switch" and the first "case"', 'Tag before first case');
  AssertCompileRaises('{{switch x}}{{case 1}}{{if y}}{{case 2}}{{endif}}{{endswitch}}', '"case" without "switch"', 'Case inside if');
  AssertCompileRaises('{{switch}}{{endswitch}}', 'Expected', 'Switch without value');
  AssertCompileRaises('{{switch x}}{{case}}{{endswitch}}', 'Expected', 'Case without value');
  AssertSurvivesSaveLoad('{{switch v|uppercase}}{{case "A", w}}A{{case 1.5}}F{{default}}D{{endswitch}}',
    procedure(aTemplate: ITProCompiledTemplate)
    begin
      aTemplate.SetData('v', 'a');
      aTemplate.SetData('w', 'B');
    end, 'Switch');
  WriteLn('TestSwitchCase'.PadRight(45) + ' : OK');
end;

procedure TestForRange;
// 1.2: {{for i in range(...)}} - Python semantics, arguments are expressions
var
  lTemplate: ITProCompiledTemplate;
  lArr: TJDOJsonArray;
begin
  AssertRenderRaises(CompileStr('{{for i in range(1, 5, 0)}}{{:i}}{{endfor}}'), 'range step cannot be zero', 'Step zero');
  AssertRenderRaises(CompileStr('{{for i in range(1.5)}}{{:i}}{{endfor}}'), 'integer', 'Float argument');
  AssertRenderRaises(CompileStr('{{for i in range("a")}}{{:i}}{{endfor}}'), 'integer', 'String argument');
  AssertCompileRaises('{{for i in range()}}{{endfor}}', 'range expects', 'No arguments');
  AssertCompileRaises('{{for i in range(1,2,3,4)}}{{endfor}}', 'range expects', 'Too many arguments');
  AssertCompileRaises('{{for i in range(1,2}}{{endfor}}', 'range', 'Unclosed range');
  // a variable whose name starts with "range" is still a variable
  lArr := TJDOJsonArray.Parse('[1,2]') as TJDOJsonArray;
  try
    lTemplate := CompileStr('{{for r in ranges}}{{:r}}{{endfor}}');
    lTemplate.SetData('ranges', lArr);
    Assert(lTemplate.Render = '12', 'Variable named ranges: ' + lTemplate.Render);
    lTemplate := nil;
  finally
    lArr.Free;
  end;
  AssertSurvivesSaveLoad('{{for i in range(n, n + 3)}}{{:i}}{{endfor}}',
    procedure(aTemplate: ITProCompiledTemplate)
    begin
      aTemplate.SetData('n', 2);
    end, 'Range');
  WriteLn('TestForRange'.PadRight(45) + ' : OK');
end;

procedure TestNewFilters;
// 1.2 built-in filters: parameters from variables, line endings, ownership, wrong parameter count
var
  lTemplate: ITProCompiledTemplate;
  lNames: TList<string>;
  lItems: TObjectList<TDataItem>;
begin
  lNames := TList<string>.Create;
  lItems := GetItems;
  try
    lNames.AddRange(['ann', 'bob', 'carl']);
    lTemplate := CompileStr('{{:v|replace,from,to}}|{{:names|join,sep}}|{{:items|join,sep,prop}}|{{:v|wordwrap,w}}|' +
      '{{:n|pluralize,one,many}}|{{:names|length}}|{{:names|first}}{{:names|last}}');
    lTemplate.SetData('v', 'aa bb');
    lTemplate.SetData('from', 'a');
    lTemplate.SetData('to', 'x');
    lTemplate.SetData('names', lNames);
    lTemplate.SetData('items', lItems);
    lTemplate.SetData('sep', '-');
    lTemplate.SetData('prop', 'PropInt');
    lTemplate.SetData('w', 2);
    lTemplate.SetData('n', 1);
    lTemplate.SetData('one', 'child');
    lTemplate.SetData('many', 'children');
    lTemplate.OutputLineEnding := lesCRLF;
    Assert(lTemplate.Render = 'xx bb|ann-bob-carl|1-2-3|aa'#13#10'bb|child|3|anncarl', 'Variable parameters: ' + lTemplate.Render);

    lTemplate := CompileStr('{{:v|nl2br}}');
    lTemplate.SetData('v', 'a'#13#10'b'#13'c'#10'd');
    Assert(lTemplate.Render = 'a<br>b<br>c<br>d', 'nl2br line endings: ' + lTemplate.Render);

    // first/last never free: the element of a filter-created list stays valid until Render ends
    lTemplate := CompileStr('{{set f := x|mklist|first}}{{:f.Prop1}}');
    lTemplate.AddFilter('mklist',
      function(const aValue: TValue; const aParameters: TArray<TFilterParameter>): TValue
      begin
        Result := GetItems;
      end);
    Assert(lTemplate.Render = 'value1.1', 'first of a filter-created list: ' + lTemplate.Render);
    lTemplate := nil;
  finally
    lItems.Free;
    lNames.Free;
  end;
  AssertRenderRaises(CompileStr('{{:v|replace,"a"}}'), 'Expected 2 parameters', 'replace with 1 parameter');
  AssertRenderRaises(CompileStr('{{:v|trim,1}}'), 'Expected 0 parameters', 'trim with 1 parameter');
  AssertRenderRaises(CompileStr('{{:v|join}}'), 'parameters', 'join without separator');
  AssertRenderRaises(CompileStr('{{:v|pluralize,"a"}}'), 'Expected 2 parameters', 'pluralize with 1 parameter');
  AssertRenderRaises(CompileStr('{{:v|wordwrap}}'), 'Expected 1 parameters', 'wordwrap without width');
  // expression and float parameters survive the compiled-template file
  AssertSurvivesSaveLoad('{{:v|replace,@(1 + 1),"x"}}|{{:n|default,1.5}}|{{:v|nl2br}}',
    procedure(aTemplate: ITProCompiledTemplate)
    begin
      aTemplate.SetData('v', 'a2'#10'b');
    end, 'Filter parameters');
  WriteLn('TestNewFilters'.PadRight(45) + ' : OK');
end;

procedure TestMacroNamedAndOptionalArgs;
// 1.2: macro parameters with defaults, named arguments at call time
const
  MACRO_B = '{{macro b(a, size="md")}}{{:a}}{{:size}}{{endmacro}}';
begin
  AssertCompileRaises('{{macro b(a="x", c)}}{{endmacro}}',
    'Macro "b": parameter "c" without default after a parameter with default', 'Required after optional');
  AssertCompileRaises(MACRO_B + '{{>b(size="x", "y")}}', 'Positional argument after named argument', 'Positional after named');
  AssertRenderRaises(CompileStr(MACRO_B + '{{>b("x", colour="red")}}'), 'Unknown parameter "colour" for macro "b"', 'Unknown named');
  AssertRenderRaises(CompileStr(MACRO_B + '{{>b("x", size="lg", size="xl")}}'), 'Parameter "size" passed twice to macro "b"', 'Named twice');
  AssertRenderRaises(CompileStr(MACRO_B + '{{>b("x", a="y")}}'), 'Parameter "a" passed twice to macro "b"', 'Positional and named');
  AssertRenderRaises(CompileStr(MACRO_B + '{{>b(size="lg")}}'), 'Missing required parameter "a"', 'Missing required');
  AssertSurvivesSaveLoad('{{macro m(a, b="B", c=v, d=2.5, e=true)}}{{:a}}{{:b}}{{:c}}{{:d}}{{if e}}E{{endif}}{{endmacro}}' +
    '{{>m("x")}}/{{>m("y", c="C", e=false)}}',
    procedure(aTemplate: ITProCompiledTemplate)
    begin
      aTemplate.SetData('v', 'V');
    end, 'Macro defaults and named arguments');
  WriteLn('TestMacroNamedAndOptionalArgs'.PadRight(45) + ' : OK');
end;

procedure TestPushStack;
// 1.2: {{push "name"}}...{{endpush}} collects content, {{stack "name"}} emits it (even if it comes first)
var
  lTemplate: ITProCompiledTemplate;

  function Render(const aTemplateSrc: string; const aVarName: string = ''; const aVarValue: string = ''): string;
  begin
    lTemplate := CompileStr(aTemplateSrc);
    if aVarName <> '' then
      lTemplate.SetData(aVarName, aVarValue);
    Result := lTemplate.Render;
  end;

  procedure CheckRender(const aTemplateSrc, aExpected, aCase: string; const aVarName: string = ''; const aVarValue: string = '');
  var
    lActual: string;
  begin
    lActual := Render(aTemplateSrc, aVarName, aVarValue);
    Assert(lActual = aExpected, aCase + ' - expected "' + aExpected + '", got "' + lActual + '"');
  end;

  procedure SetDynamicInclude(const aContent: string);
  begin
    lTemplate.SetData('page', 'dyn.tpro');
    lTemplate.OnGetDynamicallyIncludedTemplate :=
      procedure(const TemplateName: string; var TemplateContent: string; var Handled: Boolean)
      begin
        TemplateContent := aContent;
        Handled := True;
      end;
  end;

begin
  CheckRender('{{stack "s"}}|{{push "s"}}A{{endpush}}{{push "s"}}B{{endpush}}', 'AB|', 'Stack before pushes');
  CheckRender('{{push "s" once}}X{{endpush}}{{push "s" once}}X{{endpush}}{{push "s" once}}Y{{endpush}}{{stack "s"}}', 'XY', 'Once');
  CheckRender('[{{stack "s"}}]', '[]', 'Empty stack');
  CheckRender('{{push "nowhere"}}X{{endpush}}ok', 'ok', 'Push without stack');
  CheckRender('{{stack n}}{{push "abc"}}Z{{endpush}}', 'Z', 'Stack name from a variable', 'n', 'abc');
  CheckRender('{{stack "s"}}{{push "s"}}{{:v}}{{endpush}}', '&lt;b&gt;', 'Autoescape in push', 'v', '<b>');
  CheckRender('{{:v}}{{stack "s"}}{{push "s"}}X{{endpush}}', '{{stack &quot;s&quot;}}X', 'Data looking like a stack', 'v', '{{stack "s"}}');
  CheckRender('{{macro m()}}<{{stack "s"}}>{{endmacro}}{{>m()}}{{push "s"}}Q{{endpush}}', '<Q>', 'Stack in a macro');

  // every render starts with empty stacks
  lTemplate := CompileStr('{{stack "s"}}{{push "s"}}A{{endpush}}');
  Assert((lTemplate.Render = 'A') and (lTemplate.Render = 'A'), 'Stacks not reset between renders');

  // a dynamically included template pushes to the parent's stacks, and can host a stack
  lTemplate := CompileStr('{{stack "s"}}-{{include @(page)}}');
  SetDynamicInclude('inc{{push "s"}}P{{endpush}}');
  Assert(lTemplate.Render = 'P-inc', 'Push from a dynamic include: ' + lTemplate.Render);
  lTemplate := CompileStr('{{push "s"}}P{{endpush}}[{{include @(page)}}]');
  SetDynamicInclude('H{{stack "s"}}');
  Assert(lTemplate.Render = '[HP]', 'Stack in a dynamic include: ' + lTemplate.Render);
  lTemplate := nil;

  AssertCompileRaises('{{endpush}}', '"endpush" without "push"', 'Endpush without push');
  AssertCompileRaises('{{push "s"}}x', 'expected "endpush"', 'Missing endpush');
  AssertCompileRaises('{{push}}{{endpush}}', 'Expected', 'Push without name');
  AssertCompileRaises('{{stack}}', 'Expected', 'Stack without name');
  AssertRenderRaises(CompileStr('{{push "a"}}{{stack "s"}}{{endpush}}'), 'inside "push"', 'Stack inside push');
  AssertSurvivesSaveLoad('<{{stack "s"}}>{{push "s" once}}A{{endpush}}{{push n}}B{{endpush}}',
    procedure(aTemplate: ITProCompiledTemplate)
    begin
      aTemplate.SetData('n', 's');
    end, 'Push and stack');
  WriteLn('TestPushStack'.PadRight(45) + ' : OK');
end;

procedure TestRangeKeepsStringLiterals;
// "@(" inside a string literal of a range argument is text, not the @(expr) marker
var
  lCompiler: TTProCompiler;
  lTemplate: ITProCompiledTemplate;
begin
  lCompiler := TTProCompiler.Create;
  try
    lTemplate := lCompiler.Compile('{{for i in range(0, Length("@(x"))}}{{:i}}{{endfor}}|{{for i in range(@(1 + 1))}}{{:i}}{{endfor}}');
    Assert(lTemplate.Render = '012|01', 'Unexpected output: ' + lTemplate.Render);
    lTemplate := nil;
  finally
    lCompiler.Free;
  end;
  WriteLn('TestRangeKeepsStringLiterals'.PadRight(45) + ' : OK');
end;

procedure TestExpressionShortCircuitAndModByZero;
// IF..THEN..ELSE evaluates only the selected branch; MOD/DIV by zero raise like "/"
var
  lCompiler: TTProCompiler;
  lTemplate: ITProCompiledTemplate;
  lRaised: Boolean;
begin
  lCompiler := TTProCompiler.Create;
  try
    lTemplate := lCompiler.Compile('[{{@IF n > 0 THEN total / n ELSE 0}}]');
    lTemplate.SetData('n', 0);
    lTemplate.SetData('total', 10);
    Assert(lTemplate.Render = '[0]', 'IF must not evaluate the untaken branch: ' + lTemplate.Render);

    for var lExpr in ['10 MOD 0', '10 DIV 0'] do
    begin
      lTemplate := lCompiler.Compile('{{@' + lExpr + '}}');
      lRaised := False;
      try
        lTemplate.Render;
      except
        on E: ETProRenderException do
        begin
          lRaised := True;
          Assert(ContainsText(E.Message, 'Division by zero'), lExpr + ' - unexpected message: ' + E.Message);
        end;
      end;
      Assert(lRaised, lExpr + ' did not raise ETProRenderException');
    end;
    lTemplate := nil;
  finally
    lCompiler.Free;
  end;
  WriteLn('TestExpressionShortCircuitAndModByZero'.PadRight(45) + ' : OK');
end;

procedure TestHTMLEncodeLinearTime;
// HTML-encoding must be linear: 40,000 escapable chars took ~2s (and 80,000 ~60s) with the old implementation
const
  CHAR_COUNT = 40000;
var
  lStopWatch: TStopwatch;
  lEncoded: string;
begin
  lStopWatch := TStopwatch.StartNew;
  lEncoded := HTMLEncode(StringOfChar('<', CHAR_COUNT));
  lStopWatch.Stop;
  Assert(lEncoded = DupeString('&lt;', CHAR_COUNT), 'HTMLEncode produced a wrong result');
  Assert(lStopWatch.ElapsedMilliseconds < 500,
    Format('HTMLEncode of %d chars took %d ms', [CHAR_COUNT, lStopWatch.ElapsedMilliseconds]));
  WriteLn('TestHTMLEncodeLinearTime'.PadRight(45) + ' : OK');
end;

procedure TestIncludeCycleDetected;
// A template that (directly or indirectly) includes itself must raise a compiler error, not overflow the stack
var
  lCompiler: TTProCompiler;
  lRaised: Boolean;
begin
  lCompiler := TTProCompiler.Create;
  try
    lCompiler.OnGetIncludedTemplate :=
      procedure(const TemplateName: string; var TemplateContent: string; var Handled: Boolean)
      begin
        if SameText(TemplateName, 'a.tpro') then
          TemplateContent := 'A{{include "b.tpro"}}'
        else
          TemplateContent := 'B{{include "a.tpro"}}';
        Handled := True;
      end;
    lRaised := False;
    try
      lCompiler.Compile('{{include "a.tpro"}}');
    except
      on E: ETProCompilerException do
      begin
        lRaised := True;
        Assert(ContainsText(E.Message, 'Circular include'), 'Unexpected message: ' + E.Message);
      end;
    end;
    Assert(lRaised, 'Circular include not detected');
  finally
    lCompiler.Free;
  end;
  WriteLn('TestIncludeCycleDetected'.PadRight(45) + ' : OK');
end;

procedure TestDynamicIncludeRootPath;
// IncludeRootPath (opt-in) confines file-system dynamic includes to a folder.
// When empty (default) the v1.1 behaviour is unchanged.
var
  lRoot, lTemplatesDir: string;
  lCompiler: TTProCompiler;
  lTemplate: ITProCompiledTemplate;
  lRaised: Boolean;

  function NewTemplate: ITProCompiledTemplate;
  begin
    Result := lCompiler.Compile('[{{include @(page)}}]', TPath.Combine(lTemplatesDir, 'main.tpro'));
  end;

begin
  lRoot := TPath.GetFullPath(TPath.Combine('output', 'includeroot'));
  lTemplatesDir := TPath.Combine(lRoot, 'templates');
  TDirectory.CreateDirectory(lTemplatesDir);
  TFile.WriteAllText(TPath.Combine(lRoot, 'secret.txt'), 'SECRET');
  TFile.WriteAllText(TPath.Combine(lTemplatesDir, 'allowed.tpro'), 'ALLOWED');
  lCompiler := TTProCompiler.Create;
  try
    // default: no restriction (v1.1 compatible)
    lTemplate := NewTemplate;
    lTemplate.SetData('page', '..\secret.txt');
    Assert(lTemplate.Render = '[SECRET]', 'Default behaviour must stay unrestricted');

    // restricted: a file inside the root is allowed
    lTemplate := NewTemplate;
    lTemplate.IncludeRootPath := lTemplatesDir;
    lTemplate.SetData('page', 'allowed.tpro');
    Assert(lTemplate.Render = '[ALLOWED]', 'Include inside root must work');

    // restricted: traversal and absolute paths outside the root are rejected
    for var lPage in ['..\secret.txt', TPath.Combine(lRoot, 'secret.txt'), '..\templates2\x.tpro'] do
    begin
      lTemplate := NewTemplate;
      lTemplate.IncludeRootPath := lTemplatesDir;
      lTemplate.SetData('page', lPage);
      lRaised := False;
      try
        lTemplate.Render;
      except
        on E: ETProRenderException do
        begin
          lRaised := True;
          Assert(ContainsText(E.Message, 'outside'), 'Unexpected message: ' + E.Message);
        end;
      end;
      Assert(lRaised, 'Dynamic include outside IncludeRootPath was not rejected: ' + lPage);
    end;
    lTemplate := nil;
  finally
    lCompiler.Free;
    TDirectory.Delete(lRoot, True);
  end;
  WriteLn('TestDynamicIncludeRootPath'.PadRight(45) + ' : OK');
end;

procedure TestLoadCorruptedCompiledTemplate;
// A corrupted/tampered .tpc must be rejected at load time with a TemplatePro exception
const
  CORRUPTED_FILE = 'output\corrupted.tpc';
var
  lCompiler: TTProCompiler;
  lOriginal: TBytes;

  procedure AssertRejected(const aBytes: TBytes; const aCase: string);
  var
    lRaised: Boolean;
  begin
    TFile.WriteAllBytes(CORRUPTED_FILE, aBytes);
    lRaised := False;
    try
      TTProCompiledTemplate.CreateFromFile(CORRUPTED_FILE);
    except
      on E: ETProException do
      begin
        lRaised := True;
        Assert(ContainsText(E.Message, 'invalid'), aCase + ' - unexpected message: ' + E.Message);
      end;
    end;
    Assert(lRaised, aCase + ' - corrupted compiled template was loaded');
  end;

var
  lBytes: TBytes;
begin
  lCompiler := TTProCompiler.Create;
  try
    lCompiler.Compile('Hello {{:name}}').SaveToFile(CORRUPTED_FILE);
  finally
    lCompiler.Free;
  end;
  lOriginal := TFile.ReadAllBytes(CORRUPTED_FILE);

  // token type out of the TTokenType range
  lBytes := Copy(lOriginal);
  lBytes[0] := 255;
  AssertRejected(lBytes, 'Token type');

  // Value1 length far beyond the file size
  lBytes := Copy(lOriginal);
  PUInt32(@lBytes[1])^ := $7FFFFFF0;
  AssertRejected(lBytes, 'Value length');
  TFile.Delete(CORRUPTED_FILE);

  WriteLn('TestLoadCorruptedCompiledTemplate'.PadRight(45) + ' : OK');
end;

function MapResolver(const aPairs: TArray<string>): TTProTemplateResolver;
// name1, content1, name2, content2, ...
var
  lPairs: TArray<string>;
begin
  lPairs := aPairs;
  Result := procedure(const TemplateName: string; var TemplateContent: string; var Handled: Boolean)
    var
      I: Integer;
    begin
      I := 0;
      while I < High(lPairs) do
      begin
        if SameText(lPairs[I], TemplateName) then
        begin
          TemplateContent := lPairs[I + 1];
          Handled := True;
          Exit;
        end;
        Inc(I, 2);
      end;
    end;
end;

function CompileWith(const aResolver: TTProTemplateResolver; const aTemplate: string): ITProCompiledTemplate;
var
  lCompiler: TTProCompiler;
begin
  lCompiler := TTProCompiler.Create;
  try
    lCompiler.OnGetIncludedTemplate := aResolver;
    Result := lCompiler.Compile(aTemplate);
  finally
    lCompiler.Free;
  end;
end;

procedure AssertCompileWithRaises(const aResolver: TTProTemplateResolver; const aTemplateSrc, aMsgPart, aCase: string);
var
  lRaised: Boolean;
begin
  lRaised := False;
  try
    CompileWith(aResolver, aTemplateSrc);
  except
    on E: ETProCompilerException do
    begin
      lRaised := True;
      Assert(ContainsText(E.Message, aMsgPart), aCase + ' - unexpected message: ' + E.Message);
    end;
    on E: Exception do
      Assert(False, aCase + ' - expected ETProCompilerException, got ' + E.ClassName + ': ' + E.Message);
  end;
  Assert(lRaised, aCase + ' - no compile error raised');
end;

procedure AssertRendersAs(const aTemplate: ITProCompiledTemplate; const aExpected, aCase: string);
var
  lActual: string;
begin
  lActual := aTemplate.Render;
  Assert(lActual = aExpected, aCase + ' - expected "' + aExpected + '", got "' + lActual + '"');
end;

procedure AssertSurvivesSaveLoadWith(const aResolver: TTProTemplateResolver; const aTemplateSrc: string; const aCase: string);
const
  TPC_FILE = 'output\roundtrip_with.tpc';
var
  lTemplate, lLoaded: ITProCompiledTemplate;
  lExpected, lActual: string;
begin
  lTemplate := CompileWith(aResolver, aTemplateSrc);
  lExpected := lTemplate.Render;
  lTemplate.SaveToFile(TPC_FILE);
  lLoaded := TTProCompiledTemplate.CreateFromFile(TPC_FILE);
  lActual := lLoaded.Render;
  TFile.Delete(TPC_FILE);
  Assert(lActual = lExpected, aCase + ' - loaded template renders "' + lActual + '" instead of "' + lExpected + '"');
end;

procedure TestImportLibrary;
// 1.2: {{import "file" as ns}} embeds the macros of a library as ns.<name>
const
  UI_LIB = '{{macro button(text)}}<b>{{:text}}</b>{{endmacro}}'#13#10 +
    '{{# a comment #}}'#13#10 +
    '{{import "icons.tpro" as ic}}'#13#10 +
    '  '#13#10 +
    '{{macro card(title)}}[{{:title}}{{>button("x")}}{{>ic.star()}}]{{endmacro}}'#13#10 +
    '{{macro panel()}}<{{slot}}>{{endmacro}}{{macro framed()}}{{call panel()}}{{slot}}{{endcall}}{{endmacro}}';
var
  lRes: TTProTemplateResolver;
begin
  lRes := MapResolver(['lib/ui.tpro', UI_LIB,
    'icons.tpro', '{{macro star()}}*{{endmacro}}',
    'lib/bad.tpro', '{{macro m()}}{{endmacro}}text',
    'lib/badset.tpro', '{{set x := 1}}{{macro m()}}{{endmacro}}',
    'lib/self.tpro', '{{import "self.tpro" as s}}']);
  AssertRendersAs(CompileWith(lRes, '{{import "lib/ui.tpro" as ui}}'#13#10'{{>ui.button("OK")}}|{{>ui.card("T")}}'),
    '<b>OK</b>|[T<b>x</b>*]', 'Qualified calls, internal and nested calls');
  AssertRendersAs(CompileWith(lRes, '{{import "lib/ui.tpro" as a}}{{import "lib/ui.tpro" as b}}{{>a.button("1")}}{{>b.button("2")}}'),
    '<b>1</b><b>2</b>', 'Same file, two aliases');
  AssertRendersAs(CompileWith(lRes, '{{import "lib/ui.tpro" as ui}}{{macro button(t)}}P{{endmacro}}{{>button("z")}}{{>ui.card("T")}}'),
    'P[T<b>x</b>*]', 'Page macro with the name of a library macro');
  AssertRendersAs(CompileWith(lRes, '{{>ui.button("late")}}{{import "lib/ui.tpro" as ui}}'),
    '<b>late</b>', 'Library macros are available before the import tag');
  AssertRendersAs(CompileWith(lRes, '{{import "lib/ui.tpro" as ui}}{{call ui.panel()}}P{{endcall}}{{call ui.framed()}}F{{endcall}}'),
    '<P><F>', 'Library macros with slots');
  AssertRenderRaises(CompileWith(lRes, '{{import "lib/ui.tpro" as ui}}{{>ic.star()}}'), 'Macro "ic.star" not defined', 'Nested import not visible');
  AssertRenderRaises(CompileWith(lRes, '{{import "lib/ui.tpro" as ui}}{{>ui.nope()}}'), 'Macro "ui.nope" not defined', 'Unknown library macro');
  AssertCompileWithRaises(lRes, '{{import "lib/ui.tpro" as ui}}{{import "icons.tpro" as ui}}', 'Namespace "ui" already imported', 'Duplicated alias');
  AssertCompileWithRaises(lRes, '{{import "lib/bad.tpro" as b}}', 'Library "lib/bad.tpro" can contain only macros and imports', 'Text in library');
  AssertCompileWithRaises(lRes, '{{import "lib/badset.tpro" as b}}', 'Library "lib/badset.tpro" can contain only macros and imports', 'Set in library');
  AssertCompileWithRaises(lRes, '{{import "lib/self.tpro" as s}}', 'Circular', 'Circular import');
  AssertCompileWithRaises(lRes, '{{import "lib/missing.tpro" as m}}', 'Cannot read "lib/missing.tpro"', 'Missing library');
  AssertCompileWithRaises(lRes, '{{if v}}{{import "lib/ui.tpro" as ui}}{{endif}}', '"import" is allowed only at the top level', 'Import inside if');
  AssertCompileWithRaises(lRes, '{{macro m()}}{{import "lib/ui.tpro" as ui}}{{endmacro}}', '"import" is allowed only at the top level', 'Import inside macro');
  AssertCompileWithRaises(lRes, '{{import "lib/ui.tpro"}}', 'Expected "as"', 'Import without alias');
  AssertCompileWithRaises(lRes, '{{import ui}}', 'Expected string', 'Import without a string');
  AssertCompileRaises('{{macro a.b()}}{{endmacro}}', 'Macro name "a.b" cannot contain "."', 'Dotted page macro');
  AssertSurvivesSaveLoadWith(lRes, '{{import "lib/ui.tpro" as ui}}{{>ui.card("T")}}', 'Import');
  WriteLn('TestImportLibrary'.PadRight(45) + ' : OK');
end;

procedure TestSlots;
// 1.2: {{call m(args)}}...{{endcall}} passes content to the macro, rendered by {{slot}}/{{slot "name"}}
const
  CARD = '{{macro card(title)}}<{{:title}}|{{slot}}|{{if slots.footer}}F:{{slot "footer"}}{{endif}}|{{slot "note"}}no note{{endslot}}>{{endmacro}}';
  WRAP = '{{macro wrap()}}[{{slot}}]{{endmacro}}';
var
  lTemplate: ITProCompiledTemplate;

  function T(const aSrc: string): ITProCompiledTemplate;
  begin
    lTemplate := CompileStr(aSrc);
    lTemplate.SetData('v', 'V');
    lTemplate.SetData('t', 'T');
    lTemplate.SetData('k', 'a');
    Result := lTemplate;
  end;

begin
  AssertRendersAs(T(CARD + '{{call card(title=t)}}body {{:v}}{{fill "footer"}}foot {{:v|lowercase}}{{endfill}}{{endcall}}'),
    '<T|body V|F:foot v|no note>', 'Default and named slot');
  AssertRendersAs(T(CARD + '{{>card("T")}}'), '<T|||no note>', 'Macro called without a body');
  AssertRendersAs(T(CARD + '{{call card("T")}}{{fill "note"}}N{{endfill}}{{endcall}}'), '<T|||N>', 'Fallback replaced');
  AssertRendersAs(T(CARD + '{{call card("T")}}   {{fill "note"}} {{endfill}}{{endcall}}'), '<T|||no note>', 'Blank slots are not filled');
  AssertRendersAs(T('{{macro twice()}}{{slot}}{{slot}}{{endmacro}}{{call twice()}}x{{:v}}{{endcall}}'), 'xVxV', 'Slot rendered twice');
  AssertRendersAs(T('{{macro m()}}{{if slots.default}}Y{{else}}N{{endif}}{{endmacro}}{{call m()}}x{{endcall}}{{call m()}} {{endcall}}{{>m()}}'),
    'YNN', 'slots.default');
  AssertRendersAs(T(WRAP + '{{for i in range(3)}}{{call wrap()}}{{:i}}{{:i.@@index}}{{endcall}}{{endfor}}'),
    '[01][12][23]', 'Loop variables of the caller');
  AssertRendersAs(T('{{macro m()}}({{:v}}){{slot}}{{endmacro}}{{call m()}}{{:v}}{{endcall}}'), '()V', 'The macro does not see the caller');
  AssertRendersAs(T('{{macro m(p)}}{{slot}}{{endmacro}}{{call m("P")}}[{{:p}}]{{endcall}}'), '[]', 'The slot does not see the macro');
  AssertRendersAs(T(WRAP + '{{call wrap()}}{{call wrap()}}{{:v}}{{endcall}}{{endcall}}'), '[[V]]', 'Call inside a slot');
  AssertRendersAs(T(WRAP + '{{macro outer()}}O({{call wrap()}}{{slot}}{{endcall}}){{endmacro}}{{call outer()}}{{:v}}{{endcall}}'),
    'O([V])', 'Slot passed through a nested call');
  AssertRendersAs(T(WRAP + '{{call wrap()}}{{>wrap()}}{{endcall}}'), '[[]]', 'Macro call inside a slot');
  AssertRendersAs(T(WRAP + '{{stack "s"}}{{call wrap()}}{{push "s"}}P{{endpush}}X{{endcall}}'), 'P[X]', 'Push inside a slot');
  AssertRendersAs(T(WRAP + '{{call wrap()}}{{set z := "Z"}}{{endcall}}{{:z}}'), '[]Z', 'Set inside a slot writes the caller scope');
  AssertRendersAs(T('{{macro m(n)}}{{slot n}}|{{slot @(n + "b")}}{{endmacro}}{{call m("a")}}{{fill k}}A{{endfill}}{{fill "ab"}}B{{endfill}}{{endcall}}'),
    'A|B', 'Slot and fill names from variables and expressions');
  AssertRendersAs(T(WRAP + '{{call wrap()}}{{switch v}}{{case "V"}}sw{{endswitch}}{{if v}}if{{endif}}{{endcall}}'), '[swif]', 'Control flow in a slot');
  AssertRenderRaises(T('{{macro r()}}{{call r()}}{{slot}}{{endcall}}{{endmacro}}{{call r()}}x{{endcall}}'), 'nesting too deep', 'Recursion limit');
  AssertCompileRaises('{{fill "a"}}{{endfill}}', '"fill" must be directly inside "call"', 'Fill outside call');
  AssertCompileRaises(WRAP + '{{call wrap()}}{{if v}}{{fill "a"}}{{endfill}}{{endif}}{{endcall}}', '"fill" must be directly inside "call"', 'Fill inside if');
  AssertCompileRaises(WRAP + '{{call wrap()}}{{fill "a"}}{{endfill}}{{fill "A"}}{{endfill}}{{endcall}}', 'Duplicated fill "A"', 'Duplicated fill');
  AssertCompileRaises(WRAP + '{{call wrap()}}{{fill "default"}}{{endfill}}{{endcall}}', 'reserved', 'Fill named default');
  AssertCompileRaises('{{slot}}', '"slot" can be used only inside a macro', 'Slot outside macro');
  AssertCompileRaises('{{macro m(a, slots)}}{{endmacro}}', 'cannot be named "slots"', 'Parameter named slots');
  AssertCompileRaises('{{macro m(slots=1)}}{{endmacro}}', 'cannot be named "slots"', 'Optional parameter named slots');
  AssertCompileRaises(WRAP + '{{call wrap()}}x', 'Unbalanced "call"', 'Missing endcall');
  AssertCompileRaises('{{endcall}}', '"endcall" without "call"', 'Endcall without call');
  AssertCompileRaises(WRAP + '{{call wrap()}}{{fill "a"}}x{{endcall}}', 'expected "endfill"', 'Missing endfill');
  AssertCompileRaises('{{endfill}}', '"endfill" without "fill"', 'Endfill without fill');
  AssertCompileRaises('{{macro m()}}{{endslot}}{{endmacro}}', '"endslot" without "slot"', 'Endslot without slot');
  AssertCompileRaises('{{call}}{{endcall}}', 'Expected macro name', 'Call without name');
  AssertSurvivesSaveLoad(CARD + '{{call card(title=t)}}b{{:v}}{{fill "footer"}}f{{endfill}}{{endcall}}{{>card("x")}}',
    procedure(aTemplate: ITProCompiledTemplate)
    begin
      aTemplate.SetData('v', 'V');
      aTemplate.SetData('t', 'T');
    end, 'Slots');
  // the "slots" object belongs to the macro: nothing is left behind after the call
  lTemplate := T(WRAP + '{{call wrap()}}x{{endcall}}{{:slots}}');
  AssertRendersAs(lTemplate, '[x]', 'No slots variable in the caller');
  lTemplate := nil;
  WriteLn('TestSlots'.PadRight(45) + ' : OK');
end;

procedure TestGlobalTemplateResolver;
// 1.2: TTProConfiguration.OnGetTemplate serves static includes, extends, imports and dynamic includes.
// Precedence: the instance resolver (if it handles the name), then the global one, then the file system.
var
  lCompiler: TTProCompiler;
  lTemplate: ITProCompiledTemplate;
begin
  TFile.WriteAllText(TPath.Combine('output', 'fs_inc.tpro'), 'FS');
  TTProConfiguration.OnGetTemplate := MapResolver(['g_inc.tpro', 'G-INC',
    'g_layout.tpro', 'L[{{block "c"}}{{endblock}}]',
    'g_lib.tpro', '{{macro m()}}GM{{endmacro}}',
    'g_dyn.tpro', 'G-DYN{{include "g_inc.tpro"}}',
    'both.tpro', 'GLOBAL']);
  try
    AssertRendersAs(CompileStr('{{include "g_inc.tpro"}}'), 'G-INC', 'Static include');
    AssertRendersAs(CompileStr('{{extends "g_layout.tpro"}}{{block "c"}}X{{endblock}}'), 'L[X]', 'Extends');
    AssertRendersAs(CompileStr('{{import "g_lib.tpro" as g}}{{>g.m()}}'), 'GM', 'Import');
    lTemplate := CompileStr('{{include @(n)}}');
    lTemplate.SetData('n', 'g_dyn.tpro');
    AssertRendersAs(lTemplate, 'G-DYNG-INC', 'Dynamic include');
    // the instance resolver comes first...
    AssertRendersAs(CompileWith(MapResolver(['both.tpro', 'INSTANCE']), '{{include "both.tpro"}}'), 'INSTANCE', 'Instance first');
    lTemplate := CompileStr('{{include @(n)}}');
    lTemplate.SetData('n', 'both.tpro');
    lTemplate.OnGetDynamicallyIncludedTemplate := MapResolver(['both.tpro', 'DYN-INSTANCE']);
    AssertRendersAs(lTemplate, 'DYN-INSTANCE', 'Dynamic instance first');
    // ...but when it does not handle the name, the global one does
    AssertRendersAs(CompileWith(MapResolver(['other.tpro', 'X']), '{{include "both.tpro"}}'), 'GLOBAL', 'Global after instance');
    lTemplate := CompileStr('{{include @(n)}}'); // a new one: dynamic includes are cached
    lTemplate.SetData('n', 'both.tpro');
    lTemplate.OnGetDynamicallyIncludedTemplate := MapResolver(['other.tpro', 'X']);
    AssertRendersAs(lTemplate, 'GLOBAL', 'Dynamic global after instance');
    // names nobody handles come from the file system
    lCompiler := TTProCompiler.Create;
    try
      AssertRendersAs(lCompiler.Compile('{{include "fs_inc.tpro"}}', TPath.Combine('output', 'main.tpro')), 'FS', 'File system last');
    finally
      lCompiler.Free;
    end;
    lTemplate := nil;
  finally
    TTProConfiguration.OnGetTemplate := nil;
    TFile.Delete(TPath.Combine('output', 'fs_inc.tpro'));
  end;
  WriteLn('TestGlobalTemplateResolver'.PadRight(45) + ' : OK');
end;

procedure TestIsStale;
// 1.2: a compiled template records its dependencies (static includes, extends, imports) and knows when they changed
var
  lDir, lMain, lInc, lLib, lTpc: string;
  lCompiler: TTProCompiler;
  lTemplate, lLoaded: ITProCompiledTemplate;

  function CompileMain: ITProCompiledTemplate;
  begin
    Result := lCompiler.Compile(TFile.ReadAllText(lMain), lMain);
  end;

  function SaveAndLoad(const aTemplate: ITProCompiledTemplate): ITProCompiledTemplate;
  begin
    aTemplate.SaveToFile(lTpc);
    Result := TTProCompiledTemplate.CreateFromFile(lTpc);
  end;

begin
  lDir := TPath.GetFullPath(TPath.Combine('output', 'stale'));
  TDirectory.CreateDirectory(TPath.Combine(lDir, 'sub'));
  lMain := TPath.Combine(lDir, 'main.tpro');
  lInc := TPath.Combine(lDir, 'inc.tpro');
  lLib := TPath.Combine(lDir, TPath.Combine('sub', 'lib.tpro'));
  lTpc := TPath.Combine(lDir, 'main.tpc');
  TFile.WriteAllText(lMain, '{{include "inc.tpro"}}{{import "sub/lib.tpro" as l}}{{>l.m()}}');
  TFile.WriteAllText(lInc, 'INC');
  TFile.WriteAllText(lLib, '{{macro m()}}M{{endmacro}}');
  lCompiler := TTProCompiler.Create;
  try
    Assert(not CompileStr('no dependencies').IsStale, 'A template without dependencies is never stale');

    lLoaded := SaveAndLoad(CompileMain);
    Assert(lLoaded.Render = 'INCM', 'Unexpected render: ' + lLoaded.Render);
    Assert(not lLoaded.IsStale, 'Just compiled: not stale');

    // the main source is not a dependency: the caller checks it
    TFile.WriteAllText(lMain, TFile.ReadAllText(lMain) + ' ');
    Assert(not lLoaded.IsStale, 'The main template is not a dependency');

    // an included file changes (content and time)
    TFile.WriteAllText(lInc, 'INC changed');
    TFile.SetLastWriteTime(lInc, IncHour(Now, 1));
    Assert(lLoaded.IsStale, 'Included file changed');

    // an imported file changes only its time
    lLoaded := SaveAndLoad(CompileMain);
    Assert(not lLoaded.IsStale, 'Recompiled: not stale');
    TFile.SetLastWriteTime(lLib, IncHour(Now, 2));
    Assert(lLoaded.IsStale, 'Imported file touched');

    // an imported file disappears
    lLoaded := SaveAndLoad(CompileMain);
    TFile.Delete(lLib);
    Assert(lLoaded.IsStale, 'Imported file deleted');

    // resolver-provided dependencies follow TTProConfiguration.TemplateChanged
    lCompiler.OnGetIncludedTemplate := MapResolver(['r_lib.tpro', '{{import "r_icons.tpro" as i}}{{macro m()}}R{{endmacro}}',
      'r_icons.tpro', '{{macro x()}}{{endmacro}}', 'r_inc.tpro', 'RI', 'r_layout.tpro', '[{{block "b"}}{{endblock}}]']);
    lLoaded := SaveAndLoad(lCompiler.Compile('{{import "r_lib.tpro" as r}}{{include "r_inc.tpro"}}{{>r.m()}}'));
    Assert(lLoaded.Render = 'RIR', 'Unexpected render: ' + lLoaded.Render);
    Assert(not lLoaded.IsStale, 'Resolver dependencies: not stale');
    TTProConfiguration.TemplateChanged('unrelated.tpro');
    Assert(not lLoaded.IsStale, 'Unrelated template changed');
    TTProConfiguration.TemplateChanged('R_LIB.TPRO'); // names are case-insensitive
    Assert(lLoaded.IsStale, 'Resolver-provided library changed');
    lLoaded := SaveAndLoad(lCompiler.Compile('{{include "r_inc.tpro"}}'));
    Assert(not lLoaded.IsStale, 'Recompiled after TemplateChanged');
    TTProConfiguration.TemplateChanged('r_inc.tpro');
    Assert(lLoaded.IsStale, 'Resolver-provided include changed');
    lLoaded := SaveAndLoad(lCompiler.Compile('{{import "r_lib.tpro" as r}}{{extends "r_layout.tpro"}}{{block "b"}}X{{endblock}}'));
    Assert(lLoaded.Render = '[X]', 'Unexpected render: ' + lLoaded.Render);
    Assert(not lLoaded.IsStale, 'Extends: not stale');
    TTProConfiguration.TemplateChanged('r_icons.tpro');
    Assert(lLoaded.IsStale, 'Library imported by a library changed');
    lLoaded := SaveAndLoad(lCompiler.Compile('{{import "r_lib.tpro" as r}}{{extends "r_layout.tpro"}}{{block "b"}}X{{endblock}}'));
    TTProConfiguration.TemplateChanged('r_layout.tpro');
    Assert(lLoaded.IsStale, 'Layout changed');
    lTemplate := nil;
    lLoaded := nil;
  finally
    lCompiler.Free;
    TDirectory.Delete(lDir, True);
  end;
  WriteLn('TestIsStale'.PadRight(45) + ' : OK');
end;

procedure TestMacroBodyFullRenderer;
// 1.2: a macro body runs through the full renderer (loops included), keeping the macro semantics
const
  LIST_MACRO = '{{macro lst(items)}}({{for x in items}}{{:x}}{{if !x.@@last}},{{endif}}{{else}}empty{{endfor}}){{endmacro}}';
var
  lTemplate: ITProCompiledTemplate;
  lArr, lEmpty: TJDOJsonArray;

  function T(const aSrc: string): ITProCompiledTemplate;
  begin
    lTemplate := CompileStr(aSrc);
    lTemplate.SetData('arr', lArr);
    lTemplate.SetData('empty', lEmpty);
    lTemplate.SetData('v', 'V');
    Result := lTemplate;
  end;

begin
  lArr := TJDOJsonArray.Parse('[1,2,3]') as TJDOJsonArray;
  lEmpty := TJDOJsonArray.Create;
  try
    AssertRendersAs(T(LIST_MACRO + '{{>lst(arr)}}'), '(1,2,3)', 'For loop in a macro');
    AssertRendersAs(T(LIST_MACRO + '{{>lst(empty)}}'), '(empty)', 'For..else in a macro');
    AssertRendersAs(T('{{macro m(n)}}{{for i in range(n)}}{{:i}}{{endfor}}{{endmacro}}{{>m(3)}}'), '012', 'Range in a macro');
    // the same loop expression in the caller and in the macro: two different loops
    AssertRendersAs(T('{{macro m(a)}}{{for x in a}}{{:x}}{{endfor}}{{endmacro}}{{set a := arr}}{{for x in a}}[{{>m(a)}}]{{endfor}}'),
      '[123][123][123]', 'Same loop in caller and macro');
    // the caller's loop variables are not visible in the macro...
    AssertRendersAs(T('{{macro m()}}<{{:x}}>{{endmacro}}{{for x in arr}}{{>m()}}{{endfor}}'), '<><><>', 'Caller loop not visible');
    // ...but they are in the slot content, even while the macro loops
    AssertRendersAs(T('{{macro m()}}{{for i in range(2)}}{{slot}}{{endfor}}{{endmacro}}{{for x in arr}}{{call m()}}{{:x}}{{endcall}}{{endfor}}'),
      '112233', 'Slot inside a macro loop sees the caller loop');
    AssertRendersAs(T('{{macro inner(a)}}{{for i in range(2)}}{{:a}}{{endfor}}{{endmacro}}' +
      '{{macro outer(arr)}}{{for x in arr}}{{>inner(x)}}|{{endfor}}{{endmacro}}{{>outer(arr)}}'), '11|22|33|', 'Macro loop calling a macro loop');
    // continue inside a macro loop
    AssertRendersAs(T('{{macro m(arr)}}{{for x in arr}}{{if x.@@first}}{{continue}}{{endif}}{{:x}}{{endfor}}{{endmacro}}{{>m(arr)}}'), '23', 'Continue in a macro loop');
    // an error inside a macro loop leaves the template usable
    lTemplate := T('{{macro m(arr)}}{{for x in arr}}{{@1/0}}{{endfor}}{{endmacro}}{{>m(arr)}}');
    AssertRenderRaises(lTemplate, 'Error evaluating expression', 'Error in a macro loop');
    AssertRendersAs(T(LIST_MACRO + '{{>lst(arr)}}'), '(1,2,3)', 'Render after an error');
    // the other statements behave as outside a macro
    AssertRendersAs(T('{{macro m(h)}}{{switch h}}{{case "<b>"}}S{{endswitch}}{{set z := "Z"}}{{:z}}{{raw}}{{:v}}{{endraw}}' +
      '{{autoescape false}}{{:h}}{{endautoescape}}{{:h}}{{endmacro}}{{>m("<b>")}}'),
      'SZ{{:v}}<b>&lt;b&gt;', 'switch, set, raw, autoescape in a macro');
    // include with mapping and dynamic include: in 1.1 the mapping was ignored and the dynamic include skipped
    lTemplate := CompileWith(MapResolver(['inc.tpro', '[{{:q}}]']),
      '{{macro m(p)}}{{include "inc.tpro", q = p}}{{include @(p + ".tpro")}}{{endmacro}}{{>m("inc")}}');
    lTemplate.OnGetDynamicallyIncludedTemplate := MapResolver(['inc.tpro', '<{{:p}}>']);
    AssertRendersAs(lTemplate, '[inc]<inc>', 'Includes in a macro');
    lTemplate := nil;
  finally
    lEmpty.Free;
    lArr.Free;
  end;
  WriteLn('TestMacroBodyFullRenderer'.PadRight(45) + ' : OK');
end;

procedure TestAttrFilter;
// 1.2: {{:model|attr,name}} reads a member by name from objects, datasets, JSON objects, dictionaries, TStrings
var
  lTemplate: ITProCompiledTemplate;
  lItem: TDataItem;
  lNullables: TDataItemNullables;
  lDS: TDataSet;
  lJSON: TJDOJsonObject;
  lDict: TDictionary<string, string>;
  lDictV: TDictionary<string, TValue>;
  lSL: TStringList;
begin
  lItem := TDataItem.Create('a', 'b', 'c', 7);
  lNullables := TDataItemNullables.Create('s', nil, 5, nil, nil, nil, nil, nil);
  lDS := GetDatasetWithNulls;
  lJSON := TJDOJsonObject.Parse('{"a":"x","b":2,"n":null}') as TJDOJsonObject;
  lDict := TDictionary<string, string>.Create;
  lDictV := TDictionary<string, TValue>.Create;
  lSL := TStringList.Create;
  try
    lDS.First;
    lDS.Next; // Bruce, 40, Salary NULL
    lDict.Add('email', 'e@x');
    lDictV.Add('age', 42);
    lSL.Add('k=v');
    lTemplate := CompileStr(
      '{{:o|attr,"prop1"}}|{{:o|attr,n}}|{{:o|attr,@("Prop" + "Int")}}|{{:o|attr,"missing"|default,"D"}}|{{:nothing|attr,"x"|default,"N"}}' +
      '#{{:nb|attr,"NullInt32"}}|{{:nb|attr,"NullBoolean"|default,"null"}}' +
      '#{{:ds|attr,"name"}}|{{:ds|attr,"Salary"|default,"null"}}|{{:ds|attr,"Age"}}|{{:ds|attr,"nope"|default,"-"}}' +
      '#{{:j|attr,"a"}}|{{:j|attr,"b"}}|{{:j|attr,"c"|default,"-"}}|{{:j|attr,"n"|default,"null"}}' +
      '#{{:d|attr,"email"}}|{{:d|attr,"no"|default,"-"}}|{{:dv|attr,"age"}}|{{:dv|attr,"no"|default,"-"}}' +
      '#{{:sl|attr,"k"}}|{{:sl|attr,"z"|default,"-"}}' +
      '#{{:o|attr,"Prop1"|uppercase}}{{if o|attr,"PropInt"|eq,7}}=7{{endif}}');
    lTemplate.SetData('o', lItem);
    lTemplate.SetData('n', 'Prop2');
    lTemplate.SetData('nb', lNullables);
    lTemplate.SetData('ds', lDS);
    lTemplate.SetData('j', lJSON);
    lTemplate.SetData('d', lDict);
    lTemplate.SetData('dv', lDictV);
    lTemplate.SetData('sl', lSL);
    AssertRendersAs(lTemplate, 'a|b|7|D|N#5|null#Bruce|null|40|-#x|2|-|null#e@x|-|42|-#v|-#A=7', 'attr');
    AssertRenderRaises(CompileStr('{{:o|attr}}'), 'Expected 1 parameters', 'attr without parameters');
    AssertRenderRaises(CompileStr('{{:o|attr,"a","b"}}'), 'Expected 1 parameters', 'attr with 2 parameters');
    // a custom filter named attr wins
    lTemplate := CompileStr('{{:o|attr,"Prop1"}}');
    lTemplate.SetData('o', lItem);
    lTemplate.AddFilter('attr',
      function(const aValue: TValue; const aParameters: TArray<TFilterParameter>): TValue
      begin
        Result := 'custom';
      end);
    AssertRendersAs(lTemplate, 'custom', 'custom attr');
    lTemplate := nil;
  finally
    lSL.Free;
    lDictV.Free;
    lDict.Free;
    lJSON.Free;
    lDS.Free;
    lNullables.Free;
    lItem.Free;
  end;
  WriteLn('TestAttrFilter'.PadRight(45) + ' : OK');
end;

type
  TFormModel = class
  private
    fCustomerName: string;
    fVAT_Number: string;
    fAge: Integer;
    fBig: Int64;
    fPrice: Double;
    fAmount: Currency;
    fBirthDate: TDate;
    fCreatedAt: TDateTime;
    fStartTime: TTime;
    fActive: Boolean;
    fNick: NullableString;
    fNoNick: NullableInt32;
    fChild: TDataItem;
    fTags: TArray<string>;
  public
    constructor Create;
    destructor Destroy; override;
    property CustomerName: string read fCustomerName write fCustomerName;
    property VAT_Number: string read fVAT_Number write fVAT_Number;
    property Age: Integer read fAge write fAge;
    property Big: Int64 read fBig write fBig;
    property Price: Double read fPrice write fPrice;
    property Amount: Currency read fAmount write fAmount;
    property BirthDate: TDate read fBirthDate write fBirthDate;
    property CreatedAt: TDateTime read fCreatedAt write fCreatedAt;
    property StartTime: TTime read fStartTime write fStartTime;
    property Active: Boolean read fActive write fActive;
    property Nick: NullableString read fNick write fNick;
    property NoNick: NullableInt32 read fNoNick write fNoNick;
    property Code: string read fCustomerName; // read-only
    property Child: TDataItem read fChild; // an object: skipped
    property Tags: TArray<string> read fTags; // an array: skipped
  end;

constructor TFormModel.Create;
begin
  inherited;
  fCustomerName := 'ACME';
  fVAT_Number := 'IT01';
  fAge := 42;
  fBig := 10000000000;
  fPrice := 1.5;
  fAmount := 2.25;
  fBirthDate := EncodeDate(2024, 8, 20);
  fCreatedAt := EncodeDateTime(2024, 8, 20, 10, 20, 30, 0);
  fStartTime := EncodeTime(9, 30, 0, 0);
  fActive := True;
  fNick := 'nn';
  fNoNick := nil;
  fChild := TDataItem.Create('a', 'b', 'c', 1);
end;

destructor TFormModel.Destroy;
begin
  fChild.Free;
  inherited;
end;

procedure TestFieldsMetadata;
// 1.2: {{for f in x.@@fields}} gives the same field metadata for datasets and objects
const
  META = '{{for f in m.@@fields}}{{:f.@@index}}:{{:f.FieldName}}/{{:f.DisplayLabel}}/{{:f.DataType}}/{{:f.Required}}/{{:f.ReadOnly}}/' +
    '{{:f.Size}}/{{:f.Visible}}/{{:f.Hidden}}{{if f.@@last}}.{{else}};{{endif}}{{endfor}}';
  VALUES = '{{for f in m.@@fields}}{{switch f.DataType}}{{case "ftDate"}}{{:f.Value|formatdatetime,"yyyy-mm-dd"}}' +
    '{{case "ftTime"}}{{:f.Value|formatdatetime,"hh:nn"}}{{case "ftDateTime"}}{{:f.Value|formatdatetime,"yyyy-mm-dd hh:nn"}}' +
    '{{default}}{{:f.Value}}{{endswitch}};{{endfor}}';
var
  lTemplate: ITProCompiledTemplate;
  lModel: TFormModel;
  lDS: TDataSet;
  lItems: TObjectList<TDataItem>;
  lCalls: string;
begin
  lModel := TFormModel.Create;
  lDS := GetCustomersDataset;
  lItems := GetItems;
  try
    lTemplate := CompileStr(META);
    lTemplate.SetData('m', lModel);
    AssertRendersAs(lTemplate,
      '1:CustomerName/Customer name/ftString/False/False/0/True/False;' +
      '2:VAT_Number/Vat number/ftString/False/False/0/True/False;' +
      '3:Age/Age/ftInteger/False/False/0/True/False;' +
      '4:Big/Big/ftLargeint/False/False/0/True/False;' +
      '5:Price/Price/ftFloat/False/False/0/True/False;' +
      '6:Amount/Amount/ftCurrency/False/False/0/True/False;' +
      '7:BirthDate/Birth date/ftDate/False/False/0/True/False;' +
      '8:CreatedAt/Created at/ftDateTime/False/False/0/True/False;' +
      '9:StartTime/Start time/ftTime/False/False/0/True/False;' +
      '10:Active/Active/ftBoolean/False/False/0/True/False;' +
      '11:Nick/Nick/ftString/False/False/0/True/False;' +
      '12:NoNick/No nick/ftInteger/False/False/0/True/False;' +
      '13:Code/Code/ftString/False/True/0/True/False.', 'Object metadata');
    lTemplate := CompileStr(VALUES);
    lTemplate.SetData('m', lModel);
    AssertRendersAs(lTemplate, 'ACME;IT01;42;10000000000;1.5;2.25;2024-08-20;2024-08-20 10:20;09:30;True;nn;;ACME;', 'Object values');
    // the hook changes the metadata of objects
    lCalls := '';
    TTProConfiguration.OnGetFieldMetadata :=
      procedure(const aObject: TObject; const aPropertyName: string; const aMetadata: TTProFieldMetadata)
      begin
        Assert(aObject = lModel, 'Hook: wrong object');
        lCalls := lCalls + aPropertyName.Substring(0, 1);
        if aPropertyName = 'CustomerName' then
        begin
          aMetadata.DisplayLabel := 'Customer';
          aMetadata.Size := 50;
          aMetadata.Required := True;
        end
        else if aPropertyName = 'Age' then
          aMetadata.ReadOnly := True
        else if aPropertyName = 'Big' then
          aMetadata.Hidden := True
        else if aPropertyName = 'VAT_Number' then
        begin
          aMetadata.DataType := 'ftMemo';
          aMetadata.Visible := False;
        end;
      end;
    try
      lTemplate := CompileStr('{{for f in m.@@fields}}{{if f.@@index|le,4}}{{:f.FieldName}}/{{:f.DisplayLabel}}/{{:f.DataType}}/' +
        '{{:f.Required}}/{{:f.ReadOnly}}/{{:f.Size}}/{{:f.Visible}}/{{:f.Hidden}};{{endif}}{{endfor}}');
      lTemplate.SetData('m', lModel);
      AssertRendersAs(lTemplate, 'CustomerName/Customer/ftString/True/False/50/True/False;VAT_Number/Vat number/ftMemo/False/False/0/False/False;' +
        'Age/Age/ftInteger/False/True/0/True/False;Big/Big/ftLargeint/False/False/0/True/True;', 'Hook');
      Assert(lCalls = 'CVABPABCSANNC', 'Hook calls: ' + lCalls);
    finally
      TTProConfiguration.OnGetFieldMetadata := nil;
    end;
    // a dataset answers the same names, @@fields is an alias of fields
    lTemplate := CompileStr('{{for f in m.@@fields}}{{:f.@@index}}:{{:f.FieldName}}/{{:f.DisplayLabel}}/{{:f.DataType}}/{{:f.Required}}/' +
      '{{:f.ReadOnly}}/{{:f.Size}}/{{:f.Visible}}/{{:f.Hidden}}={{:f.Value}}{{if f.@@last}}.{{else}};{{endif}}{{endfor}}');
    lTemplate.SetData('m', lDS);
    AssertRendersAs(lTemplate, '1:Code/Code/ftInteger/False/False/0/True/False=1;2:Name/Name/ftString/False/False/20/True/False=Ford.', 'Dataset');
    // inside a macro, on a loop variable, and on a null model (nothing to iterate)
    lTemplate := CompileStr('{{macro m(model)}}{{for f in model.@@fields}}{{:f.FieldName}}{{else}}none{{endfor}}{{endmacro}}' +
      '{{>m(o)}}|{{>m(nothing)}}|{{for x in list}}{{for f in x.@@fields}}{{:f.FieldName}}{{endfor}}{{endfor}}');
    lTemplate.SetData('o', lModel.Child);
    lTemplate.SetData('list', lItems);
    AssertRendersAs(lTemplate, 'Prop1Prop2Prop3PropInt|none|Prop1Prop2Prop3PropIntProp1Prop2Prop3PropIntProp1Prop2Prop3PropInt', 'Macro, loop variable, null');
    lTemplate := nil;
  finally
    lItems.Free;
    lDS.Free;
    lModel.Free;
  end;
  WriteLn('TestFieldsMetadata'.PadRight(45) + ' : OK');
end;

procedure TestJsonItemsAsObjects;
// 1.2: the items of a JSON array are JSON objects for filters and macros (attr, macro parameters); the output is unchanged
var
  lTemplate: ITProCompiledTemplate;
  lArr: TJDOJsonArray;
  lObj: TJDOJsonObject;
begin
  lArr := TJDOJsonArray.Parse('[{"id":1,"t":"a"},{"id":2,"t":"b"}]') as TJDOJsonArray;
  lObj := TJDOJsonObject.Parse('{"list":[{"id":3}]}') as TJDOJsonObject;
  try
    lTemplate := CompileStr('{{macro m(x)}}<{{:x.t}}>{{endmacro}}{{for o in arr}}{{:o|attr,"id"}}{{>m(o)}}{{:o$}}{{endfor}}' +
      '|{{for o in obj.list}}{{:o|attr,"id"}}{{:o$}}{{endfor}}');
    lTemplate.SetData('arr', lArr);
    lTemplate.SetData('obj', lObj);
    AssertRendersAs(lTemplate, '1<a>{"id":1,"t":"a"}2<b>{"id":2,"t":"b"}|3{"id":3}', 'JSON items');
    lTemplate := nil;
  finally
    lObj.Free;
    lArr.Free;
  end;
  WriteLn('TestJsonItemsAsObjects'.PadRight(45) + ' : OK');
end;

procedure TestFilteredValueOutput;
// 1.2: a filtered value is printed as an unfiltered one: null -> nothing, floats and dates with the template FormatSettings
var
  lTemplate: ITProCompiledTemplate;
  lModel: TFormModel;
  lSavedSeparator: Char;
begin
  lModel := TFormModel.Create;
  lSavedSeparator := FormatSettings.DecimalSeparator;
  FormatSettings.DecimalSeparator := ',';
  try
    lTemplate := CompileStr('[{{:m|attr,"missing"}}][{{:m|attr,"NoNick"}}]{{:m|attr,"Price"}}|{{:m|attr,"BirthDate"}}');
    lTemplate.SetData('m', lModel);
    AssertRendersAs(lTemplate, '[][]1.5|2024-08-20', 'Filtered values');
    lTemplate := nil;
  finally
    FormatSettings.DecimalSeparator := lSavedSeparator;
    lModel.Free;
  end;
  WriteLn('TestFilteredValueOutput'.PadRight(45) + ' : OK');
end;

procedure TestExpressionOutputUsesTemplateFormatSettings;
// 1.2: {{@expr}} prints floats and dates with the template FormatSettings, not with the process-wide ones
var
  lTemplate: ITProCompiledTemplate;
  lSavedSeparator: Char;
begin
  lSavedSeparator := FormatSettings.DecimalSeparator;
  FormatSettings.DecimalSeparator := ',';
  try
    lTemplate := CompileStr('{{@1.5 + 1}}|{{@2 + 3}}|{{@"a" + "b"}}|{{@1 < 2}}|{{@today()}}');
    AssertRendersAs(lTemplate, '2.5|5|ab|True|' + FormatDateTime('yyyy-mm-dd', Date), 'Invariant template FormatSettings');
    lTemplate := CompileStr('{{macro m()}}{{@1.5 + 1}}{{endmacro}}{{>m()}}');
    AssertRendersAs(lTemplate, '2.5', 'Expression in macro body');
    lTemplate := CompileStr('{{set x := @(1.5 + 1)}}{{:x}}|{{@1.5 + 1|default,"x"}}');
    AssertRendersAs(lTemplate, '2.5|2.5','Set from expression, filtered expression');
    FormatSettings.DecimalSeparator := '.';
    lTemplate := CompileStr('{{@1.5 + 1}}');
    lTemplate.FormatSettings^.DecimalSeparator := ',';
    AssertRendersAs(lTemplate, '2,5', 'Comma template FormatSettings');
    lTemplate := nil;
  finally
    FormatSettings.DecimalSeparator := lSavedSeparator;
  end;
  WriteLn('TestExpressionOutputUsesTemplateFormatSettings'.PadRight(45) + ' : OK');
end;

procedure TestMacroArgumentsWithFilters;
// 1.2: macro arguments (positional, named, defaults) accept filters, like {{:value|filter}}
const
  M = '{{macro m(a, b="-")}}[{{:a}}|{{:b}}]{{endmacro}}';
  P = '{{macro p(model)}}{{:model}}{{endmacro}}';
  D = '{{macro d(x=name|uppercase, y="k"|uppercase)}}[{{:x}}{{:y}}]{{endmacro}}';
var
  lSetup: TProc<ITProCompiledTemplate>;
  lTemplate: ITProCompiledTemplate;
  lArr: TJDOJsonArray;
  lSrc: string;
begin
  lArr := TJDOJsonArray.Parse('[10,20]') as TJDOJsonArray;
  try
    lSetup := procedure(aTemplate: ITProCompiledTemplate)
      begin
        aTemplate.SetData('name', 'Bob');
        aTemplate.SetData('num', 7);
        aTemplate.SetData('items', lArr);
      end;
    lSrc := M + P + D +
      '{{>m(name|uppercase)}}' +                      // positional
      '{{>m(a=name|uppercase, b="lg")}}' +            // named
      '{{>m(name, b = name|lowercase|uppercase)}}' +  // chained
      '{{>m(a=num|lpad,3, b="x")}}' +                 // filter with parameters, then a named argument
      '{{>m("y", num|lpad,3)}}' +                     // filter with parameters on the last positional
      '{{>m("abc"|uppercase, b=@("a" + "b")|uppercase)}}' +    // literal and expression with filters
      '{{>p(model=items|first)}}' +                   // object value through a filter
      '{{call m(a=name|lowercase)}}{{endcall}}' +     // call
      '{{>d()}}{{>d(y="z")}}';                        // defaults with filters
    AssertCompileRaises('{{macro r(a|uppercase)}}{{endmacro}}', 'filters are allowed only on a default value', 'Filter on a required parameter');
    lTemplate := CompileStr(lSrc);
    lSetup(lTemplate);
    AssertRendersAs(lTemplate, '[BOB|-][BOB|lg][Bob|BOB][  7|x][y|  7][ABC|AB]10[bob|-][BOBK][BOBz]', 'Macro arguments with filters');
    lTemplate := nil;
    AssertSurvivesSaveLoad(lSrc, lSetup, 'Macro arguments with filters');
  finally
    lArr.Free;
  end;
  WriteLn('TestMacroArgumentsWithFilters'.PadRight(45) + ' : OK');
end;

procedure TestContainsFilters;
// 1.2: icontains ignores the case of the parameter too; contains/icontains work on any value (as printed)
var
  lTemplate: ITProCompiledTemplate;
begin
  lTemplate := CompileStr('{{:v|icontains,"AbC"}}|{{:v|icontains,@("A" + "B")}}|{{:n|contains,"2"}}|{{:n|icontains,"4"}}|{{:nothing|contains,"a"}}');
  lTemplate.SetData('v', 'xxabcxx');
  lTemplate.SetData('n', 123);
  AssertRendersAs(lTemplate, 'True|True|True|False|False', 'contains');
  lTemplate := nil;
  WriteLn('TestContainsFilters'.PadRight(45) + ' : OK');
end;

procedure TestListOfSimpleValues;
// 1.2: a list of simple values (e.g. TList<string>) can be iterated, its items are the values
var
  lTemplate: ITProCompiledTemplate;
  lNames: TList<string>;
  lInts: TList<Integer>;
begin
  lNames := TList<string>.Create;
  lInts := TList<Integer>.Create;
  try
    lNames.AddRange(['a', 'b']);
    lInts.AddRange([1, 2]);
    lTemplate := CompileStr('{{for s in names}}{{:s}}{{:s.@@index}}{{if s|eq,"b"}}!{{endif}},{{endfor}}{{for i in ints}}{{:i}}{{endfor}}');
    lTemplate.SetData('names', lNames);
    lTemplate.SetData('ints', lInts);
    AssertRendersAs(lTemplate, 'a1,b2!,12', 'List of simple values');
    lTemplate := nil;
  finally
    lInts.Free;
    lNames.Free;
  end;
  WriteLn('TestListOfSimpleValues'.PadRight(45) + ' : OK');
end;

procedure TestFormLibraries;
// 1.2: lib\forms_html.tpro and lib\forms_bootstrap5.tpro: same macros and parameters (the contract), different markup
const
  FORM = '{{import "forms.tpro" as f}}'#10 +
    '{{call f.form("/save", method="get", class="my-form", attrs=hx)}}'#10 +
    '{{>f.input("email", label="E-mail", type="email", required=true, readonly=true, placeholder="you@x", maxlength=50, class="c1", attrs=hx)}}'#10 +
    '{{>f.input("quote")}}'#10 +
    '{{>f.textarea("notes", label="Notes", rows=5, required=true, readonly=true, class="c2", attrs=hx)}}'#10 +
    '{{>f.select("country", countries, label="Country", valueprop="PropInt", textprop="Prop1", empty="--", required=true, class="c3", attrs=hx)}}'#10 +
    '{{>f.select("color", colors, label="Color")}}'#10 +
    '{{>f.select("size", sizes, valueprop="v", textprop="t")}}'#10 +
    '{{>f.checkbox("active", label="Active", class="c4", attrs=hx)}}'#10 +
    '{{>f.checkbox("off", label="Off")}}'#10 +
    '{{call f.actions()}}'#10'{{>f.submit("Go", class="c5", attrs=hx)}}'#10'{{>f.submit()}}'#10'{{endcall}}'#10 +
    '{{endcall}}'#10 +
    '{{>f.auto(obj, exclude="Big, nothing")}}'#10 +
    '{{>f.auto(ds, errors=dserrors)}}'#10;
var
  lModel: TDictionary<string, TValue>;
  lErrors, lDSErrors: TDictionary<string, string>;
  lCountries: TObjectList<TDataItem>;
  lColors: TList<string>;
  lSizes: TJDOJsonArray;
  lObj: TFormModel;
  lDS: TDataSet;

  function MacroSignatures(const aLibFile: string): string;
  var
    lMatch: TMatch;
  begin
    Result := '';
    for lMatch in TRegEx.Matches(TFile.ReadAllText(aLibFile), '\{\{macro [^}]*\}\}') do
      Result := Result + lMatch.Value + #10;
  end;

  function RenderWith(const aLibFile: string): string;
  var
    lCompiler: TTProCompiler;
    lTemplate: ITProCompiledTemplate;
  begin
    lCompiler := TTProCompiler.Create;
    try
      lCompiler.OnGetIncludedTemplate := MapResolver(['forms.tpro', TFile.ReadAllText(aLibFile)]);
      lTemplate := lCompiler.Compile(FORM);
    finally
      lCompiler.Free;
    end;
    lTemplate.SetData('formModel', lModel);
    lTemplate.SetData('formErrors', lErrors);
    lTemplate.SetData('dserrors', lDSErrors);
    lTemplate.SetData('countries', lCountries);
    lTemplate.SetData('colors', lColors);
    lTemplate.SetData('sizes', lSizes);
    lTemplate.SetData('obj', lObj);
    lTemplate.SetData('ds', lDS);
    lTemplate.SetData('hx', 'hx-post="/x"');
    Result := lTemplate.Render;
  end;

  procedure AssertHas(const aOutput, aMarker, aCase: string);
  begin
    Assert(aOutput.Contains(aMarker), aCase + ': missing [' + aMarker + '] in:'#10 + aOutput);
  end;

  procedure AssertContract(const aOutput, aCase: string);
  var
    lMarker: string;
  begin
    for lMarker in ['action="/save" method="get" class="my-form" hx-post="/x">', 'for="email"', 'id="email" name="email"',
      'type="email"', 'value="a&quot;b&lt;c&gt;"', 'value="x &quot;y&quot;"', ' required', ' readonly', 'placeholder="you@x"',
      'maxlength="50"', 'Bad &lt;email&gt;', 'rows="5"', '>n &amp; m</textarea>', '<option value="">--</option>',
      '<option value="1">Italy</option>', '<option value="2" selected>Spain</option>', 'Pick one',
      '<option value="red">red</option>', '<option value="green" selected>green</option>',
      '<option value="S">Small</option>', '<option value="M" selected>Medium</option>',
      '<input type="hidden" name="active" value="false">', 'name="active" value="true"', ' checked', 'name="off" value="true">',
      'Go</button>', 'Submit</button>',
      // auto on an object
      'for="CustomerName"', '>Customer name<', '>Vat number<', 'name="CustomerName" value="ACME"', 'name="Age" value="42"',
      'type="number"', 'name="Price" value="1.5"', 'step=any', 'type="date"', 'name="BirthDate" value="2024-08-20"',
      'type="datetime-local"', 'name="CreatedAt" value="2024-08-20T10:20"', 'type="time"', 'name="StartTime" value="09:30"',
      'name="Active" value="true" checked', 'name="NoNick" value=""', 'name="Code" value="ACME" readonly',
      '<input type="hidden" id="Age" name="Age" value="42">', 'name="CustomerName" value="ACME" required',
      // auto on a dataset
      'name="Code" value="1"', 'name="Name" value="Ford" maxlength="20"', 'Too short'] do
      AssertHas(aOutput, lMarker, aCase);
    Assert(not aOutput.Contains('name="Big"'), aCase + ': excluded field rendered');
    Assert(not aOutput.Contains('name="Nick"'), aCase + ': not Visible field rendered');
    Assert(not aOutput.Contains('name="Child"') and not aOutput.Contains('name="Tags"'), aCase + ': object/array property rendered');
    Assert(not aOutput.Contains(#10#10), aCase + ': blank line in:'#10 + aOutput);
  end;

var
  lHtml, lBS: string;
begin
  lModel := TDictionary<string, TValue>.Create;
  lErrors := TDictionary<string, string>.Create;
  lDSErrors := TDictionary<string, string>.Create;
  lCountries := TObjectList<TDataItem>.Create(True);
  lColors := TList<string>.Create;
  lSizes := TJDOJsonArray.Parse('[{"v":"S","t":"Small"},{"v":"M","t":"Medium"}]') as TJDOJsonArray;
  lObj := TFormModel.Create;
  lDS := GetCustomersDataset;
  try
    lModel.Add('email', 'a"b<c>');
    lModel.Add('quote', 'x "y"');
    lModel.Add('notes', 'n & m');
    lModel.Add('country', 2);
    lModel.Add('color', 'green');
    lModel.Add('size', 'M');
    lModel.Add('active', True);
    lModel.Add('off', False);
    lErrors.Add('email', 'Bad <email>');
    lErrors.Add('country', 'Pick one');
    lDSErrors.Add('Name', 'Too short');
    lCountries.Add(TDataItem.Create('Italy', '', '', 1));
    lCountries.Add(TDataItem.Create('Spain', '', '', 2));
    lColors.AddRange(['red', 'green']);
    Assert(MacroSignatures('..\..\lib\forms_html.tpro') = MacroSignatures('..\..\lib\forms_bootstrap5.tpro'),
      'The two libraries must declare the same macros with the same parameters');
    // the metadata hook drives auto on objects
    TTProConfiguration.OnGetFieldMetadata :=
      procedure(const aObject: TObject; const aPropertyName: string; const aMetadata: TTProFieldMetadata)
      begin
        if aPropertyName = 'Age' then
          aMetadata.Hidden := True
        else if aPropertyName = 'Nick' then
          aMetadata.Visible := False
        else if aPropertyName = 'CustomerName' then
          aMetadata.Required := True;
      end;
    try
      lHtml := RenderWith('..\..\lib\forms_html.tpro');
      lBS := RenderWith('..\..\lib\forms_bootstrap5.tpro');
    finally
      TTProConfiguration.OnGetFieldMetadata := nil;
    end;
    AssertContract(lHtml, 'forms_html');
    AssertContract(lBS, 'forms_bootstrap5');
    // variant markup
    AssertHas(lBS, 'class="form-control is-invalid c1"', 'forms_bootstrap5');
    AssertHas(lBS, '<div class="invalid-feedback">Bad &lt;email&gt;</div>', 'forms_bootstrap5');
    AssertHas(lBS, 'class="form-select is-invalid c3"', 'forms_bootstrap5');
    AssertHas(lBS, 'class="form-check-input c4"', 'forms_bootstrap5');
    AssertHas(lBS, 'class="btn btn-primary c5"', 'forms_bootstrap5');
    AssertHas(lHtml, 'aria-invalid="true" aria-describedby="email-error"', 'forms_html');
    AssertHas(lHtml, '<small id="email-error">Bad &lt;email&gt;</small>', 'forms_html');
    // classless: the only classes are the ones passed
    Assert(TRegEx.Matches(lHtml, 'class="').Count = 6, 'forms_html: unexpected class attributes in:'#10 + lHtml);
  finally
    lDS.Free;
    lObj.Free;
    lSizes.Free;
    lColors.Free;
    lCountries.Free;
    lDSErrors.Free;
    lErrors.Free;
    lModel.Free;
  end;
  WriteLn('TestFormLibraries'.PadRight(45) + ' : OK');
end;

var
  gRegressionFailed: Boolean = False;

procedure TestCompiledTemplateBytes;
// SaveToBytes/CreateFromBytes: an in-memory compiled template, no files involved
const
  UI_LIB = '{{macro panel(t)}}<{{:t}}:{{slot}}>{{endmacro}}';
  SRC = '{{import "lib/ui.tpro" as ui}}{{stack "s"}}{{call ui.panel(v)}}{{push "s"}}P{{endpush}}X{{endcall}}';
var
  lTemplate, lA, lB: ITProCompiledTemplate;
  lBytes, lBad: TBytes;
  lExpected: string;
  lRaised: Boolean;
begin
  lTemplate := CompileWith(MapResolver(['lib/ui.tpro', UI_LIB]), SRC);
  lTemplate.SetData('v', 'V');
  lExpected := lTemplate.Render;
  Assert(lExpected = 'P<V:X>', 'Unexpected source render: ' + lExpected);
  lBytes := lTemplate.SaveToBytes;
  Assert(Length(lBytes) > 0, 'Empty bytes');

  lA := TTProCompiledTemplate.CreateFromBytes(lBytes);
  lB := TTProCompiledTemplate.CreateFromBytes(lBytes);
  lA.SetData('v', 'V');
  lB.SetData('v', 'W');
  AssertRendersAs(lA, lExpected, 'Bytes round-trip');
  AssertRendersAs(lB, 'P<W:X>', 'Second instance from the same bytes');
  AssertRendersAs(lA, lExpected, 'First instance not affected by the second');

  lBad := Copy(lBytes);
  lBad[0] := 255;
  lRaised := False;
  try
    TTProCompiledTemplate.CreateFromBytes(lBad);
  except
    on E: ETProException do
      lRaised := ContainsText(E.Message, 'invalid');
  end;
  Assert(lRaised, 'Corrupted bytes were loaded');
  WriteLn('TestCompiledTemplateBytes'.PadRight(45) + ' : OK');
end;

procedure RunRegressionTest(const aName: string; const aTest: TProc);
begin
  try
    aTest();
  except
    on E: Exception do
    begin
      WriteLn(aName.PadRight(45) + ' : FAIL - ' + E.ClassName + ': ' + E.Message);
      gRegressionFailed := True;
    end;
  end;
end;

procedure Main;
var
  lTPro: TTProCompiler;
  lInput: string;
  lItems, lItemsWithFalsy: TObjectList<TDataItem>;
  lItemsNullables: TObjectList<TDataItemNullables>;
  lFailed: Boolean;
  lActualOutput: String;
  lInputFileNames: TArray<string>;
  lFile: string;
  lTestScriptsFolder: string;
  lCompiledTemplate: ITProCompiledTemplate;
  lExpectedExceptionMessage: string;
  lExpectedOutput: string;
  lJSONArr: TJsonArray;
  lJSONArrEmpty: TJsonArray;
  lJSONObj: TJsonObject;
  lJSONObj2: TJsonObject;
  lCustomers: TDataSet;
  lCustomer: TDataSet;
  lEmptyDataSet: TDataSet;
  lDataItemWithChild: TDataItemWithChild;
  lDataItemWithChildList: TDataItemWithChildList;
  lDataItemAsObjectsList: TObjectList<TDataItemWithChild>;
  lUltraNestedList: TObjectList<TObjectList<TObjectList<TSimpleDataItem>>>;
  lEmptyList: TObjectList<TObjectList<TObjectList<TSimpleDataItem>>>;
  lTestDataSet: TDataSet;
  lDataSetWithNulls: TDataSet;
  lSimpleNested: TSimpleNested1;
  lItemNullable: TDataItemNullables;
  lItemNullableAllNull: TDataItemNullables;
begin
  lFailed := False;
  lActualOutput := '';
  lTPro := TTProCompiler.Create;
  try
    lInputFileNames := TDirectory.GetFiles('..\test_scripts\', '*.tpro',
      function(const Path: string; const SearchRec: TSearchRec): Boolean
      begin
        Result := (not String(SearchRec.Name).StartsWith('included')) and
          (not String(SearchRec.Name).StartsWith('layout')) and ((TestFileNameFilter = '*') or String(SearchRec.Name)
          .Contains(TestFileNameFilter));
        Result := Result and not(String(SearchRec.Name).StartsWith('_'));
      end);
    for lFile in lInputFileNames do
    begin
      try
        if TFile.Exists(lFile + '.failed.txt') then
        begin
          TFile.Delete(lFile + '.failed.txt');
        end;

        lInput := TFile.ReadAllText(lFile, TEncoding.UTF8);
        Write(TPath.GetFileName(lFile).PadRight(45));
        lTestScriptsFolder := TPath.Combine(GetModuleName(HInstance), '..', '..', 'test_scripts');
        lActualOutput := '';
        lCompiledTemplate := nil;
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
          lExpectedExceptionMessage := TFile.ReadAllText(lFile + '.expected.exception.txt', TEncoding.UTF8);
          if not SameText(lActualOutput, lExpectedExceptionMessage) then
          begin
            lFailed := True;
            WriteLn(' : WRONG EXCEPTION');
            TFile.WriteAllText(lFile + '.failed.txt', lActualOutput, TEncoding.UTF8);
          end
          else
          begin
            WriteLn(' : OK');
          end;
          lCompiledTemplate := nil;  // Explicitly release before Continue
          Continue;
        end;
        // lCompiledTemplate.FormatSettings.DateSeparator := '-';
        // lCompiledTemplate.FormatSettings.TimeSeparator := ':';
        // lCompiledTemplate.FormatSettings.DecimalSeparator := '.';
        // lCompiledTemplate.FormatSettings.ThousandSeparator := ',';
        // lCompiledTemplate.FormatSettings.ShortDateFormat := 'yyyy-mm-dd';
        // lCompiledTemplate.FormatSettings^ := TFormatSettings.Create('en-US');
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
        // Variables for dynamic include tests
        lCompiledTemplate.SetData('template_name', 'included_dynamic.tpro');
        lCompiledTemplate.SetData('template_type', 'dynamic');
        lCompiledTemplate.SetData('content', 'Hello Dynamic');
        // Variables for Issue #1 test: ISO 8601 datetime strings
        lCompiledTemplate.SetData('iso8601_with_tz', '2025-12-30T14:23:08.281+01:00');
        lCompiledTemplate.SetData('iso8601_utc', '2025-12-30T14:23:08.281Z');
        lCompiledTemplate.SetData('iso8601_no_tz', '2025-12-30T14:23:08');
        lCompiledTemplate.SetData('simple_date_str', '2025-12-30');
        lCompiledTemplate.SetData('empty_date_str', '');
        lCompiledTemplate.SetData('invalid_date_str', 'not-a-date');
        // Variables for NullableTDateTime test
        lCompiledTemplate.SetData('nullable_datetime', TValue.From<NullableTDateTime>(EncodeDateTime(2025, 12, 30, 14, 30, 45, 0)));
        lCompiledTemplate.SetData('nullable_datetime_null', TValue.From<NullableTDateTime>(nil));
        lJSONArr := TJsonBaseObject.ParseFromFile(TPath.Combine(lTestScriptsFolder, 'people.json')) as TJsonArray;
        lJSONArrEmpty := TJsonArray.Create;
        try
          lJSONObj := TJsonObject.Create;
          try
            lJSONObj.A['people'] := lJSONArr.Clone;
            lJSONObj2 := TJsonBaseObject.ParseFromFile(TPath.Combine(lTestScriptsFolder, 'test.json')) as TJsonObject;
            try
              lItems := GetItems;
              try
                lItemsNullables := GetItemsNullables;
                try
                  lItemsWithFalsy := GetItems(True);
                  try
                    lCompiledTemplate.SetData('obj', lItems[0]);
                    lCustomers := GetCustomersDataset;
                    try
                      lCustomer := GetSingleCustomerDataset;
                      try
                        lEmptyDataSet := GetEmptyDataset;
                        try
                          lDataItemWithChild := TDataItemWithChild.Create('value1', 1);
                          try
                            lDataItemWithChildList := TDataItemWithChildList.Create('value1','value2','value3',3);
                            try
                              lDataItemAsObjectsList := TObjectList<TDataItemWithChild>.Create(True);
                              try
                                lDataItemAsObjectsList.Add(TDataItemWithChild.Create('Str0', 0));
                                lDataItemAsObjectsList.Add(TDataItemWithChild.Create('Str1', 1));
                                lDataItemAsObjectsList.Add(TDataItemWithChild.Create('Str2', 2));

                                lUltraNestedList := TObjectList<TObjectList<TObjectList<TSimpleDataItem>>>.Create(True);
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

                                  lEmptyList := TObjectList<TObjectList<TObjectList<TSimpleDataItem>>>.Create(True);
                                  try
                                    lEmptyList.Add(TObjectList<TObjectList<TSimpleDataItem>>.Create(True));
                                    lEmptyList.Last.Add(TObjectList<TSimpleDataItem>.Create(True));
                                    lTestDataSet := GetTestDataset;
                                    try
                                      lDataSetWithNulls := GetDatasetWithNulls;
                                      try
                                      lSimpleNested := TSimpleNested1.Create('ValueNested');
                                      try
                                        lItemNullable := TDataItemNullables.Create('Daniele', True, 123, 234,
                                          EncodeDate(1979,11,04),
                                          EncodeDateTime(1979,11,04, 17, 18, 19, 0),
                                          EncodeTime(17, 18, 19, 0),
                                          1234.5678);
                                        lItemNullableAllNull := TDataItemNullables.Create(nil,nil,nil,nil,nil,nil,nil,nil);
                                        try
                                          lCompiledTemplate.SetData('emptydataset', lEmptyDataSet);
                                          lCompiledTemplate.SetData('customer', lCustomer);
                                          lCompiledTemplate.SetData('customers', lCustomers);
                                          lCompiledTemplate.SetData('testdst', lTestDataSet);
                                          lCompiledTemplate.SetData('datasetnulls', lDataSetWithNulls);
                                          lCompiledTemplate.SetData('objects', lItems);
                                          lCompiledTemplate.SetData('objects_nullables', lItemsNullables);
                                          lCompiledTemplate.SetData('dataitems', lDataItemWithChildList);
                                          lCompiledTemplate.SetData('dataitemsasobjectlist', lDataItemAsObjectsList);
                                          lCompiledTemplate.SetData('ultranestedlist', lUltraNestedList);
                                          lCompiledTemplate.SetData('emptylist', lEmptyList);
                                          lCompiledTemplate.SetData('nested', lSimpleNested);
                                          lCompiledTemplate.SetData('objectsb', lItemsWithFalsy);
                                          lCompiledTemplate.SetData('jsonobj', lJSONObj);
                                          lCompiledTemplate.SetData('json2', lJSONObj2);
                                          lCompiledTemplate.SetData('jsonarray', lJSONArr);
                                          lCompiledTemplate.SetData('jsonarrayempty', lJSONArrEmpty);
                                          lCompiledTemplate.SetData('dataitem', lDataItemWithChild);
                                          lCompiledTemplate.SetData('dataitemnullable', lItemNullable);
                                          lCompiledTemplate.SetData('dataitemnullableallnull', lItemNullableAllNull);
                                          lActualOutput := '';
                                          try
                                            lActualOutput := lCompiledTemplate.Render;
                                          except
                                            on E: Exception do
                                            begin
                                              lActualOutput := E.Message;
                                            end;
                                          end;
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
                                          lItemNullable.Free;
                                          lItemNullableAllNull.Free;
                                        end;
                                      finally
                                        lSimpleNested.Free;
                                      end;
                                      finally
                                        lDataSetWithNulls.Free;
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
                  lItemsNullables.Free;
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
          lJSONArrEmpty.Free;
        end;
        // Explicitly release interface to avoid memory leaks
        lCompiledTemplate := nil;
      except
        on E: Exception do
        begin
          WriteLn(' : FAIL - ' + E.Message);
          lFailed := True;
          lCompiledTemplate := nil;
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
      TestCompiledTemplateOutputIdentical;
      TestCompiledTemplateTokensPreserved;
      TestCompiledTemplateUnicodePreserved;
      TestCompiledTemplateMultipleRenders;
      TestCompiledFileBinaryEquality;
      TestHTMLEntities;
      TestGetTValueFromPath;
      TestExpressionEvaluator;
      TestExpressionInTemplate;
      TestExpressionWithFilters;
      TestExpressionInIf;
      // Tests for OnGetIncludedTemplate callback
      TestOnGetIncludedTemplate_StaticInclude;
      TestOnGetIncludedTemplate_NestedIncludes;
      TestOnGetIncludedTemplate_NotHandled;
      TestOnGetDynamicallyIncludedTemplate;
      TestOnGetIncludedTemplate_WithExtends;
      TestOnGetIncludedTemplate_MultipleTemplates;
      // Regression tests for critical issues found in the v1.1 review
      RunRegressionTest('TestRenderDoesNotFreeCallerObjects', TestRenderDoesNotFreeCallerObjects);
      RunRegressionTest('TestFilterObjectOwnership', TestFilterObjectOwnership);
      RunRegressionTest('TestRenderStateResetAfterFailure', TestRenderStateResetAfterFailure);
      RunRegressionTest('TestExpressionNestingLimit', TestExpressionNestingLimit);
      RunRegressionTest('TestRenderNestingLimit', TestRenderNestingLimit);
      RunRegressionTest('TestHTMLEncodeLinearTime', TestHTMLEncodeLinearTime);
      RunRegressionTest('TestIncludeCycleDetected', TestIncludeCycleDetected);
      RunRegressionTest('TestDynamicIncludeRootPath', TestDynamicIncludeRootPath);
      RunRegressionTest('TestLoadCorruptedCompiledTemplate', TestLoadCorruptedCompiledTemplate);
      // 1.2 features
      RunRegressionTest('TestCustomFilterOverridesBuiltIn', TestCustomFilterOverridesBuiltIn);
      RunRegressionTest('TestRangeKeepsStringLiterals', TestRangeKeepsStringLiterals);
      RunRegressionTest('TestExpressionShortCircuitAndModByZero', TestExpressionShortCircuitAndModByZero);
      RunRegressionTest('TestExpressionErrorsAreRenderExceptions', TestExpressionErrorsAreRenderExceptions);
      RunRegressionTest('TestRoundUsesTemplateFormatSettings', TestRoundUsesTemplateFormatSettings);
      RunRegressionTest('TestSwitchCase', TestSwitchCase);
      RunRegressionTest('TestForRange', TestForRange);
      RunRegressionTest('TestNewFilters', TestNewFilters);
      RunRegressionTest('TestMacroNamedAndOptionalArgs', TestMacroNamedAndOptionalArgs);
      RunRegressionTest('TestPushStack', TestPushStack);
      RunRegressionTest('TestImportLibrary', TestImportLibrary);
      RunRegressionTest('TestSlots', TestSlots);
      RunRegressionTest('TestGlobalTemplateResolver', TestGlobalTemplateResolver);
      RunRegressionTest('TestIsStale', TestIsStale);
      RunRegressionTest('TestMacroBodyFullRenderer', TestMacroBodyFullRenderer);
      RunRegressionTest('TestAttrFilter', TestAttrFilter);
      RunRegressionTest('TestFieldsMetadata', TestFieldsMetadata);
      RunRegressionTest('TestJsonItemsAsObjects', TestJsonItemsAsObjects);
      RunRegressionTest('TestFilteredValueOutput', TestFilteredValueOutput);
      RunRegressionTest('TestCompiledTemplateBytes', TestCompiledTemplateBytes);
      RunRegressionTest('TestContainsFilters', TestContainsFilters);
      RunRegressionTest('TestListOfSimpleValues', TestListOfSimpleValues);
      RunRegressionTest('TestFormLibraries', TestFormLibraries);
      RunRegressionTest('TestExpressionOutputUsesTemplateFormatSettings', TestExpressionOutputUsesTemplateFormatSettings);
      RunRegressionTest('TestMacroArgumentsWithFilters', TestMacroArgumentsWithFilters);
      RunRegressionTest('TestDataSetFieldTypes', TestDataSetFieldTypes);
      if gRegressionFailed then
        Halt(1);
    end;
    Main;
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      if DebugHook <> 0 then
      begin
        Write(E.Message);
      end;
      Halt(1);
    end;
  end;

end.
