unit TemplatePro.Utils;

{$LEGACYIFEND ON}

interface

uses
  System.Rtti,
  System.Generics.Collections,
  System.SysUtils,
  System.TypInfo,
  System.Math;

type
  EMVCDuckTypingException = class(Exception);

  ITProWrappedList = interface
    ['{C1963FBF-1E42-4E2A-A17A-27F3945F13ED}']
    function GetItem(const AIndex: Integer): TObject;
    procedure Add(const AObject: TObject);
    function Count: Integer;
    procedure Clear;
    function IsWrappedList: Boolean; overload;
    function ItemIsObject(const AIndex: Integer; out AValue: TValue): Boolean;
  end;

  TTProDuckTypedList = class(TInterfacedObject, ITProWrappedList)
  private
    FObjectAsDuck: TObject;
    FContext: TRttiContext;
    FObjType: TRttiType;
    FAddMethod: TRttiMethod;
    FClearMethod: TRttiMethod;
    FCountProperty: TRttiProperty;
    FGetItemMethod: TRttiMethod;
    FGetCountMethod: TRttiMethod;
  protected
    procedure Add(const AObject: TObject);
    procedure Clear;
    function ItemIsObject(const AIndex: Integer; out AValue: TValue): Boolean;
  public
    constructor Create(const AObjectAsDuck: TObject); overload;
    constructor Create(const AInterfaceAsDuck: IInterface); overload;
    destructor Destroy; override;

    function IsWrappedList: Boolean; overload;
    function Count: Integer;
    procedure GetItemAsTValue(const AIndex: Integer; out AValue: TValue);
    function GetItem(const AIndex: Integer): TObject;
    class function CanBeWrappedAsList(const AObjectAsDuck: TObject): Boolean; overload; static;
    class function CanBeWrappedAsList(const AObjectAsDuck: TObject; out AMVCList: ITProWrappedList): Boolean; overload; static;
    class function CanBeWrappedAsList(const AInterfaceAsDuck: IInterface): Boolean; overload; static;
    class function Wrap(const AObjectAsDuck: TObject): ITProWrappedList; static;
  end;

  TTProRTTIUtils = class sealed
  private
    class var GlContext: TRttiContext;
    class constructor Create;
    class destructor Destroy;
  public
    class function GetProperty(AObject: TObject; const APropertyName: string): TValue;
  end;

function WrapAsList(const AObject: TObject): ITProWrappedList;

implementation

function WrapAsList(const AObject: TObject): ITProWrappedList;
begin
  Result := TTProDuckTypedList.Wrap(AObject);
end;


class function TTProRTTIUtils.GetProperty(AObject: TObject; const APropertyName: string): TValue;
var
  Prop: TRttiProperty;
  ARttiType: TRttiType;
begin
  ARttiType := GlContext.GetType(AObject.ClassType);
  if not Assigned(ARttiType) then
    raise Exception.CreateFmt('Cannot get RTTI for type [%s]', [ARttiType.ToString]);
  Prop := ARttiType.GetProperty(APropertyName);
  if not Assigned(Prop) then
    raise Exception.CreateFmt('Cannot get RTTI for property [%s.%s]', [ARttiType.ToString, APropertyName]);
  if Prop.IsReadable then
    Result := Prop.GetValue(AObject)
  else
    raise Exception.CreateFmt('Property is not readable [%s.%s]', [ARttiType.ToString, APropertyName]);
end;

class constructor TTProRTTIUtils.Create;
begin
  GlContext := TRttiContext.Create;
end;


class destructor TTProRTTIUtils.Destroy;
begin
  GlContext.Free;
end;


{ TDuckTypedList }

procedure TTProDuckTypedList.Add(const AObject: TObject);
begin
  if not Assigned(FAddMethod) then
    raise EMVCDuckTypingException.Create('Cannot find method "Add" in the Duck Object.');
  FAddMethod.Invoke(FObjectAsDuck, [AObject]);
end;

class function TTProDuckTypedList.CanBeWrappedAsList(const AInterfaceAsDuck: IInterface): Boolean;
begin
  Result := CanBeWrappedAsList(TObject(AInterfaceAsDuck));
end;

class function TTProDuckTypedList.CanBeWrappedAsList(const AObjectAsDuck: TObject): Boolean;
var
  lList: ITProWrappedList;
begin
  Result := CanBeWrappedAsList(AObjectAsDuck, lList);
end;

class function TTProDuckTypedList.CanBeWrappedAsList(const AObjectAsDuck: TObject; out AMVCList: ITProWrappedList): Boolean;
var
  List: ITProWrappedList;
begin
  List := TTProDuckTypedList.Create(AObjectAsDuck);
  Result := List.IsWrappedList;
  if Result then
    AMVCList := List;
end;

