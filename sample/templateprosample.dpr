program templateprosample;

uses
  Vcl.Forms,
  MainFormU in 'MainFormU.pas' {MainForm},
  RandomTextUtilsU in 'RandomTextUtilsU.pas',
  TemplatePro in '..\TemplatePro.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
