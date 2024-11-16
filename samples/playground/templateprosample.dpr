program templateprosample;

uses
  Vcl.Forms,
  MainFormU in 'MainFormU.pas' {MainForm},
  RandomTextUtilsU in 'RandomTextUtilsU.pas',
  TemplatePro in '..\TemplatePro.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Glow');
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
