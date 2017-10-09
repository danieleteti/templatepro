program templateprosample;

uses
  Vcl.Forms,
  MainFormU in 'MainFormU.pas' {MainForm},
  TemplateProU in '..\TemplateProU.pas',
  RandomTextUtilsU in 'RandomTextUtilsU.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
