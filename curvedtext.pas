unit CurvedText;

{
Main code by Angus Johnson
Adaptation for Lazarus by Antônio Galvão
}

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, LCLType, LCLProc, Graphics, LazUTF8, Math;

procedure BezierTextOut(ACanvas: TCanvas; BezierPoints: array of TPoint; const s: string);
procedure CircleTextOut(ACanvas :TCanvas; Center :TPoint; Radius :integer;
  s :string);

implementation

// taazz / Angus
//----------------------------
type
  TPoints = array of TPoint;

  PFloatPoint = ^TFloatPoint;
  TFloat = Single;
  TFloatPoint = record
    X, Y: TFloat;
  end;

function GetBezierPolyline(Control_Points: array of TPoint): TPoints;
const
  cBezierTolerance = 0.00001;  //0.001;//
  half = 0.5;
var
   I, J, ArrayLen, ResultCnt: Integer;
   CtrlPts: array[0..3] of TFloatPoint;

  function FixedPoint(const FP: TFloatPoint): TPoint;
  begin
    Result.X := Round(FP.X * 65536);
    Result.Y := Round(FP.Y * 65536);
  end;

  function FloatPoint(const P: TPoint): TFloatPoint;overload;
  const
    F = 1 / 65536;
  begin
    with P do
    begin
      Result.X := X * F;
      Result.Y := Y * F;
    end;
  end;

  procedure RecursiveCBezier(const p1, p2, p3, p4: TFloatPoint);
   var
     p12, p23, p34, p123, p234, p1234: TFloatPoint;
   begin
     // assess flatness of curve ...
     // http://groups.google.com/group/comp.graphics.algorithms/tree/browse_frm/thread/d85ca902fdbd746e
     if abs(p1.x + p3.x - 2*p2.x) + abs(p2.x + p4.x - 2*p3.x) +
       abs(p1.y + p3.y - 2*p2.y) + abs(p2.y + p4.y - 2*p3.y) < cBezierTolerance then
     begin
       if ResultCnt = Length(Result) then
         SetLength (Result, Length(Result) + 128);
       Result[ResultCnt] := FixedPoint(p4);
       Inc(ResultCnt);
     end else
     begin
       p12.X := (p1.X + p2.X) *half;
       p12.Y := (p1.Y + p2.Y) *half;
       p23.X := (p2.X + p3.X) *half;
       p23.Y := (p2.Y + p3.Y) *half;
       p34.X := (p3.X + p4.X) *half;
       p34.Y := (p3.Y + p4.Y) *half;
       p123.X := (p12.X + p23.X) *half;
       p123.Y := (p12.Y + p23.Y) *half;
       p234.X := (p23.X + p34.X) *half;
       p234.Y := (p23.Y + p34.Y) *half;
       p1234.X := (p123.X + p234.X) *half;
       p1234.Y := (p123.Y + p234.Y) *half;
       RecursiveCBezier(p1, p12, p123, p1234);
       RecursiveCBezier(p1234, p234, p34, p4);
     end;
   end;

begin
   //first check that the 'control_Points' count is valid ...
   ArrayLen := Length(Control_Points);
   if (ArrayLen < 4) or ((ArrayLen -1) mod 3 <> 0) then Exit;

   SetLength(Result, 128);
   Result[0] := Control_Points[0];
   ResultCnt := 1;
   for I := 0 to (ArrayLen div 3)-1 do
   begin
     for J := 0 to 3 do
       CtrlPts[J] := FloatPoint(Control_Points[I*3 +J]);
     RecursiveCBezier(CtrlPts[0], CtrlPts[1], CtrlPts[2], CtrlPts[3]);
   end;
   SetLength(Result, ResultCnt);
end;
//----------------------------
//taazz / Angus


//--------------------------------------------------------------------------
//Helper functions
//--------------------------------------------------------------------------

function DistanceBetween2Pts(pt1,pt2: TPoint): single;
begin
  result := sqrt((pt1.X - pt2.X)*(pt1.X - pt2.X) +
    (pt1.Y - pt2.Y)*(pt1.Y - pt2.Y));
end;
//--------------------------------------------------------------------------

function GetPtAtDistAndAngleFromPt(pt: TPoint;
  dist: integer; angle: single): TPoint;
begin
  result.X := round(dist * cos(angle));
  result.Y := -round(dist * sin(angle)); //nb: Y axis is +ve down
  inc(result.X , pt.X);
  inc(result.Y , pt.Y);
end;
//--------------------------------------------------------------------------

function PtBetween2Pts(pt1, pt2: TPoint;
  relativeDistFromPt1: single): TPoint;
begin
  //nb: 0 <= relativeDistFromPt1 <= 1
  if pt2.X = pt1.X then
    result.X := pt2.X else
    result.X := pt1.X + round((pt2.X - pt1.X)*relativeDistFromPt1);
  if pt2.Y = pt1.Y then
    result.Y := pt2.Y else
    result.Y := pt1.Y + round((pt2.Y - pt1.Y)*relativeDistFromPt1);
end;
//--------------------------------------------------------------------------

function GetAnglePt2FromPt1(pt1, pt2: TPoint): single;
begin
  //nb: result is in radians
  dec(pt2.X,pt1.X);
  dec(pt2.Y,pt1.Y);
  with pt2 do
    if X = 0 then
    begin
      result := pi/2;
      if Y > 0 then result := 3*result; //nb: Y axis is +ve down
    end else
    begin
      result := arctan2(-Y,X);
      if result < 0 then result := result + pi * 2;
    end;
