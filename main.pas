unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  LCLProc, CurvedText;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnExec :TButton;
    procedure btnExecClick(Sender :TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1 : TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.btnExecClick(Sender :TObject);
var
  S :String;
  Points :array[0..6] of TPoint;
begin
  S := 'Bézier Text Out Test';
  Canvas.Font.Name := 'Tahoma';
  Canvas.Font.Size := 14;
  Canvas.Font.Style := [fsBold];
  Points[0] := Point( 50,  50);
  Points[1] := Point(100, 150);
  Points[2] := Point(200, 150);
  Points[3] := Point(250,  50);
  Points[4] := Point(300,  0);
  Points[5] := Point(400,  0);
  Points[6] := Point(450, 50);
  BezierTextOut(Canvas, Points, S);
end;

end.

