unit UtilsU;

interface

uses
  System.Generics.Collections, Data.DB, System.Rtti, TemplatePro;

type
  TDataItem = class
  private
    fProp2: string;
    fProp3: string;
    fProp1: string;
    fPropInt: Integer;
  public
    constructor Create(const Value1, Value2, Value3: string; const IntValue: Integer);
    property Prop1: string read fProp1 write fProp1;
    property Prop2: string read fProp2 write fProp2;
    property Prop3: string read fProp3 write fProp3;
    property PropInt: Integer read fPropInt write fPropInt;
  end;

  TSimpleNested3 = class
  private
    fValueNested3: String;
  public
    constructor Create(ValueNested3: String);
    property ValueNested3: String read fValueNested3;
  end;

  TSimpleNested2 = class
  private
    fValueNested2: String;
    fSimpleNested3: TSimpleNested3;
  public
    constructor Create(ValueNested2: String);
    property SimpleNested3: TSimpleNested3 read fSimpleNested3;
    property ValueNested2: String read fValueNested2;
  end;

  TSimpleNested1 = class
  private
    fValueNested1: String;
    fSimpleNested2: TSimpleNested2;
  public
    constructor Create(ValueNested1: String);
    property SimpleNested2: TSimpleNested2 read fSimpleNested2;
    property ValueNested1: String read fValueNested1 write fValueNested1;
  end;

  TSimpleDataItem = class
  private
    FValue1: String;
  public
    constructor Create(Value1: String);
    property Value1: String read FValue1;
  end;




  {A class with its simple properties and then a list with is a list of another class instances}
  TDataItemWithChild = class
  private
    fPropStr: string;
    fPropInt: Integer;
    fDataItemList: TObjectList<TSimpleDataItem>;
  public
    constructor Create(const Str: String; const Int: Integer);
    destructor Destroy; override;
    property PropStr: String read fPropStr;
    property PropInt: Integer read fPropInt;
    property DataItemList: TObjectList<TSimpleDataItem> read FDataItemList;
  end;

  TDataItemWithChildList = class(TObjectList<TDataItemWithChild>)
  public
    constructor Create(const Value1, Value2, Value3: string; const IntValue: Integer);
  end;

function GetItems(const WithFalsyValues: Boolean = False): TObjectList<TDataItem>;
function GetCustomersDataset: TDataSet;
function GetTestDataset: TDataSet;
function GetSingleCustomerDataset: TDataSet;
function GetEmptyDataset: TDataSet;

implementation

uses
  FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Comp.DataSet, FireDAC.Comp.Client,
  System.SysUtils, Data.SqlTimSt, System.DateUtils;

function GetCustomersDataset: TDataSet;
var
  lMT: TFDMemTable;
begin
  lMT := TFDMemTable.Create(nil);
  try
    lMT.FieldDefs.Clear;
    lMT.FieldDefs.Add('Code', ftInteger);
    lMT.FieldDefs.Add('Name', ftString, 20);
    lMT.Active := True;
    lMT.AppendRecord([1, 'Ford']);
    lMT.AppendRecord([2, 'Ferrari']);
    lMT.AppendRecord([3, 'Lotus']);
    lMT.AppendRecord([4, 'FCA']);
    lMT.AppendRecord([5, 'Hyundai']);
    lMT.AppendRecord([6, 'De Tomaso']);
    lMT.AppendRecord([7, 'Dodge']);
    lMT.AppendRecord([8, 'Tesla']);
    lMT.AppendRecord([9, 'Kia']);
    lMT.AppendRecord([10, 'Tata']);
    lMT.AppendRecord([11, 'Volkswagen']);
    lMT.AppendRecord([12, 'Audi']);
    lMT.AppendRecord([13, 'Skoda']);
    lMT.First;
    Result := lMT;
  except
    lMT.Free;
    raise;
  end;
end;

function GetSingleCustomerDataset: TDataSet;
var
  lMT: TFDMemTable;
begin
  lMT := TFDMemTable.Create(nil);
  try
    lMT.FieldDefs.Clear;
    lMT.FieldDefs.Add('Code', ftInteger);
    lMT.FieldDefs.Add('Name', ftString, 20);
    lMT.Active := True;
    lMT.AppendRecord([1, 'Ford']);
    lMT.First;
    Result := lMT;
  except
    lMT.Free;
    raise;
  end;
end;

function GetEmptyDataset: TDataSet;
var
  lMT: TFDMemTable;
begin
  lMT := TFDMemTable.Create(nil);
  try
    lMT.FieldDefs.Clear;
    lMT.FieldDefs.Add('Code', ftInteger);
    lMT.FieldDefs.Add('Name', ftString, 20);
    lMT.Active := True;
    Result := lMT;
  except
    lMT.Free;
    raise;
  end;
end;


function GetTestDataset: TDataSet;
var
  lMT: TFDMemTable;
