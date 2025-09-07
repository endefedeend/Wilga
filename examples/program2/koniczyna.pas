program KoniczynaWilgaSimple;
uses wilga, Math,sysutils;

type
  TPoint = record x, y: SmallInt; end;

var
  sX, sY: SmallInt;
  punkty: array[0..2] of array of TPoint;
  currentPoint: Integer = 0;
  currentLodyga: Integer = 0;
  koniczynaIndex: Integer = 0;
  lastUpdateTime: Double = 0; 

procedure InicjalizujKoniczyne;
var
  i, kat: Integer;
  phi, r, x, y: Double;
  cx, cy: SmallInt;
begin
  sX := GetScreenWidth div 2;
  sY := GetScreenHeight div 2;
  
  for i := 0 to 2 do
  begin
    case i of
      0: begin cx := sX - 100; cy := sY + 50; end;
      1: begin cx := sX;       cy := sY - 50; end;
      2: begin cx := sX + 100; cy := sY + 50; end;
    end;
    
    SetLength(punkty[i], 361);
    for kat := 0 to 360 do
    begin
      phi := kat * Pi / 180;
      r := 80 * Sin(2 * phi);
      x := r * Cos(phi) + cx;
      y := r * Sin(phi) + cy;
      punkty[i][kat].x := Round(x);
      punkty[i][kat].y := Round(y);
    end;
  end;
end;

procedure WypelnijKoniczyne(index: Integer; kolor: TColor);
var
  i: Integer;
  vertices: array of TInputVector;
begin
  SetLength(vertices, 361);
  for i := 0 to 360 do
  begin
    vertices[i] := NewVector(punkty[index][i].x, punkty[index][i].y);
  end;
  DrawPolygon(vertices, kolor, True);
end;

procedure Update(const dt: Double);
begin
  
  lastUpdateTime := lastUpdateTime + dt;
  
  if lastUpdateTime >= 0.005 then
  begin
    lastUpdateTime := 0;
    
    if currentPoint < 360 then
      Inc(currentPoint)
    else if currentLodyga < 100 then
      Inc(currentLodyga)
    else if koniczynaIndex < 2 then
    begin
      Inc(koniczynaIndex);
      currentPoint := 0;
      currentLodyga := 0;
    end;
  end;
  
  if IsKeyPressed(KEY_ESCAPE) then
    CloseWindow;
end;

procedure Draw(const dt: Double);
var
  i, j: Integer;
  kolory: array[0..2] of TColor;
  koloryLinii: array[0..2] of TColor;
  pozycje: array[0..2] of TPoint;
begin
  kolory[0] := COLOR_WHITE;
  kolory[1] := COLOR_BLUE;
  kolory[2] := COLOR_RED;
  
  koloryLinii[0] := COLOR_LIGHTGRAY;
  koloryLinii[1] := COLOR_YELLOW;
  koloryLinii[2] := COLOR_YELLOW;
  
  ClearBackground(COLOR_BLACK);
  
  pozycje[0].x := sX - 100; pozycje[0].y := sY + 50;
  pozycje[1].x := sX;       pozycje[1].y := sY - 50;
  pozycje[2].x := sX + 100; pozycje[2].y := sY + 50;
  
  for i := 0 to 2 do
  begin
    if i <= koniczynaIndex then
    begin
      if i = koniczynaIndex then
      begin
        for j := 1 to currentPoint do
        begin
          DrawLine(punkty[i][j-1].x, punkty[i][j-1].y, punkty[i][j].x, punkty[i][j].y, koloryLinii[i], 2);
        end;
      end
      else
      begin
        for j := 1 to 360 do
        begin
          DrawLine(punkty[i][j-1].x, punkty[i][j-1].y, punkty[i][j].x, punkty[i][j].y, koloryLinii[i], 2);
        end;
      end;
      
      if (i < koniczynaIndex) or ((i = koniczynaIndex) and (currentPoint = 360)) then
      begin
        WypelnijKoniczyne(i, kolory[i]);
      end;
      
      if (i = koniczynaIndex) and (currentPoint = 360) then
      begin
        DrawLine(pozycje[i].x, pozycje[i].y, pozycje[i].x, pozycje[i].y + currentLodyga, COLOR_GREEN, 3);
      end
      else if i < koniczynaIndex then
      begin
        DrawLine(pozycje[i].x, pozycje[i].y, pozycje[i].x, pozycje[i].y + 100, COLOR_GREEN, 3);
      end;
    end;
  end;
  
  DrawText('Nacisnij ESC aby wyjsc', 10, 10, 20, COLOR_WHITE);
  DrawText('Koniczyna: ' + IntToStr(koniczynaIndex + 1) + '/3', 10, 40, 16, COLOR_LIGHTGRAY);
  
end;

begin
  InitWindow(800, 600, 'Koniczyna - Prosta Wersja');
  SetTargetFPS(60);
  
  InicjalizujKoniczyne;
  Run(@Update, @Draw);
end.
