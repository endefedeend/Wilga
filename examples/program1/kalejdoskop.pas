program KalejdoskopWilga;

uses
  wilga, math;

const
  SZEROKOSC_EKRANU = 900;
  WYSOKOSC_EKRANU = 900;
  LICZBA_LUSTER = 6;
  LICZBA_KORALIKOW = 180;
  PREDKOSC_OBROTU = 0.7;
  OBSZAR_KORALIKOW = 450;
  STOPNIE_NA_RADIANY = Pi / 180;
  KOLOR_TLA: TColor = (r: 5; g: 5; b: 15; a: 255);
  KOLOR_SOCZEWKI: TColor = (r: 255; g: 255; b: 255; a: 30);
  SILA_DOSRODKOWA = 2.0;
  SILA_PRZYCIAGANIA = 0.5;

type
  TShapeType = (stCircle, stSquare, stTriangle);
  TKoralik = record
    pozycja, predkosc: TVector2;
    kolor: TColor;
    rozmiar: Integer;
    shape: TShapeType;
  end;

var
  koraliki: array[0..LICZBA_KORALIKOW-1] of TKoralik;
  kat: Double = 0;
  intensywnosc_wstrzasu: Double = 0.0;
  soczewka: TTexture;


function ClampF(x, lo, hi: Double): Double; inline;
begin
  if x < lo then Exit(lo);
  if x > hi then Exit(hi);
  Result := x;
end;


function RandomColor: TColor;
begin
  Result := ColorCreate(Random(200) + 55, Random(200) + 55, Random(200) + 55, 255);
end;

function RandomShape: TShapeType;
begin
  Result := TShapeType(Random(Ord(High(TShapeType)) + 1));
end;

procedure DrawShape(shape: TShapeType; position: TVector2; size: Integer; color: TColor; rotationDeg: Double);
var
  points: array[0..2] of TVector2;
  center, p1, p2, p3: TVector2;
  rot: Double;
begin
  rot := rotationDeg * STOPNIE_NA_RADIANY;
  case shape of
    stCircle:
      DrawCircleV(position, size, color);

    stSquare:
      DrawRectanglePro(
        RectangleCreate(position.x, position.y, size * 2, size * 2),
        Vector2Create(size, size),
        rot,
        color
      );

    stTriangle:
      begin
        center := position;
        points[0] := Vector2Create(0, -size);
        points[1] := Vector2Create(-size, size);
        points[2] := Vector2Create(size, size);

        p1 := Vector2Add(Vector2Rotate(points[0], rot), center);
        p2 := Vector2Add(Vector2Rotate(points[1], rot), center);
        p3 := Vector2Add(Vector2Rotate(points[2], rot), center);

        DrawTriangle(TriangleCreate(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y), color);
      end;
  end;
end;

procedure InicjalizujKoraliki;
var
  i: Integer;
  srodek, kierunek: TVector2;
  dlugosc: Double;
begin
  srodek := Vector2Create(SZEROKOSC_EKRANU / 2, WYSOKOSC_EKRANU / 2);

  for i := 0 to High(koraliki) do
  begin
    kierunek := Vector2Normalize(Vector2Create(Random(200) - 100, Random(200) - 100));
    dlugosc := Random(OBSZAR_KORALIKOW div 2) + 50;
    koraliki[i].pozycja := Vector2Add(srodek, Vector2Scale(kierunek, dlugosc));
    koraliki[i].predkosc := Vector2Zero();
    koraliki[i].kolor := RandomColor;
    koraliki[i].rozmiar := Random(8) + 4;
    koraliki[i].shape := RandomShape;
  end;
end;

procedure InicjalizujSoczewke;
var
  target: TRenderTexture2D;
begin
  target := LoadRenderTexture(200, 200);
  BeginTextureMode(target);
    ClearBackground(COLOR_TRANSPARENT());
    DrawCircleGradient(100, 100, 100, KOLOR_SOCZEWKI, COLOR_TRANSPARENT());
  EndTextureMode();
  soczewka := target.texture;
end;

procedure AktualizujKoraliki;
var
  i: Integer;
  srodek, doSrodka, kierunek: TVector2;
  odleglosc, sila: Double;