begin
  lMT := TFDMemTable.Create(nil);
  try
    lMT.FieldDefs.Clear;
    lMT.FieldDefs.Add('field_ftString', ftString, 20);
    lMT.FieldDefs.Add('field_ftInteger', ftInteger);
    lMT.FieldDefs.Add('field_ftFloat', ftFloat);
    lMT.FieldDefs.Add('field_ftSingle', ftSingle);
    lMT.FieldDefs.Add('field_ftFMTBcd', ftFMTBcd);
    lMT.FieldDefs.Add('field_ftTimeStamp', ftTimeStamp);
    lMT.Active := True;
    var lBaseDate: TDate := EncodeDate(1979, 11, 4);
    var lTimeStamp := DateTimeToTimeStamp(lBaseDate + 1.1);

    lMT.Append;
    lMT.FieldByName('field_ftString').AsString := 'Daniele Teti';
    lMT.FieldByName('field_ftInteger').AsInteger := 1;
    lMT.FieldByName('field_ftFloat').AsFloat := 123.456;
    lMT.FieldByName('field_ftSingle').AsSingle := 123.456;
    lMT.FieldByName('field_ftFMTBcd').AsBCD := 1234.5678;
    lMT.FieldByName('field_ftTimeStamp').AsSQLTimeStamp := DateTimeToSQLTimeStamp(lBaseDate + OneMinute * 10);
    lMT.Post;

    lMT.Append;
    lMT.FieldByName('field_ftString').AsString := 'Bruce Banner';
    lMT.FieldByName('field_ftInteger').AsInteger := 2;
    lMT.FieldByName('field_ftFloat').AsFloat := 234.567;
    lMT.FieldByName('field_ftSingle').AsSingle := 234.567;
    lMT.FieldByName('field_ftFMTBcd').AsBCD := 2345.5678;
    lMT.FieldByName('field_ftTimeStamp').AsSQLTimeStamp := DateTimeToSQLTimeStamp(lBaseDate + OneMinute * 10);
    lMT.Post;

    lMT.First;
    Result := lMT;
  except
    lMT.Free;
    raise;
  end;
end;


function GetItems(const WithFalsyValues: Boolean): TObjectList<TDataItem>;
begin
  Result := TObjectList<TDataItem>.Create(True);
  if not WithFalsyValues then
  begin
    Result.Add(TDataItem.Create('value1.1', 'value2.1', 'value3.1', 1));
    Result.Add(TDataItem.Create('value1.2', 'value2.2', 'value3.2', 2));
    Result.Add(TDataItem.Create('value1.3', 'value2.3', 'value3.3', 3));
  end
  else
  begin
    Result.Add(TDataItem.Create('true', 'false', 'value3.1', 0));
    Result.Add(TDataItem.Create('false', 'true', 'value3.2', 1));
    Result.Add(TDataItem.Create('1', '0', 'value3.3', 0));
  end;
end;

{ TDataItem }

constructor TDataItem.Create(const Value1, Value2, Value3: string; const IntValue: Integer);
begin
  inherited Create;
  fProp1 := Value1;
  fProp2 := Value2;
  fProp3 := Value3;
  fPropInt := IntValue;
end;

{ TDataItemWithChild }

constructor TDataItemWithChild.Create(const Str: String; const Int: Integer);
begin
  inherited Create;
  fPropStr := Str;
  fPropInt := Int;
  FDataItemList := TObjectList<TSimpleDataItem>.Create(True);
  for var I := 0 to 2 do
  begin
    FDataItemList.Add(TSimpleDataItem.Create('SimpleDataItem' + I.ToString));
  end;
end;

destructor TDataItemWithChild.Destroy;
begin
  FDataItemList.Free;
  inherited;
end;

{ TDataItemsWithChild }

constructor TDataItemWithChildList.Create(const Value1, Value2, Value3: string; const IntValue: Integer);
begin
  inherited Create(True);
  for var I := 0 to 2 do
  begin
    Add(TDataItemWithChild.Create('Str' + I.ToString, I));
  end;
end;

{ TSimpleDataItem }

constructor TSimpleDataItem.Create(Value1: String);
begin
  inherited Create;
  FValue1 := Value1;
end;

{ TSimpleNested2 }

constructor TSimpleNested2.Create(ValueNested2: String);
begin
  inherited Create;
  fValueNested2 := ValueNested2;
  fSimpleNested3 := TSimpleNested3.Create(ValueNested2 + '.3');
end;

{ TSimpleNested1 }

constructor TSimpleNested1.Create(ValueNested1: String);
begin
  inherited Create;
  fValueNested1 := ValueNested1 + '.1';
  fSimpleNested2 := TSimpleNested2.Create(fValueNested1 + '.2');
end;

{ TSimpleNested3 }

constructor TSimpleNested3.Create(ValueNested3: String);
begin
  inherited Create;
  fValueNested3 := ValueNested3;
end;

end.