procedure TTProDuckTypedList.Clear;
begin
  if not Assigned(FClearMethod) then
    raise EMVCDuckTypingException.Create('Cannot find method "Clear" in the Duck Object.');
  FClearMethod.Invoke(FObjectAsDuck, []);
end;

function TTProDuckTypedList.Count: Integer;
begin
  Result := 0;

  if (not Assigned(FGetCountMethod)) and (not Assigned(FCountProperty)) then
    raise EMVCDuckTypingException.Create('Cannot find property/method "Count" in the Duck Object.');

  if Assigned(FCountProperty) then
    Result := FCountProperty.GetValue(FObjectAsDuck).AsInteger
  else if Assigned(FGetCountMethod) then
    Result := FGetCountMethod.Invoke(FObjectAsDuck, []).AsInteger;
end;

constructor TTProDuckTypedList.Create(const AInterfaceAsDuck: IInterface);
begin
  Create(TObject(AInterfaceAsDuck));
end;

constructor TTProDuckTypedList.Create(const AObjectAsDuck: TObject);
begin
  inherited Create;
  FObjectAsDuck := AObjectAsDuck;

  if not Assigned(FObjectAsDuck) then
    raise EMVCDuckTypingException.Create('Duck Object can not be null.');

  FContext := TRttiContext.Create;
  FObjType := FContext.GetType(FObjectAsDuck.ClassInfo);

  FAddMethod := nil;
  FClearMethod := nil;
  FGetItemMethod := nil;
  FGetCountMethod := nil;
  FCountProperty := nil;

  if IsWrappedList then
  begin
    FAddMethod := FObjType.GetMethod('Add');
    FClearMethod := FObjType.GetMethod('Clear');

{$IF CompilerVersion >= 23}
    if Assigned(FObjType.GetIndexedProperty('Items')) then
      FGetItemMethod := FObjType.GetIndexedProperty('Items').ReadMethod;

{$IFEND}
    if not Assigned(FGetItemMethod) then
      FGetItemMethod := FObjType.GetMethod('GetItem');

    if not Assigned(FGetItemMethod) then
      FGetItemMethod := FObjType.GetMethod('GetElement');

    FGetCountMethod := nil;
    FCountProperty := FObjType.GetProperty('Count');
    if not Assigned(FCountProperty) then
      FGetCountMethod := FObjType.GetMethod('Count');
  end;
end;

destructor TTProDuckTypedList.Destroy;
begin
  FContext.Free;
  inherited Destroy;
end;

function TTProDuckTypedList.GetItem(const AIndex: Integer): TObject;
var
  lValue: TValue;
begin
  if not Assigned(FGetItemMethod) then
    raise EMVCDuckTypingException.Create
      ('Cannot find method Indexed property "Items" or method "GetItem" or method "GetElement" in the Duck Object.');
  GetItemAsTValue(AIndex, lValue);

  if lValue.Kind = tkInterface then
  begin
    Exit(TObject(lValue.AsInterface));
  end;
  if lValue.Kind = tkClass then
  begin
    Exit(lValue.AsObject);
  end;
  raise EMVCDuckTypingException.Create('Items in list can be only objects or interfaces');
end;

procedure TTProDuckTypedList.GetItemAsTValue(const AIndex: Integer;
  out AValue: TValue);
begin
  AValue := FGetItemMethod.Invoke(FObjectAsDuck, [AIndex]);
end;

function TTProDuckTypedList.IsWrappedList: Boolean;
var
  ObjectType: TRttiType;
begin
  ObjectType := FContext.GetType(FObjectAsDuck.ClassInfo);

  Result := (ObjectType.GetMethod('Add') <> nil) and (ObjectType.GetMethod('Clear') <> nil)

{$IF CompilerVersion >= 23}
    and (ObjectType.GetIndexedProperty('Items') <> nil) and (ObjectType.GetIndexedProperty('Items').ReadMethod <> nil)

{$IFEND}
    and (ObjectType.GetMethod('GetItem') <> nil) or (ObjectType.GetMethod('GetElement') <> nil) and
    (ObjectType.GetProperty('Count') <> nil);
end;

function TTProDuckTypedList.ItemIsObject(const AIndex: Integer; out AValue: TValue): Boolean;
begin
  GetItemAsTValue(AIndex, AValue);
  Result := AValue.IsObject;
end;

class function TTProDuckTypedList.Wrap(const AObjectAsDuck: TObject): ITProWrappedList;
var
  List: ITProWrappedList;
begin
  if AObjectAsDuck is TTProDuckTypedList then
    Exit(TTProDuckTypedList(AObjectAsDuck));
  Result := nil;
  List := TTProDuckTypedList.Create(AObjectAsDuck);
  if List.IsWrappedList then
    Result := List;
end;

end.
