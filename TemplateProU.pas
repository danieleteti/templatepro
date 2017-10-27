//
// Copyright (c) 2017 Daniele Teti
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

unit TemplateProU;

interface

uses
  System.Generics.Collections,
  Classes,
  SysUtils,
  Data.DB,
  System.RTTI;

type
  EParserException = class(Exception)

  end;

  ITPDataSourceAdapter = interface
    ['{9A0E5797-A8D2-413F-A8B0-5D6E67DD1701}']
    function CurrentIndex: Int64;
    procedure Reset;
    function GetMemberValue(const aMemberName: string): string;
    procedure Next;
    function Eof: Boolean;
  end;

  TTPLoopControl = record
    Identifier: string;
    class function Create(aIdentifier: string): TTPLoopControl; static;
  end;

  TTPDatasetDictionary = class(TDictionary<string, TDataSet>)
  end;

  TTPObjectListDictionary = class(TObjectDictionary<string, TObjectList<TObject>>)
  end;

  TTPDatasetAdapter = class(TInterfacedObject, ITPDataSourceAdapter)
  private
    fDataSet: TDataSet;
  public
    constructor Create(const aDataSet: TDataSet);
  protected
    function CurrentIndex: Int64;
    procedure Reset;
    function GetMemberValue(const aMemberName: string): string;
    procedure Next;
    function Eof: Boolean;
  end;

  TTPObjectListAdapter = class(TInterfacedObject, ITPDataSourceAdapter)
  private
  class var
    CTX: TRttiContext;
    fObjectList: TObjectList<TObject>;
    fIndex: Integer;
  public
    constructor Create(const aObjectList: TObjectList<TObject>);
    class constructor Create;
    class destructor Destroy;
  protected
    function Current: TObject;
    function CurrentIndex: Int64;
    procedure Reset;
    function GetMemberValue(const aMemberName: string): string;
    procedure Next;
    function Eof: Boolean;
  end;

  TTemplateProEngine = class
  strict private
    FOutput: string;
    FVariables: TDictionary<string, string>;
    function MatchStartTag: Boolean;
    function MatchEndTag: Boolean;
    function MatchIdentifier(var aIdentifier: string): Boolean;
    function MatchValue(var aValue: string): Boolean;
    function MatchReset(var aDataSet: string): Boolean;
    function MatchField(var aDataSet: string; var aFieldName: string): Boolean;
    function MatchSymbol(const Symbol: string): Boolean;
  private
    fDataSources: TDictionary<string, ITPDataSourceAdapter>;
    FInputString: string;
    FCharIndex: Int64;
    FCurrentLine: Integer;
    FCurrentColumn: Integer;
    FLoopStack: TStack<Integer>;
    FLoopIdentStack: TStack<TTPLoopControl>;
    fCurrentDataSource: ITPDataSourceAdapter;
    FOutputStreamWriter: TStreamWriter;
    procedure Error(const Message: string);
    function ExecuteFunction(AFunctionName: string; aParameters: TArray<string>; AValue: string): string;
    function SetDataSourceByName(const Name: string): Boolean;
    function GetFieldText(const FieldName: string): string;
    function ExecuteFieldFunction(AFunctionName: string;
      aParameters: TArray<string>;
      aValue: TValue): string;
    procedure CheckParNumber(const HowManyPars: Integer;
      const aParameters: TArray<string>); overload;
    procedure CheckParNumber(const MinParNumber, MaxParNumber: Integer;
      const aParameters: TArray<string>); overload;
    procedure AppendOutput(const AValue: string);
    procedure LoadDataSources(const aObjectDictionary: TTPObjectListDictionary; const aDatasetDictionary: TTPDatasetDictionary);
  public
    procedure Execute(const InputString: string; const ObjectDictionary: TTPObjectListDictionary; const DatasetDictionary: TTPDatasetDictionary; aStream: TStream);
    constructor Create;
    destructor Destroy; override;
    procedure SetVar(const AName: string; AValue: string);
    function GetVar(const AName: string): string;
    procedure ClearVariables;
  end;

implementation


uses
  System.StrUtils;