begin
  srodek := Vector2Create(SZEROKOSC_EKRANU / 2, WYSOKOSC_EKRANU / 2);

  for i := 0 to High(koraliki) do
  begin
    // Siła dośrodkowa
    doSrodka := Vector2Subtract(srodek, koraliki[i].pozycja);
    odleglosc := Vector2Length(doSrodka);

    if odleglosc > OBSZAR_KORALIKOW then
      sila := SILA_DOSRODKOWA
    else if odleglosc > OBSZAR_KORALIKOW * 0.7 then
      sila := SILA_PRZYCIAGANIA
    else
      sila := 0;

    if sila > 0 then
    begin
      kierunek := Vector2Scale(Vector2Normalize(doSrodka), sila);
      koraliki[i].predkosc := Vector2Add(koraliki[i].predkosc, kierunek);
    end;

    // Potrząsanie
    if intensywnosc_wstrzasu > 0 then
    begin
      koraliki[i].predkosc.x += (Random(100) - 50) * 0.02 * intensywnosc_wstrzasu;
      koraliki[i].predkosc.y += (Random(100) - 50) * 0.02 * intensywnosc_wstrzasu;
      intensywnosc_wstrzasu := ClampF(intensywnosc_wstrzasu - 0.02, 0.0, 1.0e9);
    end;

    // Tłumienie prędkości
    koraliki[i].predkosc := Vector2Scale(koraliki[i].predkosc, 0.98);

    // Aktualizacja pozycji
    koraliki[i].pozycja := Vector2Add(koraliki[i].pozycja, koraliki[i].predkosc);
  end;
end;

procedure RysujKalejdoskop;
var
  i, j: Integer;
  odbitaPozycja, srodek: TVector2;
  katSegmentu, aktualnyKat: Double;
  kolorSladu: TColor;
  rotRadian: Double;
begin
  katSegmentu := 360 / LICZBA_LUSTER;
  srodek := Vector2Create(SZEROKOSC_EKRANU / 2, WYSOKOSC_EKRANU / 2);

  for i := 0 to High(koraliki) do
  begin
    for j := 0 to LICZBA_LUSTER - 1 do
    begin
      aktualnyKat := katSegmentu * j + kat;
      rotRadian := aktualnyKat * STOPNIE_NA_RADIANY;

      // Odbicie pionowe względem środka
      odbitaPozycja := Vector2Create(
        koraliki[i].pozycja.x,
        2 * srodek.y - koraliki[i].pozycja.y
      );

      // Transformacja do układu współrzędnych lustra
      odbitaPozycja := Vector2Subtract(odbitaPozycja, srodek);
      odbitaPozycja := Vector2Rotate(odbitaPozycja, rotRadian);
      odbitaPozycja := Vector2Add(odbitaPozycja, srodek);

      kolorSladu := koraliki[i].kolor;

      // Rysowanie kształtu
      DrawShape(
        koraliki[i].shape,
        odbitaPozycja,
        koraliki[i].rozmiar,
        kolorSladu,
        aktualnyKat
      );
    end;
  end;

  // Rysowanie soczewki z tekstury
  DrawTexturePro(
    soczewka,
    RectangleCreate(0, 0, soczewka.width, -soczewka.height),
    RectangleCreate(srodek.x - 100, srodek.y - 100, 200, 200),
    Vector2Zero(),
    0,
    COLOR_WHITE()
  );
end;



procedure Update(const dt: Double);
begin

  kat += PREDKOSC_OBROTU * dt * 60; 
  if kat >= 360 then kat -= 360;

  if IsKeyPressed(KEY_SPACE) then
    intensywnosc_wstrzasu := 12.0;

  AktualizujKoraliki;
end;

procedure Draw(const dt: Double);
begin
  ClearBackground(KOLOR_TLA);
  RysujKalejdoskop;
  DrawText('Nacisnij SPACJE aby potrzasnac', 20, 20, 20, COLOR_WHITE());
  DrawFPS(20, 50, COLOR_WHITE());
end;

begin
  InitWindow(SZEROKOSC_EKRANU, WYSOKOSC_EKRANU, 'Git Kalejdoskop');
  SetTargetFPS(60);
  InicjalizujKoraliki;
  InicjalizujSoczewke;

  Run(@Update, @Draw);

  ReleaseTexture(soczewka);
end.
