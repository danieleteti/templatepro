// ***************************************************************************
//
// Copyright (c) 2016-2024 Daniele Teti
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
  ETProException = class(Exception)

  end;

  EParserException = class(ETProException)

  end;

  ERenderException = class(ETProException)

  end;


  ITPDataSourceAdapter = interface
    ['{9A0E5797-A8D2-413F-A8B0-5D6E67DD1701}']
    function CurrentIndex: Int64;
    procedure Reset;
    function GetMemberValue(const aMemberName: string): string;
    procedure Next;
    function Eof: Boolean;
  end;

  TTokenType = (ttContent, ttLoop, ttEndLoop, ttIfThen, ttEndIf, ttStartTag, ttEndTag, ttDataField, ttValue, ttReset, ttField, ttLineBreak);

  const
    TOKEN_TYPE_DESCR: array [Low(TTokenType)..High(TTokenType)] of string =
      ('ttContent', 'ttLoop', 'ttEndLoop', 'ttIfThen', 'ttEndIf', 'ttStartTag', 'ttEndTag', 'ttDataField', 'ttValue', 'ttReset', 'ttField', 'ttLineBreak');
  type
    TToken = packed record
      TokenType: TTokenType;
      Value: String;
      Ref: Integer;
      class function Create(TokType: TTokenType; Value: String; Ref: Integer = -1): TToken; static;
      function TokenTypeAsString: String;
    end;

  TTokenWalkProc = reference to procedure(const Index: Integer; const Token: TToken);
  ITemplateProCompiledTemplate = interface
    ['{39479EBA-3558-4293-8C5F-B36C0F849F55}']
    function Render {(
      const aObjectNames: array of string;
      const aObjects: array of TObjectList<TObject>;
      const aDataSetNames: array of string;
      const aDataSets: array of TDataSet)}: String;
    procedure SetData(const Name: String; Value: TValue); overload;
    procedure SetData(const Name: String; Value: TObject); overload;
    procedure ForEachToken(const TokenProc: TTokenWalkProc);
  end;

//  TTPDatasetDictionary = class(TDictionary<string, TDataSet>);
//
//  TTPObjectListDictionary = class(TObjectDictionary < string, TObjectList < TObject >> );
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


  TTemplateFunction = reference to function(aParameters: TArray<string>; const aValue: string): string;


  TTemplateProCompiledTemplate = class(TInterfacedObject, ITemplateProCompiledTemplate)
  private
    fTokens: TList<TToken>;
    fDataSources: TDictionary<string, ITPDataSourceAdapter>;
    fVariables: TDictionary<string, TValue>;
    constructor Create(Tokens: TList<TToken>);
    procedure Error(const aMessage: String);
    function InternalRender: String;
    function GetFieldText(const aFieldName: string): string;
    function GetVarAsString(const aName: string): string;
    function EvaluateIfExpression(const aIdentifier: string): Boolean;
    function GetDataSource: TDictionary<string, ITPDataSourceAdapter>;
    function GetVariables: TDictionary<string, TValue>;
    procedure ClearVariables;
    procedure SetVar(const aName: string; aValue: string);
  protected
    function Render: String;
    procedure ForEachToken(const TokenProc: TTokenWalkProc);
    procedure SetData(const Name: String; Value: TObject); overload;
    procedure SetData(const Name: String; Value: TValue); overload;
    procedure SetData(const Name: String; Value: TDataSet); overload;
  end;

  TTemplateProEngine = class
  strict private
    fOutput: string;
    fVariables: TDictionary<string, string>;
    function MatchStartTag: Boolean;
    function MatchEndTag: Boolean;
    function MatchIdentifier(var aIdentifier: string): Boolean;
    function MatchValue(var aValue: string): Boolean;
    function MatchReset(var aDataSet: string): Boolean;
    function MatchField(var aDataSet: string; var aFieldName: string): Boolean;
    function MatchSymbol(const aSymbol: string): Boolean;
  private
    fInputString: string;
    fCharIndex: Int64;
    fCurrentLine: Integer;
    fEncoding: TEncoding;
    fTemplateFunctions: TDictionary<string, TTemplateFunction>;
    fInThen: Boolean;
    fInElse: Boolean;

    procedure Error(const aMessage: string);

    function ExecuteFunction(aFunctionName: string; aParameters: TArray<string>; aValue: string): string;

    function ExecuteFieldFunction(aFunctionName: string; aParameters: TArray<string>; aValue: TValue): string;

    procedure CheckParNumber(const aHowManyPars: Integer; const aParameters: TArray<string>); overload;
    procedure CheckParNumber(const aMinParNumber, aMaxParNumber: Integer; const aParameters: TArray<string>); overload;
  public
    function Compile(const aTemplateString: string): ITemplateProCompiledTemplate; overload;
    constructor Create(aEncoding: TEncoding = nil);
    destructor Destroy; override;
    procedure AddTemplateFunction(const FunctionName: string; const FunctionImpl: TTemplateFunction);
  end;