const
  IdenfierAllowedFirstChars = ['a' .. 'z', 'A' .. 'Z', '_'];
  IdenfierAllowedChars = IdenfierAllowedFirstChars + ['0' .. '9'];
  ValueAllowedChars = IdenfierAllowedChars + [' ', '-', '+', '*', '.', '@', '/', '\']; // maybe a lot others
  START_TAG_1 = '{';
  END_TAG_1 = '}';

  { TParser }

procedure TTemplateProEngine.AppendOutput(const AValue: string);
begin
  FOutputStreamWriter.Write(AValue);
end;

procedure TTemplateProEngine.CheckParNumber(const MinParNumber,
  MaxParNumber: Integer; const aParameters: TArray<string>);
var
  lParNumber: Integer;
begin
  lParNumber := Length(aParameters);
  if (lParNumber < MinParNumber) or (lParNumber > MaxParNumber) then
  begin
    if MinParNumber = MaxParNumber then
      Error(Format('Expected %d parameters, got %d', [MinParNumber, lParNumber]))
    else
      Error(Format('Expected from %d to %d parameters, got %d', [MinPArNumber, MaxParNumber, lParNumber]));
  end;
end;

procedure TTemplateProEngine.ClearVariables;
begin
  FVariables.Clear;
end;

constructor TTemplateProEngine.Create;
begin
  inherited;
  FOutput := '';
  FVariables := TDictionary<string, string>.Create;
  FLoopStack := TStack<Integer>.Create;
  FLoopIdentStack := TStack<TTPLoopControl>.Create;
  fDataSources := TDictionary<string, ITPDataSourceAdapter>.Create;
end;

destructor TTemplateProEngine.Destroy;
begin
  fDataSources.Free;
  FLoopIdentStack.Free;
  FLoopStack.Free;
  FVariables.Free;
  FOutputStreamWriter.Free;
  inherited;
end;

function TTemplateProEngine.SetDataSourceByName(const Name: string): Boolean;
var
  ds: TPair<string, ITPDataSourceAdapter>;
begin
  Result := False;
  for ds in fDataSources do
  begin
    if SameText(ds.Key, name) then
    begin
      fCurrentDataSource := ds.Value;
      Result := True;
      Break;
    end;
  end;

  // for ds in FDatasets do
  // begin
  // if SameText(ds.Name, name) then
  // begin
  // FCurrentDataset := ds;
  // Result := True;
  // Break;
  // end;
  // end;
end;

function TTemplateProEngine.GetFieldText(const FieldName: string): string;
var
  lField: TField;
begin
  if not Assigned(fCurrentDataSource) then
    Error('Current datasource not set');
  Result := fcurrentDataSource.GetMemberValue(FieldName);
end;

function TTemplateProEngine.GetVar(const AName: string): string;
begin
  if not FVariables.TryGetValue(AName, Result) then
    Result := '';
end;

procedure TTemplateProEngine.LoadDataSources(
  const aObjectDictionary: TTPObjectListDictionary;
  const aDatasetDictionary: TTPDatasetDictionary);
var
  lDatasetPair: TPair<string, TDataset>;
  lObjectPair: TPair<string, TObjectList<TObject>>;
begin
  fDataSources.Clear;

  for lDatasetPair in aDatasetDictionary do
  begin
    fDataSources.Add(lDatasetPair.Key, TTPDatasetAdapter.Create(lDatasetPair.Value));
  end;

  for lObjectPair in aObjectDictionary do
  begin
    fDataSources.Add(lObjectPair.Key, TTPObjectListAdapter.Create(lObjectPair.Value));
  end;
end;

function TTemplateProEngine.MatchEndTag: Boolean;
begin
  Result := FInputString.Chars[FCharIndex] = END_TAG_1;
  if Result then
    Inc(FCharIndex, 1);
end;

function TTemplateProEngine.MatchField(var aDataSet: string; var aFieldName: string): Boolean;
begin
  Result := False;
  aFieldName := '';
  if not MatchSymbol(':') then
    Exit;
  if not MatchIdentifier(aDataSet) then
    Error('Expected dataset name');
  if not MatchSymbol('.') then
    Error('Expected "."');
  if not MatchIdentifier(aFieldName) then
    Error('Expected field name');
  Result := True;
end;

function TTemplateProEngine.MatchIdentifier(var aIdentifier: string): Boolean;
begin
  aIdentifier := '';
  Result := False;
  if CharInSet(FInputString.Chars[FCharIndex], IdenfierAllowedFirstChars) then
  begin
    while CharInSet(FInputString.Chars[FCharIndex], IdenfierAllowedChars) do
    begin
      aIdentifier := aIdentifier + FInputString.Chars[FCharIndex];
      Inc(FCharIndex);
    end;
    Result := True;
  end
end;

function TTemplateProEngine.MatchReset(var aDataSet: string): Boolean;
begin
  if not MatchSymbol('reset') then
    Exit(False);
  Result := MatchSymbol('(') and MatchIdentifier(aDataSet) and MatchSymbol(')');
end;

function TTemplateProEngine.MatchStartTag: Boolean;
begin
  Result := FInputString.Chars[FCharIndex] = START_TAG_1;
  if Result then
    Inc(FCharIndex, 1);
end;

function TTemplateProEngine.MatchSymbol(const Symbol: string): Boolean;
var
  lSymbolIndex: Integer;
  lSavedCharIndex: Int64;
begin
  if Symbol.IsEmpty then
    Exit(True);
  lSavedCharIndex := FCharIndex;
  lSymbolIndex := 0;
  // lChar := FInputString.Chars[FCharIndex];
  while FInputString.Chars[FCharIndex] = Symbol.Chars[lSymbolIndex] do
  begin
    Inc(FCharIndex);
    Inc(lSymbolIndex);
    // lChar := FInputString.Chars[FCharIndex]
  end;
  Result := (lSymbolIndex > 0) and (lSymbolIndex = Length(Symbol));
  if not Result then
    FCharIndex := lSavedCharIndex;
end;

function TTemplateProEngine.MatchValue(var aValue: string): Boolean;
begin
  aValue := '';
  while CharInSet(FInputString.Chars[FCharIndex], ValueAllowedChars) do
  begin
    aValue := aValue + FInputString.Chars[FCharIndex];
    Inc(FCharIndex);
  end;
  Result := not aValue.IsEmpty;
end;

procedure TTemplateProEngine.Execute(const InputString: string; const ObjectDictionary: TTPObjectListDictionary; const DatasetDictionary: TTPDatasetDictionary; aStream: TStream);
var
  lChar: Char;
  lVarName: string;
  lFuncName: string;
  lIdentifier: string;
  lDataSet: string;
  lFieldName: string;
  lIgnoreOutput: Boolean;
  lFuncParams: TArray<string>;
  lDataSourceName: string;
  function GetFunctionParameters: TArray<string>;
  var
    lFuncPar: string;
  begin
    Result := [];
    while MatchSymbol(':') do
    begin
      lFuncPar := '';
      if not MatchValue(lFuncPar) then
        Error('Expected function parameter');
      Result := Result + [lFuncPar];
    end;
  end;

begin
  lIgnoreOutput := False;
  FreeAndNil(FOutputStreamWriter);
  FOutputStreamWriter := TStreamWriter.Create(aStream);
  LoadDataSources(ObjectDictionary, DataSetDictionary);
  FLoopStack.Clear;
  FLoopIdentStack.Clear;
  FCharIndex := 0;
  FCurrentLine := 1;
  FCurrentColumn := 0;
  FInputString := InputString;
  while FCharIndex < InputString.Length do
  begin
    lChar := InputString.Chars[FCharIndex];
    if lChar = #13 then
    begin
      Inc(FCurrentLine);
      FCurrentColumn := 1;
    end
    else
    begin
      Inc(FCurrentColumn);
    end;

    // starttag
    if MatchStartTag then
    begin
      // loop
      if not lIgnoreOutput and MatchSymbol('loop') then
      begin
        if not MatchSymbol('(') then
          Error('Expected "("');
        if not MatchIdentifier(lIdentifier) then
          Error('Expected identifier after "loop("');
        if not MatchSymbol(')') then
          Error('Expected ")" after "' + lIdentifier + '"');
        if not MatchEndTag then
          Error('Expected closing tag for "loop(' + lIdentifier + ')"');
        if not SetDataSourceByName(lIdentifier) then
          Error('Unknown dataset: ' + lIdentifier);
        FLoopStack.Push(FCharIndex);
        FLoopIdentStack.Push(TTPLoopControl.Create(lIdentifier));
        lIgnoreOutput := false; // FCurrentDataset.Eof;
        Continue;
      end;

      // endloop
      if MatchSymbol('endloop') then
      begin
        if not MatchEndTag then
          Error('Expected closing tag');
        lIdentifier := FLoopIdentStack.Peek.Identifier;
        if not SetDataSourceByName(lIdentifier) then
          Error('Invalid datasource name: ' + lIdentifier);

        FCurrentDataSource.Next;
        if FCurrentDataSource.Eof then
        begin
          FLoopIdentStack.Pop;
          FLoopStack.Pop;
          lIgnoreOutput := False;
        end
        else
        begin
          FCharIndex := FLoopStack.Peek;
        end;
        Continue;
      end;

      // dataset field
      if not lIgnoreOutput and MatchField(lDataSourceName, lFieldName) then
      begin
        if lFieldName.IsEmpty then
          Error('Invalid field name');
        lFuncName := '';
        if MatchSymbol('|') then
        begin
          if not MatchIdentifier(lFuncName) then
            Error('Invalid function name');
          lFuncParams := GetFunctionParameters;
          if not MatchEndTag then
            Error('Expected end tag');
        end
        else
        begin
          if not MatchEndTag then
            Error('Expected closing tag');
          if not SetDataSourceByName(lDataSourceName) then
            Error('Unknown datasource: ' + lDataSourceName);
        end;
        if lFuncName.IsEmpty then
          AppendOutput(GetFieldText(lFieldName))
        else
          AppendOutput(ExecuteFieldFunction(lFuncName, lFuncParams, GetFieldText(lFieldName)));
      end;

      // reset
      if not lIgnoreOutput and MatchReset(lDataSet) then
      begin
        if not MatchEndTag then
          Error('Expected closing tag');
        SetDataSourceByName(lDataSet);
        fCurrentDataSource.Reset;
        Continue;
      end;

      // identifier
      if not lIgnoreOutput and MatchIdentifier(lVarName) then
      begin
        if lVarName.IsEmpty then
          Error('Invalid variable name');
        lFuncName := '';
        if MatchSymbol('|') then
        begin
          if not MatchIdentifier(lFuncName) then
            Error('Invalid function name');
          lFuncParams := GetFunctionParameters;
          if not MatchEndTag then
            Error('Expected end tag');
          AppendOutput(ExecuteFunction(lFuncName, lFuncParams, GetVar(lVarName)));
        end
        else
        begin
          if not MatchEndTag then
            Error('Expected end tag');
          AppendOutput(GetVar(lVarName));
        end;
      end;
    end
    else
    begin
      // output verbatim
      if not lIgnoreOutput then
        AppendOutput(lChar);
      Inc(FCharIndex);
    end;
  end;
  FOutputStreamWriter.BaseStream.Position := 0;
end;

procedure TTemplateProEngine.SetVar(
  const
  AName: string;
  AValue: string);
begin
  FVariables.AddOrSetValue(AName, AValue);
end;

function CapitalizeString(
  const
  s: string;
  const
  CapitalizeFirst: Boolean): string;
const
  ALLOWEDCHARS = ['a' .. 'z', '_'];
var
  index: Integer;
  bCapitalizeNext: Boolean;
begin
  bCapitalizeNext := CapitalizeFirst;
  Result := lowercase(s);
  if Result <> EmptyStr then
  begin
    for index := 1 to Length(Result) do
    begin
      if bCapitalizeNext then
      begin
        Result[index] := UpCase(Result[index]);
        bCapitalizeNext := False;
      end
      else if not CharInSet(Result[index], ALLOWEDCHARS) then
      begin
        bCapitalizeNext := True;
      end;
    end; // for
  end; // if
end;

procedure TTemplateProEngine.Error(const message: string);
begin
  raise EParserException.CreateFmt('%s - at line %d col %d',
    [message, FCurrentLine, FCurrentColumn]);
end;

procedure TTemplateProEngine.CheckParNumber(const HowManyPars: Integer; const aParameters: TArray<string>);
begin
  CheckParNumber(HowManyPars, HowManyPars, aParameters);
end;

function TTemplateProEngine.ExecuteFunction(AFunctionName: string; aParameters: TArray<string>; AValue: string): string;
begin
  AFunctionName := lowercase(AFunctionName);
  if AFunctionName = 'uppercase' then
  begin
    Exit(UpperCase(AValue));
  end;
  if AFunctionName = 'lowercase' then
  begin
    Exit(lowercase(AValue));
  end;
  if AFunctionName = 'capitalize' then
  begin
    Exit(CapitalizeString(AValue, True));
  end;
  if AFunctionName = 'rpad' then
  begin
    CheckParNumber(1, 2, aParameters);
    if Length(aParameters) = 1 then
      Exit(aValue.PadRight(aParameters[0].ToInteger))
    else
      Exit(aValue.PadRight(aParameters[0].ToInteger, aParameters[1].Chars[0]));
  end;
  if AFunctionName = 'lpad' then
  begin
    if Length(aParameters) = 1 then
      Exit(aValue.PadLeft(aParameters[0].ToInteger))
    else
      Exit(aValue.PadLeft(aParameters[0].ToInteger, aParameters[1].Chars[0]));
  end;

  raise EParserException.CreateFmt('Unknown function [%s]', [AFunctionName]);
end;

function TTemplateProEngine.ExecuteFieldFunction(AFunctionName: string;
  aParameters: TArray<string>;
  aValue: TValue): string;
var
  lDateValue: TDate;
  lDateTimeValue: TDateTime;
begin
  AFunctionName := lowercase(AFunctionName);
  if AFunctionName = 'datetostr' then
  begin
    if not aValue.TryAsType<TDate>(lDateValue) then
      raise Exception.Create('Invalid Date');
    Exit(DateToStr(lDateValue));
  end;
  if AFunctionName = 'datetimetostr' then
  begin
    if not aValue.TryAsType<TDateTime>(lDateTimeValue) then
      raise Exception.Create('Invalid DateTime');
    Exit(DateTimeToStr(lDateTimeValue));
  end;
  if AFunctionName = 'formatdatetime' then
  begin
    CheckParNumber(1, aParameters);
    if not aValue.TryAsType<TDateTime>(lDateTimeValue) then
      raise Exception.Create('Invalid DateTime');
    Exit(FormatDateTime(aParameters[0], lDateTimeValue));
  end;

  Result := ExecuteFunction(AFunctionName, aParameters, aValue.AsString);
end;

class
  function TTPLoopControl.Create(aIdentifier: string): TTPLoopControl;
begin
  Result.Identifier := aIdentifier;
end;

{ TTPDatasetAdapter }

constructor TTPDatasetAdapter.Create(const aDataSet: TDataSet);
begin
  inherited Create;
  fDataSet := aDataSet;
end;

function TTPDatasetAdapter.CurrentIndex: Int64;
begin
  fDataSet.RecNo;
end;

function TTPDatasetAdapter.Eof: Boolean;
begin
  Result := fDataSet.Eof;
end;

function TTPDatasetAdapter.GetMemberValue(const aMemberName: string): string;
begin
  Result := fDataSet.FieldByName(aMemberName).AsWideString;
end;

procedure TTPDatasetAdapter.Next;
begin
  fDataSet.Next;
end;

procedure TTPDatasetAdapter.Reset;
begin
  fDataSet.First;
end;

{ TTPObjectListAdapter }

constructor TTPObjectListAdapter.Create(
  const aObjectList: TObjectList<TObject>);
begin
  inherited Create;
  fObjectList := aObjectList;
  if fObjectList.Count > 0 then
    fIndex := 0
  else
    fIndex := -1;
end;

class constructor TTPObjectListAdapter.Create;
begin
  TTPObjectListAdapter.CTX := TRttiContext.Create;
end;

function TTPObjectListAdapter.Current: TObject;
begin
  if fIndex <> -1 then
    Result := fObjectList[fIndex]
  else
    raise Exception.Create('Empty DataSource');
end;

function TTPObjectListAdapter.CurrentIndex: Int64;
begin
  Result := fIndex;
end;

class destructor TTPObjectListAdapter.Destroy;
begin
  TTPObjectListAdapter.CTX.Free;
end;

function TTPObjectListAdapter.Eof: Boolean;
begin
  Result := fIndex = fObjectList.Count - 1;
end;

function TTPObjectListAdapter.GetMemberValue(const aMemberName: string): string;
var
  lRttiType: TRttiType;
  lRttiProp: TRttiProperty;
  lCurrentObj: TObject;
begin
  lCurrentObj := Current;
  lRttiType := CTX.GetType(lCurrentObj.ClassInfo);
  lRttiProp := lRttiType.GetProperty(aMemberName);
  Result := lRttiProp.GetValue(lCurrentObj).AsString;
end;

procedure TTPObjectListAdapter.Next;
begin
  if Eof then
    raise Exception.Create('DataSource is already at EOF');
  Inc(fIndex);
end;

procedure TTPObjectListAdapter.Reset;
begin
  if fObjectList.Count > 0 then
    fIndex := 0
  else
    fIndex := -1;
end;

end.
