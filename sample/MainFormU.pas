unit MainFormU;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Data.DB, Vcl.ExtCtrls, Vcl.FileCtrl, Vcl.ComCtrls, Vcl.Grids,
  Vcl.DBGrids, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet, FireDAC.Comp.Client, Vcl.OleCtrls, SHDocVw;

type
  TMainForm = class(TForm)
    ds1: TFDMemTable;
    ds1name: TStringField;
    FileListBox1: TFileListBox;
    Panel1: TPanel;
    Button1: TButton;
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
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FileListBox1DblClick(Sender: TObject);
  private
    function ReadReport(const FileName: string): string;
    procedure GenerateReport(const aReport: string);
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}


uses System.IOUtils, Winapi.Shellapi, RandomTextUtilsU, TemplateProU,
  Winapi.ActiveX, System.Generics.Collections;

procedure TMainForm.Button1Click(Sender: TObject);
begin
  GenerateReport(MemoTemplate.Lines.Text);
end;

procedure TMainForm.FileListBox1DblClick(Sender: TObject);
begin
  PageControl1.ActivePageIndex := 1;
  if tfile.Exists(FileListBox1.FileName) then
    MemoTemplate.Lines.LoadFromFile(FileListBox1.FileName);
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

  for I := 1 to 100 do
  begin
    lName := GetRndFirstName;
    lLastName := getrndlastname;
    ds1.AppendRecord([I, lName + ' ' + lLastName, GetRndCountry]);
    for J := 1 to Random(15) + 2 do
    begin
      ds2.AppendRecord([I * 100 + J, I, Format('%s.%s@%s.com', [lName.Substring(0, 1).ToLower,
        lLastName.ToLower, GetRndCountry.ToLower]), 'email']);
    end;
  end;
  ds1.First;
  ds2.First;

  // Button2Click(self);
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

procedure TMainForm.GenerateReport(const aReport: string);
var
  lTPEngine: TTemplateProEngine;
  lTemplate: string;
  lOutputFileName: string;
  lOutput: string;
  lOutputStream: TStringStream;
  lDatasets: TObjectDictionary<string, TDataset>;
begin
  // MemoTemplate.Lines.LoadFromFile(aReport);
  ds1.First;
  lTemplate := aReport;

  lTPEngine := TTemplateProEngine.Create;
  try
    lTPEngine.SetVar('first_name', 'Daniele');
    lTPEngine.SetVar('last_name', 'Teti');
    lTPEngine.SetVar('today', DateToStr(date));

    lOutputStream := TStringStream.Create;
    try
      lDatasets := TObjectDictionary<string, TDataset>.Create;
      try
        lDatasets.Add('people', ds1);
        lDatasets.Add('contacts', ds2);
        lTPEngine.Execute(aReport, lDatasets, lOutputStream);
      finally
        lDatasets.Free;
      end;
      TDirectory.CreateDirectory(ExtractFilePath(Application.ExeName) + 'output');
      lOutputFileName := ExtractFilePath(Application.ExeName) + 'output\' +
        'last_output.html';
      lOutput := lOutputStream.DataString;
      // LoadHtmlIntoBrowser(wb, lOutput);
      tfile.WriteAllText(lOutputFileName, lOutput);
      MemoOutput.Lines.LoadFromFile(lOutputFileName);
    finally
      lOutputStream.Free;
    end;
  finally
    lTPEngine.Free;
  end;
  if chkOpenGeneratedFile.Checked then
    ShellExecute(0, pchar('open'), pchar(lOutputFileName), nil, nil, SW_NORMAL);
  PageControl1.ActivePageIndex := 0;
end;

function TMainForm.ReadReport(const FileName: string): string;
begin
  with TStreamReader.Create(TFileStream.Create(FileName, fmOpenRead, fmShareDenyNone),
    TEncoding.ANSI) do
  begin
    OwnStream;
    Result := ReadToEnd;
    Free;
  end;
end;

end.
