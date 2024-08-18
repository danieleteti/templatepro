program tproconsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils, TemplatePro, Data.DB, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Comp.DataSet, FireDAC.Comp.Client, System.Rtti, JsonDataObjects;

function GetPeopleDataset: TDataSet;
var
  lMT: TFDMemTable;
begin
  lMT := TFDMemTable.Create(nil);
  try
    lMT.FieldDefs.Clear;
    lMT.FieldDefs.Add('id', ftInteger);
    lMT.FieldDefs.Add('first_name', ftString, 20);
    lMT.FieldDefs.Add('last_name', ftString, 20);
    lMT.Active := True;
    lMT.AppendRecord([1, 'Daniele', 'Teti']);
    lMT.AppendRecord([2, 'Peter', 'Parker']);
    lMT.AppendRecord([3, 'Bruce', 'Banner']);
    lMT.AppendRecord([4, 'Scott', 'Summers']);
    lMT.AppendRecord([5, 'Sue', 'Storm']);
    lMT.First;
    Result := lMT;
  except
    lMT.Free;
    raise;
  end;
end;

function GetJSON: TJSONObject;
var
  ChildObj: TJsonObject;
begin
  Result := TJsonObject.Create;
  Result.I['foo'] := 123;
  Result.S['bar'] := 'hello';
  ChildObj := Result.A['myarray'].AddObject;
  ChildObj.S['first_name'] := 'Daniele';
  ChildObj.S['last_name'] := 'Teti';
  ChildObj := ChildObj.O['company'];
  ChildObj.S['name'] := 'bit Time Professionals';
  ChildObj.S['country'] := 'ITALY';

  ChildObj := Result.A['myarray'].AddObject;
  ChildObj.S['first_name'] := 'Bruce';
  ChildObj.S['last_name'] := 'Banner';
  ChildObj := ChildObj.O['company'];
  ChildObj.S['name'] := 'Green Power';
  ChildObj.S['country'] := 'CA';
end;

function AddSquareBrackets(const aValue: TValue; const aParameters: TArray<string>): string;
begin
  Result := '[' + aValue.AsString + ']';
end;

procedure Main;
begin
  var lCompiler := TTProCompiler.Create();
  try
    var lTemplate :=

    'Simple variable:                                                           ' + sLineBreak +
    '{{:variable1}}                                                             ' + sLineBreak +
    '                                                                           ' + sLineBreak +
    'Using loops:                                                               ' + sLineBreak +
    '{{loop(people) as person}}                                                 ' + sLineBreak +
    '  - {{:person.id}}) {{:person.first_name}}, {{:person.last_name}}          ' + sLineBreak +
    '{{endloop}}                                                                ' + sLineBreak +
    '                                                                           ' + sLineBreak +
    'Using if statement:                                                        ' + sLineBreak +
    '{{if(people)}}People dataset contains records{{endif}}                     ' + sLineBreak +
    '{{if(!people)}}People dataset doesn''t contain records{{endif}}            ' + sLineBreak +
    '                                                                           ' + sLineBreak +
    '                                                                           ' + sLineBreak +
    'Using filters:                                                             ' + sLineBreak +
    'uppercase: {{:variable1|uppercase}}                                        ' + sLineBreak +
    'lowercase: {{:variable1|lowercase}}                                        ' + sLineBreak +
    'lpad     : {{:variable1|lpad:20:"*"}}                                      ' + sLineBreak +
    'rpad     : {{:variable1|rpad:20:"*"}}                                      ' + sLineBreak +
    '                                                                           ' + sLineBreak +
    'Using custom filters:                                                      ' + sLineBreak +
    'brackets : {{:variable1|brackets}}                                         ' + sLineBreak +
    '                                                                           ' + sLineBreak +
    'Using json objects:                                                        ' + sLineBreak +
    '{{:jobj.foo}}                                                              ' + sLineBreak +
    '{{:jobj.bar}}                                                              ' + sLineBreak +
    '{{""|lpad:40:"_"}}                                                         ' + sLineBreak +
    '{{loop(jobj.myarray) as item}}                                             ' + sLineBreak +
    '  - {{:item.first_name}} {{:item.last_name}}                               ' + sLineBreak +
    '    {{:item.company.name}} - {{:item.company.country}}                     ' + sLineBreak +
    '{{endloop}}                                                                ' + sLineBreak;

    var lCompiledTemplate := lCompiler.Compile(lTemplate);
    var lPeopleDataset := GetPeopleDataset;
    try
      var lJObj := GetJSON;
      try
        lCompiledTemplate.AddFilter('brackets', AddSquareBrackets);
        lCompiledTemplate.SetData('variable1', 'Daniele Teti');
        lCompiledTemplate.SetData('people', lPeopleDataset);
        lCompiledTemplate.SetData('jobj', lJObj);
        WriteLn(lCompiledTemplate.Render);
      finally
        lJObj.Free;
      end;
    finally
      lPeopleDataset.Free;
    end;
  finally
    lCompiler.Free;
  end;
end;

begin
  try
    Main;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
    end;
  end;
  Writeln;
  Writeln('Press ENTER to continue...');
  ReadLn;
end.
