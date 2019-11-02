program templateprotests;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  MainTestU in 'MainTestU.pas',
  TemplateProU in '..\TemplateProU.pas';

begin
  try
    Main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