function HTMLEntitiesEncode(s: string): string;

implementation

uses
  System.StrUtils;

const
  IdenfierAllowedFirstChars = ['a' .. 'z', 'A' .. 'Z', '_'];
  IdenfierAllowedChars = IdenfierAllowedFirstChars + ['0' .. '9'];
  ValueAllowedChars = IdenfierAllowedChars + [' ', '-', '+', '*', '.', '@', '/', '\']; // maybe a lot others
  START_TAG_1 = '{{';
  END_TAG_1 = '}}';

  { TParser }

procedure TTemplateProEngine.AddTemplateFunction(const FunctionName: string; const FunctionImpl: TTemplateFunction);
begin
  fTemplateFunctions.Add(FunctionName.ToLower, FunctionImpl);
end;

procedure TTemplateProEngine.CheckParNumber(const aMinParNumber, aMaxParNumber: Integer;
  const aParameters: TArray<string>);
var
  lParNumber: Integer;
begin
  lParNumber := Length(aParameters);
  if (lParNumber < aMinParNumber) or (lParNumber > aMaxParNumber) then
  begin
    if aMinParNumber = aMaxParNumber then
      Error(Format('Expected %d parameters, got %d', [aMinParNumber, lParNumber]))
    else
      Error(Format('Expected from %d to %d parameters, got %d', [aMinParNumber, aMaxParNumber, lParNumber]));
  end;
end;


constructor TTemplateProEngine.Create(aEncoding: TEncoding = nil);
begin
  inherited Create;
  if aEncoding = nil then
    fEncoding := TEncoding.UTF8 { default encoding }
  else
    fEncoding := aEncoding;
  fOutput := '';
  fVariables := TDictionary<string, string>.Create;
  fTemplateFunctions := TDictionary<string, TTemplateFunction>.Create;
end;

destructor TTemplateProEngine.Destroy;
begin
  fTemplateFunctions.Free;
  fVariables.Free;
  inherited;
end;

//function TTemplateProEngine.SetDataSourceByName(const aName: string): Boolean;
//var
//  ds: TPair<string, ITPDataSourceAdapter>;
//begin
//  { TODO -oDanieleT -cGeneral : Refactor this method to use GetDataSourceByName }
//  Result := False;
//  for ds in fDataSources do
//  begin
//    if SameText(ds.Key, aName) then
//    begin
//      fCurrentDataSource := ds.Value;
//      Result := True;
//      Break;
//    end;
//  end;
//end;

//function TTemplateProEngine.GetDataSourceByName(const aName: string; out aDataSource: ITPDataSourceAdapter): Boolean;
//var
//  ds: TPair<string, ITPDataSourceAdapter>;
//begin
//  Result := False;
//  for ds in fDataSources do
//  begin
//    if SameText(ds.Key, aName) then
//    begin
//      aDataSource := ds.Value;
//      Result := True;
//      Break;
//    end;
//  end;
//end;

function TTemplateProEngine.MatchEndTag: Boolean;
begin
  Result := MatchSymbol(END_TAG_1);
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
  if CharInSet(fInputString.Chars[fCharIndex], IdenfierAllowedFirstChars) then
  begin
    while CharInSet(fInputString.Chars[fCharIndex], IdenfierAllowedChars) do
    begin
      aIdentifier := aIdentifier + fInputString.Chars[fCharIndex];
      Inc(fCharIndex);
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
  Result := MatchSymbol(START_TAG_1);
end;

function TTemplateProEngine.MatchSymbol(const aSymbol: string): Boolean;
var
  lSymbolIndex: Integer;
  lSavedCharIndex: Int64;
begin
  if aSymbol.IsEmpty then
    Exit(True);
  lSavedCharIndex := fCharIndex;
  lSymbolIndex := 0;
  while (fInputString.Chars[fCharIndex] = aSymbol.Chars[lSymbolIndex]) and (lSymbolIndex < Length(aSymbol)) do
  begin
    Inc(fCharIndex);
    Inc(lSymbolIndex);
  end;
  Result := (lSymbolIndex > 0) and (lSymbolIndex = Length(aSymbol));
  if not Result then
    fCharIndex := lSavedCharIndex;
end;

function TTemplateProEngine.MatchValue(var aValue: string): Boolean;
begin
  aValue := '';
  while CharInSet(fInputString.Chars[fCharIndex], ValueAllowedChars) do
  begin
    aValue := aValue + fInputString.Chars[fCharIndex];
    Inc(fCharIndex);
  end;
  Result := not aValue.IsEmpty;
end;

function TTemplateProEngine.Compile(const aTemplateString: string): ITemplateProCompiledTemplate;
var
  lSectionStack: array [0..49] of Integer; //max 50 nested loops
  lCurrentSectionIndex: Integer;

  lIfStatementStack: array [0..49] of Integer; //max 50 nested ifs
  lCurrentIfIndex: Integer;

  lChar: Char;
  lVarName: string;
  lFuncName: string;
  lIdentifier: string;
  lDataSet: string;
  lFieldName: string;
  lFuncParams: TArray<string>;
  lDataSourceName: string;
  lStartVerbatim: UInt64;
  lEndVerbatim: UInt64;
  lTokens: TList<TToken>;
  lIndexOfLatestIfStatement: UInt64;
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

  function CurrentChar: Char;
  begin
    Result := aTemplateString.Chars[fCharIndex];
  end;

  function Step: Char;
  begin
    Inc(fCharIndex);
    Result := CurrentChar;
  end;

begin
  fCharIndex := -1;
  fCurrentLine := 1;
  lCurrentIfIndex := -1;
  lCurrentSectionIndex := -1;
  fInputString := aTemplateString;
  lTokens := TList<TToken>.Create;
  try
    lStartVerbatim := 0;
    lEndVerbatim := 0;
    lChar := Step;
    while fCharIndex <= aTemplateString.Length do
    begin
      lChar := CurrentChar;
      if lChar = #0 then //eof
      begin
        lEndVerbatim := fCharIndex;
        if lEndVerbatim - lStartVerbatim > 0 then
        begin
          lTokens.Add(TToken.Create(ttContent, aTemplateString.Substring(lStartVerbatim, lEndVerbatim - lStartVerbatim)));
        end;
        Break;
      end;

      // linebreak
      if MatchSymbol(sLineBreak) then
      begin
        lEndVerbatim := fCharIndex - Length(sLineBreak);
        if lEndVerbatim - lStartVerbatim > 0 then
        begin
          lTokens.Add(TToken.Create(ttContent, aTemplateString.Substring(lStartVerbatim, lEndVerbatim - lStartVerbatim)));
        end;
        lStartVerbatim := fCharIndex;
        lEndVerbatim := lStartVerbatim;
        lTokens.Add(TToken.Create(ttLineBreak, ''));
        lChar := CurrentChar;
        Continue;
      end;

      // starttag
      if MatchStartTag then
      begin
        lChar := CurrentChar;
        lEndVerbatim := fCharIndex - Length(START_TAG_1);
        if lEndVerbatim - lStartVerbatim > 0 then
        begin
          lTokens.Add(TToken.Create(ttContent, aTemplateString.Substring(lStartVerbatim, lEndVerbatim - lStartVerbatim)));
        end;

        // loop
        if MatchSymbol('loop') then
        begin
          lChar := CurrentChar;
          if not MatchSymbol('(') then
            Error('Expected "("');
          if not MatchIdentifier(lIdentifier) then
            Error('Expected identifier after "loop("');
          if not MatchSymbol(')') then
            Error('Expected ")" after "' + lIdentifier + '"');
          if not MatchEndTag then
            Error('Expected closing tag for "loop(' + lIdentifier + ')"');
          // create another element in the sections stack
          Inc(lCurrentSectionIndex);
          lSectionStack[lCurrentSectionIndex] := lTokens.Count;
          lTokens.Add(TToken.Create(ttLoop, lIdentifier));
          lStartVerbatim := fCharIndex;
          lEndVerbatim := lStartVerbatim;
        end;

        if MatchSymbol('endloop') then //endloop
        begin
          lChar := CurrentChar;
          if not MatchEndTag then
            Error('Expected closing tag');
          if lCurrentSectionIndex = -1 then
          begin
            Error('endloop without loop');
          end;
          lTokens.Add(TToken.Create(ttEndLoop, '', lSectionStack[lCurrentSectionIndex]));
          Dec(lCurrentSectionIndex);
          lStartVerbatim := fCharIndex;
          lEndVerbatim := lStartVerbatim;
          Continue;
        end;

        if MatchSymbol('endif') then
        begin
          if lCurrentIfIndex = -1 then
          begin
            Error('"endif" without "if"');
          end;
          if not MatchEndTag then
          begin
            Error('Expected closing tag for "endif"');
          end;
          lTokens.Add(TToken.Create(ttEndIf, ''));

          // jumps handling...
          lIndexOfLatestIfStatement := lIfStatementStack[lCurrentIfIndex];
          lTokens[lIndexOfLatestIfStatement] :=
            TToken.Create(ttIfThen, lTokens[lIndexOfLatestIfStatement].Value, lTokens.Count - 1);

          Dec(lCurrentIfIndex);
          lStartVerbatim := fCharIndex;
          lEndVerbatim := lStartVerbatim;
          Continue;
        end;

        if MatchSymbol('if') then
        begin
          if not MatchSymbol('(') then
            Error('Expected "("');
          if not MatchIdentifier(lIdentifier) then
            Error('Expected identifier after "if("');
          if not MatchSymbol(')') then
            Error('Expected ")" after "' + lIdentifier + '"');
          if not MatchEndTag then
            Error('Expected closing tag for "if(' + lIdentifier + ')"');

          lTokens.Add(TToken.Create(ttIfThen, lIdentifier));
          Inc(lCurrentIfIndex);
          lIfStatementStack[lCurrentIfIndex] := lTokens.Count - 1;
          lStartVerbatim := fCharIndex;
          lEndVerbatim := lStartVerbatim;
          Continue;
        end;

//        if MatchSymbol('else') then
//        begin
//          if lCurrentIfIndex = -1 then
//          begin
//            Error('"else" without if');
//          end;
//          if not MatchEndTag then
//          begin
//            Error('Expected end-tag');
//          end;
//
//          lTokens.Add(TToken.Create(ttElse, '', lIfStatementStack[lCurrentIfIndex]));
//          Dec(lCurrentIfIndex);
//          lStartVerbatim := fCharIndex;
//          lEndVerbatim := lStartVerbatim;
//          Continue;
//        end;

        // dataset field
        if MatchField(lDataSourceName, lFieldName) then
        begin
          lChar := CurrentChar;
          if lFieldName.IsEmpty then
            Error('Invalid field name');
          lFuncName := '';
          {
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
          }
          {
          if lFuncName.IsEmpty then
            AppendOutput(GetFieldText(lFieldName))
          else
            AppendOutput(ExecuteFieldFunction(lFuncName, lFuncParams, GetFieldText(lFieldName)));
          }
          if not MatchEndTag then
            Error('Expected closing tag');
          lTokens.Add(TToken.Create(ttDataField, lDataSourceName + '.' + lFieldName));
          lStartVerbatim := fCharIndex;
          lEndVerbatim := lStartVerbatim;
          Continue;
        end;

        // reset
        {
        if MatchReset(lDataSet) then
        begin
          if not MatchEndTag then
            Error('Expected closing tag');
          SetDataSourceByName(lDataSet);
          fCurrentDataSource.Reset;
          Continue;
        end;
        }

        // identifier
        if MatchIdentifier(lVarName) then
        begin
          lChar := CurrentChar;
          if lVarName.IsEmpty then
            Error('Invalid variable name');
          lFuncName := '';
          {
          if MatchSymbol('|') then
          begin
            if not MatchIdentifier(lFuncName) then
              Error('Invalid function name');
            lFuncParams := GetFunctionParameters;
            if not MatchEndTag then
              Error('Expected end tag');
            AppendOutput(ExecuteFunction(lFuncName, lFuncParams, GetVarAsString(lVarName)));
          end
          else
          begin
            if not MatchEndTag then
              Error('Expected end tag');
            AppendOutput(GetVarAsString(lVarName));
          end;
          }
          if not MatchEndTag then
          begin
            Error('Expected end tag "' + END_TAG_1 + '"');
          end;
          lChar := CurrentChar;
          lStartVerbatim := fCharIndex;
          lEndVerbatim := lStartVerbatim;
          lTokens.Add(TToken.Create(ttValue, lVarName));
        end;

        // comment
        if MatchSymbol('#') then
        begin
          while not MatchEndTag do
          begin
            lChar := Step;
          end;
          lChar := CurrentChar;
          lStartVerbatim := fCharIndex;
          lEndVerbatim := lStartVerbatim;
          //lTokens.Add(TToken.Create(ttValue, lVarName));
        end;
      end
      else
      begin
        // output verbatim
        Inc(lEndVerbatim);
        lChar := Step;
      end;
    end;
    Result := TTemplateProCompiledTemplate.Create(lTokens);
  except
    on E: Exception do
    begin
      lTokens.Free;
      raise;
    end;
  end;
end;

function CapitalizeString(const s: string; const CapitalizeFirst: Boolean): string;
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

procedure TTemplateProEngine.Error(const aMessage: string);
begin
  raise EParserException.CreateFmt('%s - at line %d', [aMessage, fCurrentLine]);
end;

procedure TTemplateProEngine.CheckParNumber(const aHowManyPars: Integer; const aParameters: TArray<string>);
begin
  CheckParNumber(aHowManyPars, aHowManyPars, aParameters);
end;

function TTemplateProEngine.ExecuteFunction(aFunctionName: string; aParameters: TArray<string>;
  aValue: string): string;
var
  lFunc: TTemplateFunction;
begin
  aFunctionName := lowercase(aFunctionName);
  if aFunctionName = 'tohtml' then
  begin
    Exit(HTMLEntitiesEncode(aValue));
  end;
  if aFunctionName = 'uppercase' then
  begin
    Exit(UpperCase(aValue));
  end;
  if aFunctionName = 'lowercase' then
  begin
    Exit(lowercase(aValue));
  end;
  if aFunctionName = 'capitalize' then
  begin
    Exit(CapitalizeString(aValue, True));
  end;
  if aFunctionName = 'rpad' then
  begin
    CheckParNumber(1, 2, aParameters);
    if Length(aParameters) = 1 then
      Exit(aValue.PadRight(aParameters[0].ToInteger))
    else
      Exit(aValue.PadRight(aParameters[0].ToInteger, aParameters[1].Chars[0]));
  end;
  if aFunctionName = 'lpad' then
  begin
    if Length(aParameters) = 1 then
      Exit(aValue.PadLeft(aParameters[0].ToInteger))
    else
      Exit(aValue.PadLeft(aParameters[0].ToInteger, aParameters[1].Chars[0]));
  end;

  if not fTemplateFunctions.TryGetValue(aFunctionName, lFunc) then
  begin
    raise EParserException.CreateFmt('Unknown function [%s]', [aFunctionName]);
  end;
  Result := lFunc(aParameters, aValue);
end;

function TTemplateProEngine.ExecuteFieldFunction(aFunctionName: string; aParameters: TArray<string>;
  aValue: TValue): string;
var
  lDateValue: TDate;
  lDateTimeValue: TDateTime;
  lStrValue: string;
begin
  aFunctionName := lowercase(aFunctionName);
  if aFunctionName = 'tohtml' then
  begin
    Exit(HTMLEntitiesEncode(aValue.AsString));
  end;
  if aFunctionName = 'uppercase' then
  begin
    Exit(UpperCase(aValue.AsString));
  end;
  if aFunctionName = 'lowercase' then
  begin
    Exit(lowercase(aValue.AsString));
  end;
  if aFunctionName = 'capitalize' then
  begin
    Exit(CapitalizeString(aValue.AsString, True));
  end;
  if aFunctionName = 'rpad' then
  begin
    if aValue.IsType<Integer> then
      lStrValue := aValue.AsInteger.ToString
    else if aValue.IsType<string> then
      lStrValue := aValue.AsString
    else
      Error(Format('Invalid parameter/s for function: %s', [aFunctionName]));

    CheckParNumber(1, 2, aParameters);
    if Length(aParameters) = 1 then
    begin
      Exit(lStrValue.PadRight(aParameters[0].ToInteger));
    end
    else
    begin
      Exit(lStrValue.PadRight(aParameters[0].ToInteger, aParameters[1].Chars[0]));
    end;
  end;
  if aFunctionName = 'lpad' then
  begin
    if aValue.IsType<Integer> then
      lStrValue := aValue.AsInteger.ToString
    else if aValue.IsType<string> then
      lStrValue := aValue.AsString
    else
      Error(Format('Invalid parameter/s for function: ', [aFunctionName]));

    CheckParNumber(1, 2, aParameters);
    if Length(aParameters) = 1 then
    begin
      Exit(lStrValue.PadLeft(aParameters[0].ToInteger));
    end
    else
    begin
      Exit(lStrValue.PadLeft(aParameters[0].ToInteger, aParameters[1].Chars[0]));
    end;
  end;

  if aFunctionName = 'datetostr' then
  begin
    if not aValue.TryAsType<TDate>(lDateValue) then
      Error('Invalid Date');
    Exit(DateToStr(lDateValue));
  end;
  if aFunctionName = 'datetimetostr' then
  begin
    if not aValue.TryAsType<TDateTime>(lDateTimeValue) then
      Error('Invalid DateTime');
    Exit(DateTimeToStr(lDateTimeValue));
  end;
  if aFunctionName = 'formatdatetime' then
  begin
    CheckParNumber(1, aParameters);
    if not aValue.TryAsType<TDateTime>(lDateTimeValue) then
      Error('Invalid DateTime');
    Exit(FormatDateTime(aParameters[0], lDateTimeValue));
  end;

  Error(Format('Unknown function [%s]', [aFunctionName]));
end;

{ TTPDatasetAdapter }

constructor TTPDatasetAdapter.Create(const aDataSet: TDataSet);
begin
  inherited Create;
  fDataSet := aDataSet;
end;

function TTPDatasetAdapter.CurrentIndex: Int64;
begin
  Result := fDataSet.RecNo;
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

constructor TTPObjectListAdapter.Create(const aObjectList: TObjectList<TObject>);
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

function HTMLEntitiesEncode(s: string): string;
  procedure repl(var s: string; r: string; posi: Integer);
  begin
    delete(s, posi, 1);
    insert(r, s, posi);
  end;

var
  I: Integer;
  r: string;
begin
  I := 0;
  while I < Length(s) do
  begin
    r := '';
    case ord(s[I]) of
      160:
        r := 'nbsp';
      161:
        r := 'excl';
      162:
        r := 'cent';
      163:
        r := 'ound';
      164:
        r := 'curren';
      165:
        r := 'yen';
      166:
        r := 'brvbar';
      167:
        r := 'sect';
      168:
        r := 'uml';
      169:
        r := 'copy';
      170:
        r := 'ordf';
      171:
        r := 'laquo';
      172:
        r := 'not';
      173:
        r := 'shy';
      174:
        r := 'reg';
      175:
        r := 'macr';
      176:
        r := 'deg';
      177:
        r := 'plusmn';
      178:
        r := 'sup2';
      179:
        r := 'sup3';
      180:
        r := 'acute';
      181:
        r := 'micro';
      182:
        r := 'para';
      183:
        r := 'middot';
      184:
        r := 'cedil';
      185:
        r := 'sup1';
      186:
        r := 'ordm';
      187:
        r := 'raquo';
      188:
        r := 'frac14';
      189:
        r := 'frac12';
      190:
        r := 'frac34';
      191:
        r := 'iquest';
      192:
        r := 'Agrave';
      193:
        r := 'Aacute';
      194:
        r := 'Acirc';
      195:
        r := 'Atilde';
      196:
        r := 'Auml';
      197:
        r := 'Aring';
      198:
        r := 'AElig';
      199:
        r := 'Ccedil';
      200:
        r := 'Egrave';
      201:
        r := 'Eacute';
      202:
        r := 'Ecirc';
      203:
        r := 'Euml';
      204:
        r := 'Igrave';
      205:
        r := 'Iacute';
      206:
        r := 'Icirc';
      207:
        r := 'Iuml';
      208:
        r := 'ETH';
      209:
        r := 'Ntilde';
      210:
        r := 'Ograve';
      211:
        r := 'Oacute';
      212:
        r := 'Ocirc';
      213:
        r := 'Otilde';
      214:
        r := 'Ouml';
      215:
        r := 'times';
      216:
        r := 'Oslash';
      217:
        r := 'Ugrave';
      218:
        r := 'Uacute';
      219:
        r := 'Ucirc';
      220:
        r := 'Uuml';
      221:
        r := 'Yacute';
      222:
        r := 'THORN';
      223:
        r := 'szlig';
      224:
        r := 'agrave';
      225:
        r := 'aacute';
      226:
        r := 'acirc';
      227:
        r := 'atilde';
      228:
        r := 'auml';
      229:
        r := 'aring';
      230:
        r := 'aelig';
      231:
        r := 'ccedil';
      232:
        r := 'egrave';
      233:
        r := 'eacute';
      234:
        r := 'ecirc';
      235:
        r := 'euml';
      236:
        r := 'igrave';
      237:
        r := 'iacute';
      238:
        r := 'icirc';
      239:
        r := 'iuml';
      240:
        r := 'eth';
      241:
        r := 'ntilde';
      242:
        r := 'ograve';
      243:
        r := 'oacute';
      244:
        r := 'ocirc';
      245:
        r := 'otilde';
      246:
        r := 'ouml';
      247:
        r := 'divide';
      248:
        r := 'oslash';
      249:
        r := 'ugrave';
      250:
        r := 'uacute';
      251:
        r := 'ucirc';
      252:
        r := 'uuml';
      253:
        r := 'yacute';
      254:
        r := 'thorn';
      255:
        r := 'yuml';
    end;
    if r <> '' then
    begin
      repl(s, '&' + r + ';', I);
    end;
    Inc(I)
  end;
  Result := s;
end;

{ TToken }

class function TToken.Create(TokType: TTokenType; Value: String; Ref: Integer): TToken;
begin
  Result.TokenType:= TokType;
  Result.Value := Value;
  Result.Ref := Ref;
end;

function TToken.TokenTypeAsString: String;
begin
  Result := TOKEN_TYPE_DESCR[self.TokenType];
end;

{ TTemplateProCompiledTemplate }

constructor TTemplateProCompiledTemplate.Create(Tokens: TList<TToken>);
begin
  inherited Create;
  fTokens := Tokens;
end;

procedure TTemplateProCompiledTemplate.Error(const aMessage: String);
begin
  raise EParserException.Create(aMessage);
end;

procedure TTemplateProCompiledTemplate.ForEachToken(
  const TokenProc: TTokenWalkProc);
var
  I: Integer;
begin
  for I := 0 to fTokens.Count - 1 do
  begin
    TokenProc(I, fTokens[I]);
  end;
end;


function TTemplateProCompiledTemplate.InternalRender: String;
var
  lIdx: UInt64;
  lBuff: TStringBuilder;
  lDataSource: ITPDataSourceAdapter;
  lSectionStack: array[0..49] of String;
  lSectionStackIndex: Integer;
begin
  lSectionStackIndex := -1;
  lBuff := TStringBuilder.Create;
  try
    lIdx := 0;
    while True do
    begin
      case fTokens[lIdx].TokenType of
        ttContent: begin
          lBuff.Append(fTokens[lIdx].Value);
        end;
        ttLoop: begin
          if GetDataSource.TryGetValue(fTokens[lIdx].Value, lDataSource) then
          begin
            if lDataSource.Eof then
            begin
              lIdx := fTokens[lIdx].Ref;
              Continue;
            end;
            Inc(lSectionStackIndex);
            lSectionStack[lSectionStackIndex] := fTokens[lIdx].Value;
          end;
        end;
        ttEndLoop: begin
          if GetDataSource.TryGetValue(lSectionStack[lSectionStackIndex], lDataSource) then
          begin
            lDataSource.Next;
            if not lDataSource.Eof then
            begin
              lIdx := fTokens[lIdx].Ref;
              Continue;
            end;
          end;
        end;
        ttIfThen: begin
          if not EvaluateIfExpression(fTokens[lIdx].Value) then
          begin
            lIdx := fTokens[lIdx].Ref; //jump to "endif"
            Continue;
          end;
        end;
        ttEndIf: begin end;
        ttStartTag: begin end;
        ttEndTag : begin end;
        ttDataField: begin end;
        ttValue: begin
          lBuff.Append(GetVarAsString(fTokens[lIdx].Value));
        end;
        ttReset: begin end;
        ttField: begin end;
        ttLineBreak: begin
          lBuff.AppendLine;
        end;
        else
          raise ERenderException.Create('Invalid token: ' + fTokens[lIdx].TokenTypeAsString);
      end;

      Inc(lIdx);
      if lIdx = fTokens.Count then
      begin
        Break;
      end;
    end;
    Result := lBuff.ToString;
  finally
    lBuff.Free;
  end;
end;

function TTemplateProCompiledTemplate.Render: String;
begin
  Result := InternalRender();
end;

function TTemplateProCompiledTemplate.GetDataSource: TDictionary<string, ITPDataSourceAdapter>;
begin
  if not Assigned(fDataSources) then
  begin
    fDataSources := TDictionary<string, ITPDataSourceAdapter>.Create;
  end;
  Result := fDataSources;
end;

function TTemplateProCompiledTemplate.GetFieldText(const aFieldName: string): string;
begin
//  if not Assigned(fCurrentDataSource) then
//    Error('Current datasource not set');
//  Result := fCurrentDataSource.GetMemberValue(aFieldName);
end;

function TTemplateProCompiledTemplate.GetVarAsString(const aName: string): string;
var
  lValue: TValue;
begin
  if GetVariables.TryGetValue(aName, lValue) then
  begin
    if lValue.IsType<Integer> then
      Result := lValue.AsInteger.ToString
    else if lValue.IsType<Boolean> then
      Result := lValue.AsBoolean.ToString
    else if lValue.IsType<Double> then
      Result := lValue.AsExtended.ToString
    else
      Result := lValue.AsString;
  end
  else
  begin
    Result := '';
  end;
end;

function TTemplateProCompiledTemplate.GetVariables: TDictionary<string, TValue>;
begin
  if not Assigned(fVariables) then
  begin
    fVariables := TDictionary<string, TValue>.Create;
  end;
  Result := fVariables;
end;

function TTemplateProCompiledTemplate.EvaluateIfExpression(const aIdentifier: string): Boolean;
var
  lVarValue: String;
begin
  lVarValue := GetVarAsString(aIdentifier);
  if SameText(lVarValue, 'false') or (lVarValue = '0') or lVarValue.IsEmpty then
  begin
    Exit(False);
  end
  else
  begin
    Exit(True);
  end;
end;


procedure TTemplateProCompiledTemplate.SetData(const Name: String;
  Value: TValue);
begin
  GetVariables.Add(Name, Value);
end;

procedure TTemplateProCompiledTemplate.SetData(const Name: String;
  Value: TObject);
begin
  GetVariables.Add(Name, Value);
end;

procedure TTemplateProCompiledTemplate.SetVar(const aName: string; aValue: string);
begin
//  fVariables.AddOrSetValue(aName, aValue);
end;


procedure TTemplateProCompiledTemplate.ClearVariables;
begin
//  fVariables.Clear;
end;


procedure TTemplateProCompiledTemplate.SetData(const Name: String;
  Value: TDataSet);
begin

end;

end.
