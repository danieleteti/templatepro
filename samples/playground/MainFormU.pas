unit MainFormU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Data.DB,
  Vcl.ExtCtrls,
  Vcl.FileCtrl,
  Vcl.ComCtrls,
  Vcl.Grids,
  Vcl.DBGrids,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  Vcl.OleCtrls,
  SHDocVw,
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

  TMainForm = class(TForm)
    ds1: TFDMemTable;
    ds1name: TStringField;
    FileListBox1: TFileListBox;
    Panel1: TPanel;
    btnExecute: TButton;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    chkOpenGeneratedFile: TCheckBox;
    ds2: TFDMemTable;
    ds1id: TIntegerField;
    ds2id: TIntegerField;
    ds2contact: TStringField;
    ds2contact_type: TStringField;
    ds2id_person: TIntegerField;
    DataSource1: TDataSource;
    DataSource2: TDataSource;
    TabSheet3: TTabSheet;
    DBGrid1: TDBGrid;
    DBGrid2: TDBGrid;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    ds1country: TStringField;
    MemoTemplate: TMemo;
    MemoOutput: TMemo;
    procedure btnExecuteClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FileListBox1DblClick(Sender: TObject);
  private
    function GetItems: TObjectList<TObject>;
    procedure ExecuteTemplate(const aTemplateString: string);
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}


uses
  System.IOUtils,
  Winapi.Shellapi,
  RandomTextUtilsU,
  TemplatePro,
  Winapi.ActiveX;

procedure TMainForm.btnExecuteClick(Sender: TObject);
begin
  ExecuteTemplate(MemoTemplate.Lines.Text);
end;

procedure TMainForm.FileListBox1DblClick(Sender: TObject);
begin
  PageControl1.ActivePageIndex := 0;
  if tfile.Exists(FileListBox1.FileName) then
    MemoTemplate.Lines.LoadFromFile(FileListBox1.FileName, TEncoding.UTF8);
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  I: Integer;
  J: Integer;
  lName: string;
  lLastName: string;
begin
  ds1.Open;
  ds2.Open;

  for I := 1 to 10 do
  begin
    lName := GetRndFirstName;
    lLastName := getrndlastname;
    ds1.AppendRecord([I, lName + ' ' + lLastName, GetRndCountry]);
    for J := 1 to Random(10) + 2 do
    begin
      ds2.AppendRecord([I * 100 + J, I, Format('%s.%s@%s.com', [lName.Substring(0, 1).ToLower,
        lLastName.ToLower, GetRndCountry.ToLower]), 'email']);
    end;
  end;
  ds1.First;
  ds2.First;
end;

// http://www.cryer.co.uk/brian/delphi/twebbrowser/put_HTML.htm
procedure LoadHtmlIntoBrowser(browser: TWebBrowser; const html: string);
var
  lSWriter: TStreamWriter;
begin
  // -------------------
  // Load a blank page.
  // -------------------
  browser.Navigate('about:blank');
  while browser.ReadyState <> READYSTATE_COMPLETE do
  begin
    Sleep(5);
    Application.ProcessMessages;
  end;
  // ---------------
  // Load the html.
  // ---------------
  lSWriter := TStreamWriter.Create(TMemoryStream.Create);
  try
    lSWriter.OwnStream;
    lSWriter.Write(html);
    lSWriter.BaseStream.Position := 0;
    (browser.Document as IPersistStreamInit).Load(
      TStreamAdapter.Create(lSWriter.BaseStream));
  finally
    lSWriter.Free;
  end;
end;

procedure TMainForm.ExecuteTemplate(const aTemplateString: string);
var
  lCompiler: TTProCompiler;
  lTemplate: string;
  lOutputFileName: string;
  lOutput: string;
  lItems: TObjectList<TObject>;
  lCompiledTmpl: ITProCompiledTemplate;
begin
  lTemplate := aTemplateString;
  lCompiler := TTProCompiler.Create;
  try
    lCompiledTmpl := lCompiler.Compile(aTemplateString);
    lItems := GetItems;
    try
      lCompiledTmpl.SetData('first_name', 'Daniele');
      lCompiledTmpl.SetData('last_name', 'Teti');
      lCompiledTmpl.SetData('today', DateToStr(date));
      lCompiledTmpl.SetData('people', ds1);
      lCompiledTmpl.SetData('contacts', ds2);
      lCompiledTmpl.SetData('items', lItems);
      lOutput := lCompiledTmpl.Render;
    finally
      lItems.Free;
    end;
    TDirectory.CreateDirectory(ExtractFilePath(Application.ExeName) + 'output');
    lOutputFileName := ExtractFilePath(Application.ExeName) + 'output\' +
      'last_output.html';
    TFile.WriteAllText(lOutputFileName, lOutput, TEncoding.UTF8);
    MemoOutput.Lines.LoadFromFile(lOutputFileName);
  finally
    lCompiler.Free;
  end;
  if chkOpenGeneratedFile.Checked then
    ShellExecute(0, pchar('open'), pchar(lOutputFileName), nil, nil, SW_NORMAL);
  PageControl1.ActivePageIndex := 1;
end;

function TMainForm.GetItems: TObjectList<TObject>;
begin
  Result := TObjectList<TObject>.Create(True);
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
