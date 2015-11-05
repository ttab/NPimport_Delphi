program NPimport;

uses
  Forms,
  npimportu in 'npimportu.pas' {NPimp};

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'NPimport';
  Application.CreateForm(TNPimp, NPimp);
  Application.Run;
end.
