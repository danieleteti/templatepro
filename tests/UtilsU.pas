unit UtilsU;

interface

uses
  System.Generics.Collections, Data.DB;

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

function GetItems(const WithFalsyValues: Boolean = False): TObjectList<TDataItem>;
function GetCustomersDataset: TDataSet;
function GetPeopleDataset: TDataSet;
function GetSingleCustomerDataset: TDataSet;
function GetEmptyDataset: TDataSet;

implementation

uses
  FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Comp.DataSet, FireDAC.Comp.Client;

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


function GetPeopleDataset: TDataSet;
var
  lMT: TFDMemTable;
begin
  lMT := TFDMemTable.Create(nil);
  try
    lMT.FieldDefs.Clear;
    lMT.FieldDefs.Add('first_name', ftString, 20);
    lMT.FieldDefs.Add('last_name', ftString, 20);
    lMT.Active := True;
    lMT.AppendRecord(['Daniele', 'Teti']);
    lMT.AppendRecord(['Peter', 'Parker']);
    lMT.AppendRecord(['Bruce', 'Banner']);
    lMT.AppendRecord(['Scott', 'Summers']);
    lMT.AppendRecord(['Sue', 'Storm']);
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

end.
