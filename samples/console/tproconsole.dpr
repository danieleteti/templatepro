program tproconsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  System.Rtti,
  JsonDataObjects,
  TemplatePro in '..\..\TemplatePro.pas';

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

function AddSquareBrackets(const aValue: TValue; const aParameters: TArray<TFilterParameter>): TValue;
begin
  Result := '[' + aValue.AsString + ']';
end;

function Sum(const aValue: TValue; const aParameters: TArray<TFilterParameter>): TValue;
var
  lParCount: Integer;
  lSumResult: Integer;
  I: Integer;
begin
  if not aValue.IsEmpty then
  begin
    raise ETProRenderException.Create('"Sum" cannot be used as filter because is a function');
  end;
  lParCount := Length(aParameters);
  lSumResult := 0;
  for I := 0 to lParCount - 1 do
  begin
    if aParameters[I].ParType <> fptInteger then
    begin
      raise ETProRenderException.Create('"Sum" allows only integer parameters');
    end;
    lSumResult := lSumResult + aParameters[I].ParIntValue;
  end;
  Result := lSumResult;
end;

procedure Main;
begin
  var lCompiler := TTProCompiler.Create();
  try
    var lTemplate := '''
                     Simple variable:
                     {{:variable1}}

                     Using loops:
                     {{for person in people}}
                       - {{:person.id}}) {{:person.first_name}}, {{:person.last_name}}
                     {{endfor}}

                     Using if statement:
                     {{if people}}People dataset contains records{{endif}}
                     {{if !people}}People dataset doesn''t contain records{{endif}}


                     Using filters:
                     uppercase      : {{:variable1|uppercase}}
                     lowercase      : {{:variable1|lowercase}}
                     lpad           : {{:variable1|lpad,20,"*"}}
                     rpad           : {{:variable1|rpad,20,"*"}}
                     capitalize     : {{:variable1|capitalize}}
                     trunc          : {{:variable1|trunc,5}}

                     Using custom filters:
                     brackets : {{:variable1|brackets}}

                     Using custom functions:
                     sum : {{:|sum,1,2,3}}

                     Using json objects:
                     {{:jobj.foo}}
                     {{:jobj.bar}}
                     {{""|lpad,40,"_"}}
                     {{for item in jobj.myarray}}
                       - {{:item.first_name}} {{:item.last_name}}
                         {{:item.company.name}} - {{:item.company.country}}{{if item.company.country|eq,"ITALY"}} <--- {{endif}}
                     {{endfor}}
                     ''';

    var lCompiledTemplate := lCompiler.Compile(lTemplate);
    var lPeopleDataset := GetPeopleDataset;
    try
      var lJObj := GetJSON;
      try
        lCompiledTemplate.AddFilter('brackets', AddSquareBrackets);
        lCompiledTemplate.AddFilter('sum', Sum);
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