end;
//--------------------------------------------------------------------------

procedure AngledCharOut(Canvas: TCanvas; pt: TPoint;
  c: string; radians: single; offsetX, offsetY: integer);
var
  lf: TLogFont;
  OldFontHdl,NewFontHdl: HFont;
  angle: integer;
begin
  angle := round(radians * 180/pi);
  if angle > 180 then angle := angle - 360;

  //workaround because textout() without any rotation is malaligned
  //relative to other rotated text ...
  if angle = 0 then angle := 1;
  Canvas.Font.Orientation := angle * 10;
  Canvas.TextOut(pt.x, pt.y, c);
end;

//--------------------------------------------------------------------------
// BezierTextOut()
//--------------------------------------------------------------------------

procedure BezierTextOut(ACanvas: TCanvas;
  BezierPoints: array of TPoint; const s: string);
var
  i, j, ptCnt, textLenPxls, textLenChars, vertOffset: integer;
  currentInsertionDist, charWidthDiv2: integer;
  pt: TPoint;
  flatPts: array of TPoint;
  types: array of byte;
  distances: array of single;
  dummyPtr: Pointer;
  angle, spcPxls, BezierLen, relativeDistFRomPt1: single;
  charWidths: array[#32..#255] of integer;
begin
  TextLenChars := Length(s);

  //make sure there's text and a valid number of bezier Points ...
  if (TextLenChars = 0) or (High(BezierPoints) mod 3 <> 0) then Exit;

  with ACanvas do
  begin
    flatPts := GetBezierPolyline(BezierPoints);
    ptCnt := Length(flatPts);
    if ptCnt < 1 then Exit;

    SetLength(flatPts, ptCnt);
    SetLength(types, ptCnt);
    SetLength(distances, ptCnt);

    //calculate and fill the distances array ...
    distances[0] := 0;
    BezierLen := 0;
    for i := 1 to ptCnt -1 do
    begin
      BezierLen := BezierLen +
      DistanceBetween2Pts(flatPts[i], flatPts[i-1]);
      distances[i] := BezierLen;
    end;

    //calc length of text in pixels ...
    textLenPxls := 0;
    for i := 1 to textLenChars do
      inc(textLenPxls, TextWidth(UTF8Copy(s, i, 1)));

    //calc space between chars to spread string along entire curve ...
    if textLenChars = 1 then
      spcPxls := 0 else
      spcPxls := (BezierLen - textLenPxls)/(textLenChars -1);

    SetBkMode (Handle, TRANSPARENT);

    //Position the text over the top of the curve.
    //Empirically, moving characters up 2/3 of TextHeight seems OK ...
    vertOffset := -trunc(2/3* TextHeight('Yy'));

    j := 1;
    CurrentInsertionDist := 0;
    for i := 1 to textLenChars do
    begin
      charWidthDiv2 := TextWidth(UTF8Copy(s, i, 1)) div 2;
      //increment CurrentInsertionDist half the width of char to get
      //the slope of the curve at the midPoint of that character ...
      inc(CurrentInsertionDist, charWidthDiv2);

      //find the Point on the flattened path corresponding to the
      //midPoint of the current character ...
      while (j < ptCnt -1) and (distances[j] < CurrentInsertionDist) do
        inc(j);
      if distances[j] = CurrentInsertionDist then
        pt := flatPts[j]
      else
      begin
        relativeDistFRomPt1 := (CurrentInsertionDist - distances[j-1]) /
          (distances[j] - distances[j-1]);
        pt := PtBetween2Pts(flatPts[j-1],flatPts[j],relativeDistFRomPt1);
      end;
      //get the angle of the path at this Point ...
      angle := GetAnglePt2FromPt1(flatPts[j-1], flatPts[j]);

      //finally, draw the character at the given angle  ...
      AngledCharOut(ACanvas, pt, UTF8Copy(s, i, 1), angle, -charWidthDiv2, vertOffset);

      //increment currentInsertionDist to the start of next character ...
      inc(CurrentInsertionDist,
        charWidthDiv2 + trunc(spcPxls) + round(frac(spcPxls*i)));
    end;

    //reset font orientation
    ACanvas.Font.Orientation := 0;

    //debug only - draw the path from the Points ...
    //with flatPts[0] do ACanvas.moveto(X,Y);
    //for i := 1 to ptCnt -1 do with flatPts[i] do ACanvas.lineto(X,Y);
  end;
end;

procedure CircleTextOut(ACanvas :TCanvas; Center :TPoint; Radius :integer; S :string);
var
  Points :array[0..6] of TPoint;
  dx, dy :integer;
begin
  // horizontal
  dx := Center.X - Radius;
  dy := Center.Y;
  Points[0] := Point(dx, dy);
  Points[1] := Point(dx + Round(0.05*dx), dy - 4*Radius div 3);
  Points[2] := Point(dx + 2*Radius - Round(0.05*dx), dy - 4*Radius div 3);
  Points[3] := Point(dx + 2*Radius,  dy);
  Points[4] := Point(dx + 2*Radius - Round(0.05*dx), dy + 4*Radius div 3);
  Points[5] := Point(dx + Round(0.05*dx), dy + 4*Radius div 3);
  Points[6] := Point(dx, dy);
  BezierTextOut(ACanvas, Points, S);
end;

end.
