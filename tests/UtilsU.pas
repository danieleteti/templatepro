unit UtilsU;

interface

uses
  System.Generics.Collections;

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

function GetItems: TObjectList<TDataItem>;

implementation

function GetItems: TObjectList<TDataItem>;
begin
  Result := TObjectList<TDataItem>.Create(True);
  Result.Add(TDataItem.Create('value1.1', 'value2.1', 'value3.1', 1));
  Result.Add(TDataItem.Create('value1.2', 'value2.2', 'value3.2', 2));
  Result.Add(TDataItem.Create('value1.3', 'value2.3', 'value3.3', 3));
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
