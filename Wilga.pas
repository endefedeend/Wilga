unit wilga;
{$mode objfpc}{$H+} {$modeswitch advancedrecords}

{*
  Wilga — canvas 2D helper for pas2js (raylib-inspired)
*}

interface

uses JS, Web, SysUtils, Math;

 var
  gCtx: TJSCanvasRenderingContext2D; 
  GFontSize: Integer;
   GFontFamily: String = 'system-ui, sans-serif';
type

  TLineJoinKind = (ljMiter, ljRound, ljBevel);
  TLineCapKind  = (lcButt, lcRound, lcSquare);
TNoArgProc = procedure;
  // ====== PODSTAWOWE TYPY ======
  TColor = record
    r, g, b, a: Integer; 
    function Lighten(amount: Integer): TColor;
    function Darken(amount: Integer): TColor;
    function WithAlpha(newAlpha: Integer): TColor;
    function Blend(const other: TColor; factor: Double): TColor;
  end;

  TProfileEntry = record
    name: String;
    startTime: Double;
  end;

  TSoundHandle = Integer;

  TInputVector = record
    x, y: Double;
        constructor Create(x, y: Double); inline;
    function Add(const v: TInputVector): TInputVector;
    function Subtract(const v: TInputVector): TInputVector;
    function Scale(s: Double): TInputVector;
    function Length: Double;
    function Normalize: TInputVector;
    function Distance(const v: TInputVector): Double;
    function Lerp(const target: TInputVector; t: Double): TInputVector;
  end;

  TLineBatchItem = record
    startX, startY, endX, endY: Double;
    color: TColor;
    thickness: Integer;
  end;

  TLine = record
    startPoint, endPoint: TInputVector;
  end;

  TTriangle = record
    p1, p2, p3: TInputVector;
  end;

 
  TMatrix2D = record
    m0, m1, m2: Double;
    m3, m4, m5: Double;
    function Transform(v: TInputVector): TInputVector;
    function Multiply(const b: TMatrix2D): TMatrix2D;
    procedure ApplyToContext;
    function Invert: TMatrix2D;
  end;

  // Zgodność z Raylib: TVector2 = TInputVector
  TVector2 = TInputVector;

  TCamera2D = record
    target: TInputVector;
    offset: TInputVector;
    rotation: Double; 
    zoom: Double;
    function GetMatrix: TMatrix2D;
  end;

  TRectangle = record
    x, y, width, height: Double;


    constructor Create(x, y, w, h: Double); inline;
    class function FromCenter(cx, cy, w, h: Double): TRectangle; static; inline;

    function Move(dx, dy: Double): TRectangle;
    function Scale(sx, sy: Double): TRectangle;
    function Inflate(dx, dy: Double): TRectangle;
    function Contains(const point: TInputVector): Boolean;
    function Intersects(const other: TRectangle): Boolean;
    function GetCenter: TInputVector;
  end;


  TTexture = record
    canvas: TJSHTMLCanvasElement;
    width, height: Integer;
    loaded: Boolean;
  end;

  TRenderTexture2D = record
    texture: TTexture;
  end;


  TParticle = record
    position: TInputVector;
    velocity: TInputVector;
    color: TColor;
    life: Double;
    initialLife: Double; 
    size: Double;
    rotation: Double;
    angularVelocity: Double;
    startColor: TColor;  
endColor: TColor;    
  end;

  TParticleSystem = class
  private
    particles: array of TParticle;
    maxParticles: Integer;
  public
    constructor Create(maxCount: Integer);
  procedure Emit(pos: TInputVector; count: Integer; const aStartColor, aEndColor: TColor;
               minSize, maxSize, minLife, maxLife: Double);
    procedure Update(dt: Double);
    procedure Draw;
    function GetActiveCount: Integer;
  end;

  // Callback do asynchronicznego ładowania tekstur
  TOnTextureReady = reference to procedure (const tex: TTexture);


  // ====== LOOP W STYLU „DT” ======
  TDeltaProc = procedure(const dt: Double);

{ ====== FUNKCJE POMOCNICZE ====== }
function GetScreenWidth: Integer;
function GetScreenHeight: Integer;
function GetMouseX: Integer;
function GetMouseY: Integer;
function GetFrameTime: Double;
function GetFPS: Integer;
function GetDeltaTime: Double;


function ColorToCanvasRGBA(const c: TColor): String;

// Ustawienia wydajności / jakości
procedure SetHiDPI(enabled: Boolean);
procedure SetCanvasAlpha(enabled: Boolean);
procedure SetImageSmoothing(enabled: Boolean);
procedure SetClearFast(enabled: Boolean);
procedure Clear(const color: TColor);

{ ====== CLIP / RYSOWANIE USTAWIENIA ====== }
procedure BeginScissor(x, y, w, h: Integer);
procedure EndScissor;
procedure SetLineJoin(const joinKind: String); // 'miter'|'round'|'bevel'
procedure SetLineCap(const capKind: String);   // 'butt'|'round'|'square'

procedure SetLineJoin(const joinKind: TLineJoinKind); overload;
procedure SetLineCap(const capKind: TLineCapKind); overload;


{ ====== RYSOWANIE KSZTAŁTÓW ====== }
// Poprawione deklaracje procedur
procedure DrawRectangleRounded(x, y, w, h, radius: double; const color: TColor; filled: Boolean = True);
procedure DrawRectangleRoundedRec(const rec: TRectangle; radius: Double; const color: TColor; filled: Boolean = True);
procedure DrawLine(startX, startY, endX, endY: Integer; const color: TColor; thickness: Integer = 1);
procedure DrawLineV(startPos, endPos: TInputVector; const color: TColor; thickness: Integer = 1);
procedure DrawTriangle(const tri: TTriangle; const color: TColor; filled: Boolean = True);
procedure DrawTriangleLines(const tri: TTriangle; const color: TColor; thickness: Integer = 1);
procedure DrawRectangleLines(x, y, w, h: double; const color: TColor; thickness: Integer = 1);
procedure DrawSquare(x, y, size: double; const color: TColor);
procedure DrawSquareLines(x, y, size: double; const color: TColor; thickness: Integer = 1);
procedure DrawSquareFromCenter(cx, cy, size: double; const color: TColor);
procedure DrawSquareFromCenterLines(cx, cy, size: double; const color: TColor; thickness: Integer = 1);

// Obrys zaokrąglonego prostokąta z kontrolą grubości
procedure DrawRectangleRoundedStroke(x, y, w, h, radius: double; const color: TColor; thickness: Integer = 1);
procedure DrawRectangleRoundedRecStroke(const rec: TRectangle; radius: Double; const color: TColor; thickness: Integer = 1);

// Batch obrysów prostokątów
procedure BeginRectStrokeBatch(const color: TColor; thickness: Integer = 1);
procedure BatchRectStroke(x, y, w, h: Integer);
procedure EndRectStrokeBatch;

// Batch rysowania prostokątów
procedure BeginRectBatch(const color: TColor);
procedure BatchRect(x, y, w, h: Integer);
procedure EndRectBatchFill;

// Batch rysowania linii
procedure BeginLineBatch;
procedure BatchLine(aStartX, aStartY, aEndX, aEndY: Double; const aColor: TColor; aThickness: Integer = 1);
procedure BatchLineV(const aStartPos, aEndPos: TInputVector; const aColor: TColor; aThickness: Integer = 1);
procedure EndLineBatch;

// Szybka seria prostokątów
procedure BeginRectSeries(const color: TColor);
procedure RectFill(x, y, w, h: Integer);
procedure EndRectSeries;

{ ====== TRANSFORMACJE I MACIERZE ====== }
function MatrixIdentity: TMatrix2D;
function MatrixTranslate(tx, ty: Double): TMatrix2D;
function MatrixRotate(radians: Double): TMatrix2D;
function MatrixRotateDeg(deg: Double): TMatrix2D;
function MatrixScale(sx, sy: Double): TMatrix2D;
function MatrixMultiply(const a, b: TMatrix2D): TMatrix2D;
function Vector2Transform(v: TInputVector; mat: TMatrix2D): TInputVector;

// Memory pooling
function GetVectorFromPool(x, y: Double): TInputVector;
procedure ReturnVectorToPool(var v: TInputVector);
function GetMatrixFromPool: TMatrix2D;
procedure ReturnMatrixToPool(var mat: TMatrix2D);

{ ====== KAMERA ====== }
function DefaultCamera: TCamera2D;
procedure BeginMode2D(const camera: TCamera2D);
procedure EndMode2D;
function ScreenToWorld(p: TVector2; const cam: TCamera2D): TVector2;
function WorldToScreen(p: TVector2; const cam: TCamera2D): TVector2;

{ ====== KOLIZJE ====== }
function CheckCollisionPointRec(point: TInputVector; const rec: TRectangle): Boolean;
function CheckCollisionCircles(center1: TInputVector; radius1: Double;
                              center2: TInputVector; radius2: Double): Boolean;
function CheckCollisionCircleRec(center: TInputVector; radius: Double; const rec: TRectangle): Boolean;
function CheckCollisionRecs(const a, b: TRectangle): Boolean;
function CheckCollisionPointCircle(point, center: TInputVector; radius: Double): Boolean;
function CheckCollisionPointPoly(point: TInputVector; const points: array of TInputVector): Boolean;
function CheckCollisionLineLine(a1, a2, b1, b2: TInputVector): Boolean;
function CheckCollisionLineRec(const line: TLine; const rec: TRectangle): Boolean;
function LinesIntersect(p1, p2, p3, p4: TInputVector; out t, u: Double): Boolean;

{ ====== OBRAZY ====== }
procedure LoadImageFromURL(const url: String; OnReady: TOnTextureReady); overload;
function  LoadImageFromURL(const url: String): TTexture; overload;
procedure DrawTexture(const tex: TTexture; x, y: Integer; const tint: TColor);
procedure DrawTextureV(const tex: TTexture; position: TInputVector; const tint: TColor);
procedure DrawTexturePro(const tex: TTexture; const src, dst: TRectangle; origin: TVector2; rotationDeg: Double; const tint: TColor);
function  TextureIsReady(const tex: TTexture): Boolean;

{ ====== ZDARZENIA MYSZY ====== }
function GetMouseWheelMove: Integer;
function IsMouseButtonDown(button: Integer): Boolean;
function IsMouseButtonPressed(button: Integer): Boolean;
function IsMouseButtonReleased(button: Integer): Boolean;
function GetMousePosition: TInputVector;
function GetMouseDelta: TInputVector;

{ ====== CZAS ====== }
procedure WaitTime(ms: Double); // Uwaga: busy-wait (debug only)
function GetTime: Double;

{ ====== MATEMATYKA ====== }
function Lerp(start, stop, amount: Double): Double;
function Normalize(value, start, stop: Double): Double;
function Map(value, inStart, inStop, outStart, outStop: Double): Double;
function Clamp(value, minVal, maxVal: Double): Double;
function Max(a, b: Double): Double;
function Min(a, b: Double): Double;
function MaxI(a, b: Integer): Integer;
function MinI(a, b: Integer): Integer;
function ClampI(value, minVal, maxVal: Integer): Integer;
function SmoothStep(edge0, edge1, x: Double): Double;
function Approach(current, target, delta: Double): Double;

{ ====== DŹWIĘK ====== }
function  LoadSoundEx(const url: String; voices: Integer = 4; volume: Double = 1.0; looped: Boolean = False): TSoundHandle;
procedure UnloadSoundEx(handle: TSoundHandle);
procedure PlaySoundEx(handle: TSoundHandle); overload;
procedure PlaySoundEx(handle: TSoundHandle; volume: Double); overload;
procedure StopSoundEx(handle: TSoundHandle);
procedure SetSoundVolume(handle: TSoundHandle; volume: Double);
procedure SetSoundLoop(handle: TSoundHandle; looped: Boolean);
function PlaySound(const url: String): Boolean;
function PlaySoundLoop(const url: String): Boolean;
procedure StopAllSounds;

{ ====== FABRYKI ====== }
function NewVector(ax, ay: Double): TInputVector;
function Vector2Create(x, y: Double): TInputVector;
function ColorRGBA(ar, ag, ab, aa: Integer): TColor;
function ColorCreate(r, g, b, a: Integer): TColor;
function RectangleCreate(x, y, width, height: Double): TRectangle;
function LineCreate(startX, startY, endX, endY: Double): TLine;
function TriangleCreate(p1x, p1y, p2x, p2y, p3x, p3y: Double): TTriangle;
function ColorFromHex(const hex: String): TColor;
function RandomColor(minBrightness: Integer = 0; maxBrightness: Integer = 255): TColor;
function ColorEquals(const c1, c2: TColor): Boolean;

{ ====== WEKTORY ====== }
function Vector2Zero: TInputVector;
function Vector2One: TInputVector;
function Vector2Add(v1, v2: TInputVector): TInputVector;
function Vector2Subtract(v1, v2: TInputVector): TInputVector;
function Vector2Scale(v: TInputVector; scale: Double): TInputVector;
function Vector2Length(v: TInputVector): Double;
function Vector2Normalize(v: TInputVector): TInputVector;
function Vector2Rotate(v: TInputVector; radians: Double): TInputVector;
function Vector2RotateDeg(v: TInputVector; deg: Double): TInputVector;
function Vector2Dot(a, b: TInputVector): Double;
function Vector2Perp(v: TInputVector): TInputVector;
function Vector2Lerp(a, b: TInputVector; t: Double): TInputVector;
function Vector2Distance(v1, v2: TInputVector): Double;
function Vector2Angle(v1, v2: TInputVector): Double;

{ ====== OKNO / PĘTLA ====== }
procedure InitWindow(aWidth, aHeight: Integer; const title: String);
procedure CloseWindow;
procedure SetFPS(fps: Integer);
procedure SetTargetFPS(fps: Integer);
procedure DrawFPS(x, y: Integer; color: TColor);
function WindowShouldClose: Boolean;
procedure SetCloseOnEscape(enable: Boolean);
function GetCloseOnEscape: Boolean;

procedure SetWindowSize(width, height: Integer);
procedure SetWindowTitle(const title: String);
procedure ToggleFullscreen;

{ ====== RYSOWANIE ====== }
procedure BeginDrawing;
procedure EndDrawing;
procedure ClearBackground(const color: TColor);
procedure ClearFast(const color: TColor);
procedure DrawRectangle(x, y, w, h: double; const color: TColor);
procedure DrawRectangleRec(const rec: TRectangle; const color: TColor);
procedure DrawCircle(cx, cy, radius: double; const color: TColor);
procedure DrawCircleV(center: TInputVector; radius: double; const color: TColor);
procedure DrawCircleLines(cx, cy, radius, thickness: double; const color: TColor);

procedure DrawTextWithFont(const text: String; x, y, size: Integer; const family: String; const color: TColor);
function  MeasureTextWidthWithFont(const text: String; size: Integer; const family: String): Double;
function  MeasureTextHeightWithFont(const text: String; size: Integer; const family: String): Double;
procedure DrawText(const text: String; x, y, size: Integer; const color: TColor);
function  MeasureTextWidth(const text: String; size: Integer): Double;
function  MeasureTextHeight(const text: String; size: Integer): Double;
procedure SetTextFont(const cssFont: String);
procedure SetTextAlign(const hAlign: String; const vAlign: String);
procedure DrawTextCentered(const text: String; cx, cy, size: Integer; const color: TColor);
procedure DrawTextPro(const text: String; x, y, size: Integer; const color: TColor;
                     rotation: Double; originX, originY: Double);
procedure ApplyFont;
function BuildFontString(const sizePx: Integer; const family: String = ''): String;
procedure EnsureFont(const sizePx: Integer; const family: String = ''); 
procedure SetFontSize(const sizePx: Integer); 
procedure SetFontFamily(const family: String);                 
// === Tekstury ===

// Rysowanie z pozycją, skalą, rotacją i tintem
procedure DrawTextureEx(const tex: TTexture; position: TVector2; scale: Double; rotation: Double; const tint: TColor);

// Rysowanie wycinka tekstury (source rectangle)
procedure DrawTextureRec(const tex: TTexture; const src: TRectangle; position: TVector2; const tint: TColor);

// Rysowanie powtarzającej się tekstury na obszarze (tiling)
procedure DrawTextureTiled(const tex: TTexture; const src, dst: TRectangle; origin: TVector2; rotation: Double; scale: Double; const tint: TColor);

// Rysowanie z originem w proporcjach (0..1)
procedure DrawTextureProRelOrigin(const tex: TTexture; const src, dst: TRectangle; originRel: TVector2; rotation: Double; const tint: TColor);

// Rysowanie ramki z atlasu po indeksie
procedure DrawAtlasFrame(const tex: TTexture; frameIndex, frameWidth, frameHeight: Integer; position: TVector2; const tint: TColor);


// === Tekst ===

// Proste rysowanie tekstu w punkcie
procedure DrawTextSimple(const text: String; pos: TVector2; fontSize: Integer; const color: TColor);

// Rysowanie tekstu wyśrodkowanego względem punktu
procedure DrawTextCentered(const text: String; center: TVector2; fontSize: Integer; const color: TColor);

// Rysowanie tekstu wyrównanego do prawej
procedure DrawTextRightAligned(const text: String; rightPos: TVector2; fontSize: Integer; const color: TColor);

// Tekst z obramowaniem (outline)
procedure DrawTextOutline(const text: String; pos: TVector2; fontSize: Integer; const color, outlineColor: TColor; thickness: Integer);

// Tekst z cieniem
procedure DrawTextShadow(const text: String; pos: TVector2; fontSize: Integer; const color, shadowColor: TColor; shadowOffset: TVector2);

// Tekst w ramce (word wrap)
procedure DrawTextBoxed(const text: String; pos: TVector2; boxWidth: Integer;
  fontSize: Integer; const textColor: TColor; lineSpacing: Integer;
  const borderColor: TColor; borderThickness: Integer);
// Tekst na okręgu
procedure DrawTextOnCircle(const text: String; center: TVector2; radius: Double; startAngle: Double; fontSize: Integer; const color: TColor);

// Tekst z gradientem (prosty poziomy)
procedure DrawTextGradient(const text: String; pos: TVector2; fontSize: Integer; const color1, color2: TColor);

procedure DrawTextOutlineAdv(const text: String; pos: TVector2; fontSize: Integer; const color, outlineColor: TColor; thickness: Integer);
// --- Wielokąty / polilinie ---
procedure DrawPolyline(const pts: array of TInputVector; const color: TColor; thickness: Integer = 1; closed: Boolean = False);
procedure DrawPolygon(const pts: array of TInputVector; const color: TColor; filled: Boolean = True);

// --- Łuki / wycinki ---
procedure DrawArc(cx, cy, r: Double; startDeg, endDeg: Double; const color: TColor; thickness: Integer = 1);
procedure DrawRing(cx, cy, rInner, rOuter, startDeg, endDeg: Double; const color: TColor);
procedure DrawSector(cx, cy, r: Double; startDeg, endDeg: Double; const color: TColor);

// --- Linie kreskowane ---
procedure DrawDashedLine(x1, y1, x2, y2: Double; const color: TColor; thickness: Integer; dashLen, gapLen: Double);
procedure SetLineDash(const dashes: array of Double);
procedure ClearLineDash;

// --- Gradient prostokątny ---
procedure FillRectLinearGradient(const rec: TRectangle; const c0, c1: TColor; angleDeg: Double);

// --- Tekst z obrysem ---
procedure DrawTextOutline(const text: String; x, y, size: Integer; const fillColor, outlineColor: TColor; outlinePx: Integer);

// --- Clip dowolnym path ---
procedure BeginPathClip(const BuildPath: TNoArgProc);
procedure EndClip;
procedure DrawRectangleProDeg(const rec: TRectangle; origin: TVector2; rotationDeg: Double; const color: TColor);
procedure DrawPolyDeg(center: TVector2; sides: Integer; radius: Double; rotationDeg: Double; const color: TColor);
procedure DrawRectanglePro(const rec: TRectangle; origin: TVector2; rotation: Double; const color: TColor);
procedure DrawPoly(center: TVector2; sides: Integer; radius: Double; rotation: Double; const color: TColor);
procedure DrawCircleGradient(cx, cy: Integer; radius: Integer; const inner, outer: TColor);
procedure DrawEllipse(cx, cy, rx, ry: Integer; const color: TColor);
procedure DrawEllipseLines(cx, cy, rx, ry, thickness: Integer; const color: TColor);
procedure DrawEllipseV(center: TInputVector; radiusX, radiusY: Double; const color: TColor);
function RectangleFromCenter(cx, cy, w, h: Double): TRectangle;
function RectCenter(const R: TRectangle): TVector2;
{ ====== TEKSTURY ====== }
function LoadRenderTexture(w, h: Integer): TRenderTexture2D;
procedure BeginTextureMode(const rt: TRenderTexture2D);
procedure EndTextureMode;
function CreateTextureFromCanvas(canvas: TJSHTMLCanvasElement): TTexture;
procedure ReleaseTexture(var tex: TTexture);
procedure ReleaseRenderTexture(var rtex: TRenderTexture2D);

{ ====== WEJŚCIE ====== }
function IsKeyPressed(const code: String): Boolean; overload;
function IsKeyPressed(keyCode: Integer): Boolean; overload;
function IsKeyDown(const code: String): Boolean; overload;
function IsKeyDown(keyCode: Integer): Boolean; overload;
function IsKeyReleased(const code: String): Boolean; overload;
function IsKeyReleased(keyCode: Integer): Boolean; overload;
function GetKeyPressed: String;
function GetCharPressed: String;
function GetAllPressedKeys: Array of String; // Zamiast: array of String
procedure ClearAllKeys;
function KeyCodeToCode(keyCode: Integer): String;

{ ====== PROFILER ====== }
procedure BeginProfile(const name: String);
procedure EndProfile(const name: String);
function GetProfileData: String;
procedure ResetProfileData;

{ ====== PARTICLE SYSTEM ====== }
function CreateParticleSystem(maxParticles: Integer): TParticleSystem;
procedure DrawParticles(particleSystem: TParticleSystem);
procedure UpdateParticles(particleSystem: TParticleSystem; dt: Double);

{ ====== LOOP ====== }
procedure Run(UpdateProc: TDeltaProc);
procedure Run(UpdateProc: TDeltaProc; DrawProc: TDeltaProc);


// push pop
procedure Push; inline;
procedure Pop;  inline;


{ ====== KOLORY ====== }
{ ====== Deklaracje kolorów ====== }
function COLOR_ALICEBLUE: TColor;
function COLOR_ANTIQUEWHITE: TColor;
function COLOR_AQUA: TColor;
function COLOR_AQUAMARINE: TColor;
function COLOR_AZURE: TColor;
function COLOR_BEIGE: TColor;
function COLOR_BISQUE: TColor;
function COLOR_BLACK: TColor;
function COLOR_BLANCHEDALMOND: TColor;
function COLOR_BLUE: TColor;
function COLOR_BLUEVIOLET: TColor;
function COLOR_BROWN: TColor;
function COLOR_BURLYWOOD: TColor;
function COLOR_CADETBLUE: TColor;
function COLOR_CHARTREUSE: TColor;
function COLOR_CHOCOLATE: TColor;
function COLOR_CORAL: TColor;
function COLOR_CORNFLOWERBLUE: TColor;
function COLOR_CORNSILK: TColor;
function COLOR_CRIMSON: TColor;
function COLOR_CYAN: TColor;
function COLOR_DARKBLUE: TColor;
function COLOR_DARKCYAN: TColor;
function COLOR_DARKGOLDENROD: TColor;
function COLOR_DARKGRAY: TColor;
function COLOR_DARKGREY: TColor;
function COLOR_DARKGREEN: TColor;
function COLOR_DARKKHAKI: TColor;
function COLOR_DARKMAGENTA: TColor;
function COLOR_DARKOLIVEGREEN: TColor;
function COLOR_DARKORANGE: TColor;
function COLOR_DARKORCHID: TColor;
function COLOR_DARKRED: TColor;
function COLOR_DARKSALMON: TColor;
function COLOR_DARKSEAGREEN: TColor;
function COLOR_DARKSLATEBLUE: TColor;
function COLOR_DARKSLATEGRAY: TColor;
function COLOR_DARKSLATEGREY: TColor;
function COLOR_DARKTURQUOISE: TColor;
function COLOR_DARKVIOLET: TColor;
function COLOR_DEEPPINK: TColor;
function COLOR_DEEPSKYBLUE: TColor;
function COLOR_DIMGRAY: TColor;
function COLOR_DIMGREY: TColor;
function COLOR_DODGERBLUE: TColor;
function COLOR_FIREBRICK: TColor;
function COLOR_FLORALWHITE: TColor;
function COLOR_FORESTGREEN: TColor;
function COLOR_FUCHSIA: TColor;
function COLOR_GAINSBORO: TColor;
function COLOR_GHOSTWHITE: TColor;
function COLOR_GOLD: TColor;
function COLOR_GOLDENROD: TColor;
function COLOR_GRAY: TColor;
function COLOR_GREY: TColor;
function COLOR_GREEN: TColor;
function COLOR_GREENYELLOW: TColor;
function COLOR_HONEYDEW: TColor;
function COLOR_HOTPINK: TColor;
function COLOR_INDIANRED: TColor;
function COLOR_INDIGO: TColor;
function COLOR_IVORY: TColor;
function COLOR_KHAKI: TColor;
function COLOR_LAVENDER: TColor;
function COLOR_LAVENDERBLUSH: TColor;
function COLOR_LAWNGREEN: TColor;
function COLOR_LEMONCHIFFON: TColor;
function COLOR_LIGHTBLUE: TColor;
function COLOR_LIGHTCORAL: TColor;
function COLOR_LIGHTCYAN: TColor;
function COLOR_LIGHTGOLDENRODYELLOW: TColor;
function COLOR_LIGHTGRAY: TColor;
function COLOR_LIGHTGREY: TColor;
function COLOR_LIGHTGREEN: TColor;
function COLOR_LIGHTPINK: TColor;
function COLOR_LIGHTSALMON: TColor;
function COLOR_LIGHTSEAGREEN: TColor;
function COLOR_LIGHTSKYBLUE: TColor;
function COLOR_LIGHTSLATEGRAY: TColor;
function COLOR_LIGHTSLATEGREY: TColor;
function COLOR_LIGHTSTEELBLUE: TColor;
function COLOR_LIGHTYELLOW: TColor;
function COLOR_LIME: TColor;
function COLOR_LIMEGREEN: TColor;
function COLOR_LINEN: TColor;
function COLOR_MAGENTA: TColor;
function COLOR_MAROON: TColor;
function COLOR_MEDIUMAQUAMARINE: TColor;
function COLOR_MEDIUMBLUE: TColor;
function COLOR_MEDIUMORCHID: TColor;
function COLOR_MEDIUMPURPLE: TColor;
function COLOR_MEDIUMSEAGREEN: TColor;
function COLOR_MEDIUMSLATEBLUE: TColor;
function COLOR_MEDIUMSPRINGGREEN: TColor;
function COLOR_MEDIUMTURQUOISE: TColor;
function COLOR_MEDIUMVIOLETRED: TColor;
function COLOR_MIDNIGHTBLUE: TColor;
function COLOR_MINTCREAM: TColor;
function COLOR_MISTYROSE: TColor;
function COLOR_MOCCASIN: TColor;
function COLOR_NAVAJOWHITE: TColor;
function COLOR_NAVY: TColor;
function COLOR_OLDLACE: TColor;
function COLOR_OLIVE: TColor;
function COLOR_OLIVEDRAB: TColor;
function COLOR_ORANGE: TColor;
function COLOR_ORANGERED: TColor;
function COLOR_ORCHID: TColor;
function COLOR_PALEGOLDENROD: TColor;
function COLOR_PALEGREEN: TColor;
function COLOR_PALETURQUOISE: TColor;
function COLOR_PALEVIOLETRED: TColor;
function COLOR_PAPAYAWHIP: TColor;
function COLOR_PEACHPUFF: TColor;
function COLOR_PERU: TColor;
function COLOR_PINK: TColor;
function COLOR_PLUM: TColor;
function COLOR_POWDERBLUE: TColor;
function COLOR_PURPLE: TColor;
function COLOR_REBECCAPURPLE: TColor;
function COLOR_RED: TColor;
function COLOR_ROSYBROWN: TColor;
function COLOR_ROYALBLUE: TColor;
function COLOR_SADDLEBROWN: TColor;
function COLOR_SALMON: TColor;
function COLOR_SANDYBROWN: TColor;
function COLOR_SEAGREEN: TColor;
function COLOR_SEASHELL: TColor;
function COLOR_SIENNA: TColor;
function COLOR_SILVER: TColor;
function COLOR_SKYBLUE: TColor;
function COLOR_SLATEBLUE: TColor;
function COLOR_SLATEGRAY: TColor;
function COLOR_SLATEGREY: TColor;
function COLOR_SNOW: TColor;
function COLOR_SPRINGGREEN: TColor;
function COLOR_STEELBLUE: TColor;
function COLOR_TAN: TColor;
function COLOR_TEAL: TColor;
function COLOR_THISTLE: TColor;
function COLOR_TOMATO: TColor;
function COLOR_TURQUOISE: TColor;
function COLOR_VIOLET: TColor;
function COLOR_WHEAT: TColor;
function COLOR_WHITE: TColor;
function COLOR_WHITESMOKE: TColor;
function COLOR_YELLOW: TColor;
function COLOR_YELLOWGREEN: TColor;
function COLOR_TRANSPARENT : TColor;


  {$ifdef WILGA_DEBUG}
function DumpLeakReport: String;
procedure DebugResetCounters;
{$endif}

// --- deklaracje (w interface) ---
procedure WaitTextureReady(const tex: TTexture; const OnReady, OnTimeout: TNoArgProc; msTimeout: Integer = 10000);
procedure WaitAllTexturesReady(const arr: array of TTexture; const OnReady: TNoArgProc);

const
  KEY_SPACE  = 'Space';
  KEY_ESCAPE = 'Escape';
  KEY_ENTER  = 'Enter';
  KEY_TAB    = 'Tab';
  KEY_LEFT   = 'ArrowLeft';
  KEY_RIGHT  = 'ArrowRight';
  KEY_UP     = 'ArrowUp';
  KEY_DOWN   = 'ArrowDown';
  KEY_SHIFT  = 'ShiftLeft';
  KEY_BACKSPACE = 'Backspace';
  KEY_DELETE    = 'Delete';
  KEY_INSERT    = 'Insert';
  KEY_HOME      = 'Home';
  KEY_END       = 'End';
  KEY_PAGEUP    = 'PageUp';
  KEY_PAGEDOWN  = 'PageDown';
  KEY_F1        = 'F1';
  KEY_F2        = 'F2';
  KEY_F3        = 'F3';
  KEY_F4        = 'F4';
  KEY_F5        = 'F5';
  KEY_F6        = 'F6';
  KEY_F7        = 'F7';
  KEY_F8        = 'F8';
  KEY_F9        = 'F9';
  KEY_F10       = 'F10';
  KEY_F11       = 'F11';
  KEY_F12       = 'F12';
  KEY_CONTROL   = 'ControlLeft';
  KEY_ALT       = 'AltLeft';
  KEY_META      = 'MetaLeft';
  KEY_CONTEXT   = 'ContextMenu';
  KEY_BACKQUOTE   = 'Backquote';
  KEY_MINUS       = 'Minus';
  KEY_EQUAL       = 'Equal';
  KEY_BRACKETLEFT = 'BracketLeft';
  KEY_BRACKETRIGHT= 'BracketRight';
  KEY_BACKSLASH   = 'Backslash';
  KEY_SEMICOLON   = 'Semicolon';
  KEY_QUOTE       = 'Quote';
  KEY_COMMA       = 'Comma';
  KEY_PERIOD      = 'Period';
  KEY_SLASH       = 'Slash';
  // Litery A..Z
  KEY_A = 'KeyA';
  KEY_B = 'KeyB';
  KEY_C = 'KeyC';
  KEY_D = 'KeyD';
  KEY_E = 'KeyE';
  KEY_F = 'KeyF';
  KEY_G = 'KeyG';
  KEY_H = 'KeyH';
  KEY_I = 'KeyI';
  KEY_J = 'KeyJ';
  KEY_K = 'KeyK';
  KEY_L = 'KeyL';
  KEY_M = 'KeyM';
  KEY_N = 'KeyN';
  KEY_O = 'KeyO';
  KEY_P = 'KeyP';
  KEY_Q = 'KeyQ';
  KEY_R = 'KeyR';
  KEY_S = 'KeyS';
  KEY_T = 'KeyT';
  KEY_U = 'KeyU';
  KEY_V = 'KeyV';
  KEY_W = 'KeyW';
  KEY_X = 'KeyX';
  KEY_Y = 'KeyY';
  KEY_Z = 'KeyZ';

  // Górny rząd cyfr 0..9
  KEY_0 = 'Digit0';
  KEY_1 = 'Digit1';
  KEY_2 = 'Digit2';
  KEY_3 = 'Digit3';
  KEY_4 = 'Digit4';
  KEY_5 = 'Digit5';
  KEY_6 = 'Digit6';
  KEY_7 = 'Digit7';
  KEY_8 = 'Digit8';
  KEY_9 = 'Digit9';

  // Numpad
  KEY_NUMPAD0     = 'Numpad0';
  KEY_NUMPAD1     = 'Numpad1';
  KEY_NUMPAD2     = 'Numpad2';
  KEY_NUMPAD3     = 'Numpad3';
  KEY_NUMPAD4     = 'Numpad4';
  KEY_NUMPAD5     = 'Numpad5';
  KEY_NUMPAD6     = 'Numpad6';
  KEY_NUMPAD7     = 'Numpad7';
  KEY_NUMPAD8     = 'Numpad8';
  KEY_NUMPAD9     = 'Numpad9';
  KEY_NUMPAD_ADD      = 'NumpadAdd';
  KEY_NUMPAD_SUBTRACT = 'NumpadSubtract';
  KEY_NUMPAD_MULTIPLY = 'NumpadMultiply';
  KEY_NUMPAD_DIVIDE   = 'NumpadDivide';
  KEY_NUMPAD_DECIMAL  = 'NumpadDecimal';
// === DODAJ TO W INTERFACE (poza rekordem) ===
function TRectangleCreate(x, y, w, h: Double): TRectangle; inline;

implementation


function LineJoinToStr(k: TLineJoinKind): String; inline;
begin
  case k of
    ljMiter: Result := 'miter';
    ljRound: Result := 'round';
  else
    Result := 'bevel';
  end;
end;

function LineCapToStr(k: TLineCapKind): String; inline;
begin
  case k of
    lcButt:   Result := 'butt';
    lcRound:  Result := 'round';
  else
    Result := 'square';
  end;
end;

var
  gTimeAccum: Double = 0.0;
// --- Pixel-snapping kamery ---
gCamActive: Boolean = False;  // czy jesteśmy wewnątrz BeginMode2D/EndMode2D
gCamZoom:   Double  = 1.0;    // bieżący zoom kamery (dla snapowania obiektów)


  // Timing
  gLastTime: Double = 0;
  gLastDt:   Double = 0;
  gStartTime: Double = 0;

  // Canvas / kontekst
  gUseClearFast: Boolean = False;
  gCanvas: TJSHTMLCanvasElement;
  //gCtx: TJSCanvasRenderingContext2D;
  gDPR: Double = 1.0;
  gUseHiDPI: Boolean = false;
  gCanvasAlpha: Boolean = False;
  gImageSmoothingWanted: Boolean = True;

  // Input
  gKeys: TJSObject;
  gKeysPressed: TJSObject;
  gKeysReleased: TJSObject;// Zamiast: array of String

  gMouseButtonsDown: array[0..2] of Boolean;
  gMouseButtonsPrev: array[0..2] of Boolean;
  gMouseWheelDelta: Integer = 0;
  gMousePos: TInputVector;
  gMousePrevPos: TInputVector;

  // Loop
  gRunning: Boolean = false;
  gCurrentUpdate: TDeltaProc = nil;
  gCurrentDraw: TDeltaProc = nil;

  // Render-target stos
  gCtxStack: array of TJSCanvasRenderingContext2D;
  gCanvasStack: array of TJSHTMLCanvasElement;

  // FPS
  gTargetFPS: Integer = 60;
  gLastFpsTime: Double = 0;
  gFrameCount: Integer = 0;
  gCurrentFps: LongInt = 0;

  // Zamknięcie okna
  gWantsClose: Boolean = false;  

    gCloseOnEscape: Boolean = false; 

  // Batch rendering
  gLineBatchActive: Boolean = False;
  gLineBatch: array of TLineBatchItem;

  // Memory pooling
  gVectorPool: array of TInputVector;
  gMatrixPool: array of TMatrix2D;

  // Profiler
  gProfileStack: array of TProfileEntry;
  gProfileData: TJSObject;

  // Sound
  gActiveSounds: array of TJSHTMLAudioElement;

  // Particle systems
  gParticleSystems: array of TParticleSystem;
  

  onKeyDownH: TJSEventHandler;
  onKeyUpH:   TJSEventHandler;

  onMouseMoveH: TJSEventHandler;
  onMouseDownH: TJSEventHandler;
  onMouseUpH:   TJSEventHandler;

  onWheelH: TJSEventHandler;

  onTouchStartH: TJSRawEventHandler;
  onTouchMoveH:  TJSRawEventHandler;
  onTouchEndH:   TJSRawEventHandler;

  onBlurH:  TJSEventHandler;
  onClickH: TJSEventHandler;
  // Offscreen do tintowania tekstur
  gTintCanvas: TJSHTMLCanvasElement;
  gTintCtx: TJSCanvasRenderingContext2D;
{$ifdef WILGA_DEBUG}
var
  dbg_TexturesAlive: Integer = 0;
  dbg_RenderTexturesAlive: Integer = 0;
  dbg_AudioElemsAlive: Integer = 0;

procedure DBG_Inc(var c: Integer); inline; begin Inc(c); end;
procedure DBG_Dec(var c: Integer); inline; begin if c>0 then Dec(c); end;

procedure DebugResetCounters;
begin
  dbg_TexturesAlive := 0;
  dbg_RenderTexturesAlive := 0;
  dbg_AudioElemsAlive := 0;
end;

function DumpLeakReport: String;
begin
  Result :=
    'Wilga leak report:'#10 +
    Format('  Textures alive: %d'#10, [dbg_TexturesAlive]) +
    Format('  RenderTextures alive: %d'#10, [dbg_RenderTexturesAlive]) +
    Format('  Audio elements alive: %d'#10, [dbg_AudioElemsAlive]);
end;
{$endif}

{ ====== IMPLEMENTACJA TInputVector ====== }
function TInputVector.Add(const v: TInputVector): TInputVector;
begin
  Result := NewVector(x + v.x, y + v.y);
end;

function TInputVector.Subtract(const v: TInputVector): TInputVector;
begin
  Result := NewVector(x - v.x, y - v.y);
end;

function TInputVector.Scale(s: Double): TInputVector;
begin
  Result := NewVector(x * s, y * s);
end;

function TInputVector.Length: Double;
begin
  Result := Sqrt(x*x + y*y);
end;

function TInputVector.Normalize: TInputVector;
var len: Double;
begin
  len := Length;
  if len > 0 then Result := Scale(1.0/len) else Result := Vector2Zero;
end;

function TInputVector.Distance(const v: TInputVector): Double;
begin
  Result := Sqrt(Sqr(x - v.x) + Sqr(y - v.y));
end;

function TInputVector.Lerp(const target: TInputVector; t: Double): TInputVector;
begin
  Result := NewVector(x + (target.x - x) * t, y + (target.y - y) * t);
end;

{ ====== IMPLEMENTACJA TColor ====== }
function TColor.Lighten(amount: Integer): TColor;
begin
  Result := ColorRGBA(
    MinI(255, r + amount),
    MinI(255, g + amount),
    MinI(255, b + amount),
    a
  );
end;

function TColor.Darken(amount: Integer): TColor;
begin
  Result := ColorRGBA(
    MaxI(0, r - amount),
    MaxI(0, g - amount),
    MaxI(0, b - amount),
    a
  );
end;

function TColor.WithAlpha(newAlpha: Integer): TColor;
begin
  Result := ColorRGBA(r, g, b, newAlpha);
end;

function TColor.Blend(const other: TColor; factor: Double): TColor;
begin
  Result := ColorRGBA(
    Round(Lerp(r, other.r, factor)),
    Round(Lerp(g, other.g, factor)),
    Round(Lerp(b, other.b, factor)),
    Round(Lerp(a, other.a, factor))
  );
end;

{ ====== IMPLEMENTACJA TMatrix2D ====== }
function TMatrix2D.Transform(v: TInputVector): TInputVector;
begin
  Result.x := v.x * m0 + v.y * m1 + m2;
  Result.y := v.x * m3 + v.y * m4 + m5;
end;

function TMatrix2D.Multiply(const b: TMatrix2D): TMatrix2D;
begin
  Result.m0 := m0*b.m0 + m1*b.m3;
  Result.m1 := m0*b.m1 + m1*b.m4;
  Result.m2 := m0*b.m2 + m1*b.m5 + m2;
  Result.m3 := m3*b.m0 + m4*b.m3;
  Result.m4 := m3*b.m1 + m4*b.m4;
  Result.m5 := m3*b.m2 + m4*b.m5 + m5;
end;

procedure TMatrix2D.ApplyToContext;
begin
  gCtx.setTransform(m0, m3, m1, m4, m2, m5);
end;

function TMatrix2D.Invert: TMatrix2D;
var
  det: Double;
begin
  det := m0 * m4 - m1 * m3;
  if det = 0 then Exit(MatrixIdentity);

  Result.m0 := m4 / det;
  Result.m1 := -m1 / det;
  Result.m2 := (m1 * m5 - m2 * m4) / det;
  Result.m3 := -m3 / det;
  Result.m4 := m0 / det;
  Result.m5 := (m2 * m3 - m0 * m5) / det;
end;

{ ====== IMPLEMENTACJA TCamera2D ====== }
function TCamera2D.GetMatrix: TMatrix2D;
var
  translateToTarget, rotate, scale, translateFromOffset: TMatrix2D;
begin
  translateToTarget := MatrixTranslate(-target.x, -target.y);
  rotate := MatrixRotate(rotation);
  scale := MatrixScale(zoom, zoom);
  translateFromOffset := MatrixTranslate(offset.x, offset.y);

  Result := MatrixMultiply(MatrixMultiply(MatrixMultiply(translateToTarget, rotate), scale), translateFromOffset);
end;

{ ====== IMPLEMENTACJA TRectangle ====== }
function TRectangle.Move(dx, dy: Double): TRectangle;
begin
  Result := RectangleCreate(x + dx, y + dy, width, height);
end;

function TRectangle.Scale(sx, sy: Double): TRectangle;
begin
  Result := RectangleCreate(x, y, width * sx, height * sy);
end;

function TRectangle.Inflate(dx, dy: Double): TRectangle;
begin
  Result := RectangleCreate(x - dx, y - dy, width + 2*dx, height + 2*dy);
end;

function TRectangle.Contains(const point: TInputVector): Boolean;
begin
  Result := (point.x >= x) and (point.x <= x + width) and
            (point.y >= y) and (point.y <= y + height);
end;

function TRectangle.Intersects(const other: TRectangle): Boolean;
begin
  Result := not ((x + width <= other.x) or
                 (other.x + other.width <= x) or
                 (y + height <= other.y) or
                 (other.y + other.height <= y));
end;

function TRectangle.GetCenter: TInputVector;
begin
  Result := NewVector(x + width/2, y + height/2);
end;

{ ====== IMPLEMENTACJA TParticleSystem ====== }
constructor TParticleSystem.Create(maxCount: Integer);
begin
  maxParticles := maxCount;
  SetLength(particles, 0);
end;

procedure TParticleSystem.Emit(pos: TInputVector; count: Integer; 
  const aStartColor, aEndColor: TColor;
  minSize, maxSize, minLife, maxLife: Double);
var
  i: Integer;
  angle, speed, lifeVal: Double;
begin
  for i := 0 to count - 1 do
  begin
    if Length(particles) >= maxParticles then Break;

    SetLength(particles, Length(particles) + 1);
    with particles[High(particles)] do
    begin
      position := pos;
      angle := Random * 2 * Pi;
      speed := 50 + Random * 100;
      velocity := NewVector(Cos(angle) * speed, Sin(angle) * speed);
      startColor := aStartColor;
      endColor := aEndColor;
      color := aStartColor;
      size := minSize + Random * (maxSize - minSize);
      lifeVal := minLife + Random * (maxLife - minLife);
      life := lifeVal;
      initialLife := lifeVal;
      rotation := Random * 2 * Pi;
      angularVelocity := (Random - 0.5) * 4;
    end;
  end;
end;

procedure TParticleSystem.Update(dt: Double);
var
  i: Integer;
  t: Double;
begin
  i := 0;
  while i < Length(particles) do
  begin
    with particles[i] do
    begin
      position := position.Add(velocity.Scale(dt));
      life := life - dt;
      rotation := rotation + angularVelocity * dt;

      if initialLife > 0 then
      begin
        t := Clamp(life / initialLife, 0.0, 1.0);
        // Interpoluj kolor
        color.r := Round(Lerp(endColor.r, startColor.r, t));
        color.g := Round(Lerp(endColor.g, startColor.g, t));
        color.b := Round(Lerp(endColor.b, startColor.b, t));
        color.a := Round(255 * t);
      end
      else
        color.a := 0;
    end;

    if particles[i].life <= 0 then
    begin
      particles[i] := particles[High(particles)];
      SetLength(particles, Length(particles) - 1);
    end
    else
      Inc(i);
  end;
end;

procedure TParticleSystem.Draw;
var
  i: Integer;
begin
  for i := 0 to High(particles) do
  begin
    with particles[i] do
    begin
      gCtx.save;
      gCtx.translate(position.x, position.y);
      gCtx.rotate(rotation);
      gCtx.globalAlpha := color.a / 255.0;
      gCtx.fillRect(-size/2, -size/2, size, size);
      gCtx.restore;
    end;
  end;
end;

function TParticleSystem.GetActiveCount: Integer;
begin
  Result := Length(particles);
end;

{ ====== POMOCNICZE ====== }
function ColorToCanvasRGBA(const c: TColor): String;
begin
  Result := 'rgba(' +
    IntToStr(Round(Clamp(c.r,0,255))) + ',' +
    IntToStr(Round(Clamp(c.g,0,255))) + ',' +
    IntToStr(Round(Clamp(c.b,0,255))) + ',' +
    StringReplace(FormatFloat('0.###', Clamp(c.a,0,255)/255), ',', '.', []) +
    ')';
end;
function ColorFromHex(const hex: String): TColor;
var
  cleanHex: String;
begin
  cleanHex := StringReplace(hex, '#', '', [rfReplaceAll]);
  
  if Length(cleanHex) = 6 then
  begin
    Result.r := StrToInt('$' + Copy(cleanHex, 1, 2));
    Result.g := StrToInt('$' + Copy(cleanHex, 3, 2));
    Result.b := StrToInt('$' + Copy(cleanHex, 5, 2));
    Result.a := 255;
  end
  else if Length(cleanHex) = 8 then
  begin
    Result.r := StrToInt('$' + Copy(cleanHex, 1, 2));
    Result.g := StrToInt('$' + Copy(cleanHex, 3, 2));
    Result.b := StrToInt('$' + Copy(cleanHex, 5, 2));
    Result.a := StrToInt('$' + Copy(cleanHex, 7, 2));
  end
  else
  begin
    // Domyślny czarny kolor w przypadku błędu
    Result := COLOR_BLACK;
  end;
end;
{ ==== TRectangle helpers ===================================================== }

constructor TRectangle.Create(x, y, w, h: Double);
begin
  Self.x := x; Self.y := y; Self.width := w; Self.height := h;
end;

class function TRectangle.FromCenter(cx, cy, w, h: Double): TRectangle;
begin
  Result.x := cx - w * 0.5;
  Result.y := cy - h * 0.5;
  Result.width := w;
  Result.height := h;
end;

function TRectangleCreate(x, y, w, h: Double): TRectangle;
begin
  Result := TRectangle.Create(x, y, w, h);
end;

{ ==== TInputVector helpers (opcjonalnie) ==================================== }

constructor TInputVector.Create(x, y: Double);
begin
  Self.x := x; Self.y := y;
end;

function RandomColor(minBrightness: Integer = 0; maxBrightness: Integer = 255): TColor;
begin
  minBrightness := ClampI(minBrightness, 0, 255);
  maxBrightness := ClampI(maxBrightness, minBrightness, 255);
  
  Result.r := minBrightness + Random(maxBrightness - minBrightness + 1);
  Result.g := minBrightness + Random(maxBrightness - minBrightness + 1);
  Result.b := minBrightness + Random(maxBrightness - minBrightness + 1);
  Result.a := 255;
end;

function ColorEquals(const c1, c2: TColor): Boolean;
begin
  Result := (c1.r = c2.r) and (c1.g = c2.g) and (c1.b = c2.b) and (c1.a = c2.a);
end;
procedure EnsureTintCanvas(w, h: Integer);
begin
  if (gTintCanvas = nil) then
  begin
    gTintCanvas := TJSHTMLCanvasElement(document.createElement('canvas'));
    gTintCtx := TJSCanvasRenderingContext2D(gTintCanvas.getContext('2d'));
  end;
  if (gTintCanvas.width <> w) or (gTintCanvas.height <> h) then
  begin
    gTintCanvas.width := w;
    gTintCanvas.height := h;
  end;
end;

// ====== Opcje jakości/wydajności ======
procedure SetHiDPI(enabled: Boolean);
begin
  gUseHiDPI := enabled;
end;

procedure SetCanvasAlpha(enabled: Boolean);
begin
  gCanvasAlpha := enabled;
end;

procedure SetImageSmoothing(enabled: Boolean);
begin
  gImageSmoothingWanted := enabled;
  if Assigned(gCtx) then
    TJSObject(gCtx)['imageSmoothingEnabled'] := enabled;
end;

procedure SetClearFast(enabled: Boolean);
begin
  gUseClearFast := enabled;
end;

procedure Clear(const color: TColor);
begin
  if gUseClearFast then
    ClearFast(color)
  else
    ClearBackground(color);
end;

{ ====== CLIP / USTAWIENIA LINII ====== }
procedure BeginScissor(x, y, w, h: Integer);
begin
  gCtx.save;
  gCtx.beginPath;
  gCtx.rect(x, y, w, h);
  gCtx.clip;
end;

procedure EndScissor;
begin
  gCtx.restore;
end;

procedure SetLineJoin(const joinKind: String);
begin
  gCtx.lineJoin := joinKind; // 'miter'|'round'|'bevel'
end;
procedure SetLineJoin(const joinKind: TLineJoinKind); overload;
begin
  SetLineJoin(LineJoinToStr(joinKind));
end;



procedure SetLineCap(const capKind: String);
begin
  gCtx.lineCap := capKind; // 'butt'|'round'|'square'
end;
procedure SetLineCap(const capKind: TLineCapKind); overload;
begin
  SetLineCap(LineCapToStr(capKind));
end;



// ====== ClearFast: copy composite ======
procedure ClearFast(const color: TColor);
var
  oldOp: string;
begin
  gCtx.save;
  gCtx.setTransform(1,0,0,1,0,0); // czyść w układzie domyślnym
  oldOp := gCtx.globalCompositeOperation;
  gCtx.globalCompositeOperation := 'copy';
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  gCtx.fillRect(0, 0, gCanvas.width, gCanvas.height);
  gCtx.globalCompositeOperation := oldOp;
  gCtx.restore;
end;


// ====== Batch prostokątów (path) ======
procedure BeginRectBatch(const color: TColor);
begin
  gCtx.beginPath;
  gCtx.fillStyle := ColorToCanvasRGBA(color);
end;

procedure BatchRect(x, y, w, h: Integer);
begin
  gCtx.rect(x, y, w, h);
end;

procedure EndRectBatchFill;
begin
  gCtx.fill;
end;

// ====== Batch linii ======
procedure BeginLineBatch;
begin
  SetLength(gLineBatch, 0);
  gLineBatchActive := True;
end;

procedure BatchLine(aStartX, aStartY, aEndX, aEndY: Double; const aColor: TColor; aThickness: Integer = 1);
begin
  if not gLineBatchActive then Exit;
  SetLength(gLineBatch, Length(gLineBatch) + 1);
  with gLineBatch[High(gLineBatch)] do
  begin
    startX    := aStartX;
    startY    := aStartY;
    endX      := aEndX;
    endY      := aEndY;
    color     := aColor;
    thickness := aThickness;
  end;
end;

procedure BatchLineV(const aStartPos, aEndPos: TInputVector; const aColor: TColor; aThickness: Integer = 1);
begin
  BatchLine(aStartPos.x, aStartPos.y, aEndPos.x, aEndPos.y, aColor, aThickness);
end;

procedure EndLineBatch;
var
  i: Integer;
  currentColor: TColor;
  currentThickness: Integer;
  off: Double;
begin
  if not gLineBatchActive or (Length(gLineBatch) = 0) then Exit;

  gCtx.beginPath;
  currentColor := gLineBatch[0].color;
  currentThickness := gLineBatch[0].thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(currentColor);
  gCtx.lineWidth := currentThickness;

  for i := 0 to High(gLineBatch) do
  begin
    if (gLineBatch[i].color.r <> currentColor.r) or
       (gLineBatch[i].color.g <> currentColor.g) or
       (gLineBatch[i].color.b <> currentColor.b) or
       (gLineBatch[i].color.a <> currentColor.a) or
       (gLineBatch[i].thickness <> currentThickness) then
    begin
      gCtx.stroke;
      gCtx.beginPath;
      currentColor := gLineBatch[i].color;
      currentThickness := gLineBatch[i].thickness;
      gCtx.strokeStyle := ColorToCanvasRGBA(currentColor);
      gCtx.lineWidth := currentThickness;
    end;

    if currentThickness = 1 then off := 0.5 else off := 0.0;
    gCtx.moveTo(gLineBatch[i].startX + off, gLineBatch[i].startY + off);
    gCtx.lineTo(gLineBatch[i].endX   + off, gLineBatch[i].endY   + off);
  end;

  gCtx.stroke;
  SetLength(gLineBatch, 0);
  gLineBatchActive := False;
end;

// ====== RectSeries (fillStyle raz, same fillRect) ======
procedure BeginRectSeries(const color: TColor);
begin
  gCtx.fillStyle := ColorToCanvasRGBA(color);
end;

procedure RectFill(x, y, w, h: Integer);
begin
  gCtx.fillRect(x, y, w, h);
end;

procedure EndRectSeries;
begin
  // nic – zostawiamy fillStyle
end;

function GetScreenWidth: Integer; begin Result := Round(gCanvas.width / gDPR); end;
function GetScreenHeight: Integer; begin Result := Round(gCanvas.height / gDPR); end;
function GetMouseX: Integer; begin Result := Round(gMousePos.x); end;
function GetMouseY: Integer; begin Result := Round(gMousePos.y); end;
function GetFrameTime: Double; begin Result := gLastDt; end;
function GetFPS: Integer; begin Result := gCurrentFps; end;
function GetDeltaTime: Double; begin Result := gLastDt; end;
function GetTime: Double; begin Result := (window.performance.now() - gStartTime) / 1000.0; end;

{ ====== RYSOWANIE KSZTAŁTÓW ====== }
procedure DrawLine(startX, startY, endX, endY: Integer; const color: TColor; thickness: Integer = 1);
var off: Double;

begin
  if (thickness and 1) = 1 then off := 0.5 else off := 0.0;
  gCtx.beginPath;
  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.moveTo(startX + off, startY + off);
  gCtx.lineTo(endX   + off, endY   + off);
  gCtx.stroke;
end;


procedure DrawLineV(startPos, endPos: TInputVector; const color: TColor; thickness: Integer = 1);
begin
  DrawLine(Round(startPos.x), Round(startPos.y), Round(endPos.x), Round(endPos.y), color, thickness);
end;

procedure DrawTriangle(const tri: TTriangle; const color: TColor; filled: Boolean = True);
begin
  gCtx.beginPath;
  gCtx.moveTo(tri.p1.x, tri.p1.y);
  gCtx.lineTo(tri.p2.x, tri.p2.y);
  gCtx.lineTo(tri.p3.x, tri.p3.y);
  gCtx.closePath;

  if filled then begin
    gCtx.fillStyle := ColorToCanvasRGBA(color);
    gCtx.fill;
  end else begin
    gCtx.strokeStyle := ColorToCanvasRGBA(color);
    gCtx.stroke;
  end;
end;

procedure DrawTriangleLines(const tri: TTriangle; const color: TColor; thickness: Integer = 1);
begin
  gCtx.lineWidth := thickness;
  DrawTriangle(tri, color, False);
end;
// ========== Wielokąty / polilinie ==========
procedure DrawPolyline(const pts: array of TInputVector; const color: TColor; thickness: Integer; closed: Boolean);
var i: Integer; off: Double;
begin
  if Length(pts) < 2 then Exit;
  if thickness = 1 then off := 0.5 else off := 0.0;

  gCtx.save;
  gCtx.beginPath;
  gCtx.moveTo(pts[0].x + off, pts[0].y + off);
  for i := 1 to High(pts) do
    gCtx.lineTo(pts[i].x + off, pts[i].y + off);

  if closed then gCtx.closePath;

  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.stroke;
  gCtx.restore;
end;

procedure DrawPolygon(const pts: array of TInputVector; const color: TColor; filled: Boolean);
var i: Integer;
begin
  if Length(pts) < 3 then Exit;

  gCtx.save;
  gCtx.beginPath;
  gCtx.moveTo(pts[0].x, pts[0].y);
  for i := 1 to High(pts) do
    gCtx.lineTo(pts[i].x, pts[i].y);
  gCtx.closePath;

  if filled then
  begin
    gCtx.fillStyle := ColorToCanvasRGBA(color);
    gCtx.fill;
  end
  else
  begin
    gCtx.strokeStyle := ColorToCanvasRGBA(color);
    gCtx.stroke;
  end;
  gCtx.restore;
end;

// ========== Łuki / wycinki ==========
procedure DrawArc(cx, cy, r: Double; startDeg, endDeg: Double; const color: TColor; thickness: Integer);
begin
  gCtx.save;
  gCtx.beginPath;
  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.arc(cx, cy, r, DegToRad(startDeg), DegToRad(endDeg), False);
  gCtx.stroke;
  gCtx.restore;
end;

procedure DrawRing(cx, cy, rInner, rOuter, startDeg, endDeg: Double; const color: TColor);
var a0, a1: Double;
begin
  if (rOuter <= rInner) or (rInner < 0) then Exit;
  a0 := DegToRad(startDeg); a1 := DegToRad(endDeg);

  gCtx.save;
  gCtx.beginPath;
  gCtx.arc(cx, cy, rOuter, a0, a1, False);
  gCtx.arc(cx, cy, rInner, a1, a0, True); // powrót wewnątrz
  gCtx.closePath;
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  gCtx.fill;
  gCtx.restore;
end;

procedure DrawSector(cx, cy, r: Double; startDeg, endDeg: Double; const color: TColor);
begin
  gCtx.save;
  gCtx.beginPath;
  gCtx.moveTo(cx, cy);
  gCtx.arc(cx, cy, r, DegToRad(startDeg), DegToRad(endDeg), False);
  gCtx.closePath;
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  gCtx.fill;
  gCtx.restore;
end;

// ========== Linie kreskowane ==========
procedure SetLineDash(const dashes: array of Double);
var arr: TJSArray; i: Integer;
begin
  arr := TJSArray.new;
  for i := 0 to High(dashes) do arr.push(dashes[i]);
  gCtx.setLineDash(arr);
end;

procedure ClearLineDash;
begin
  gCtx.setLineDash(TJSArray.new); // pusty pattern
end;

procedure DrawDashedLine(x1, y1, x2, y2: Double; const color: TColor; thickness: Integer; dashLen, gapLen: Double);
begin
  gCtx.save;
  gCtx.setLineDash(TJSArray.new(dashLen, gapLen));
  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.beginPath;
  gCtx.moveTo(x1, y1);
  gCtx.lineTo(x2, y2);
  gCtx.stroke;
  gCtx.restore;
end;

// ========== Gradient prostokątny ==========
procedure FillRectLinearGradient(const rec: TRectangle; const c0, c1: TColor; angleDeg: Double);
var
  cx, cy, dx, dy, halfDiag: Double;
  x0, y0, x1, y1: Double;
  grad: TJSCanvasGradient;
  rad: Double;
begin
  // środek i kierunek
  cx := rec.x + rec.width  * 0.5;
  cy := rec.y + rec.height * 0.5;
  rad := DegToRad(angleDeg);
  dx := Cos(rad); dy := Sin(rad);

  // długość do pokrycia całego rect
  halfDiag := Sqrt(Sqr(rec.width) + Sqr(rec.height)) * 0.5;

  x0 := cx - dx * halfDiag;  y0 := cy - dy * halfDiag;
  x1 := cx + dx * halfDiag;  y1 := cy + dy * halfDiag;

  grad := gCtx.createLinearGradient(x0, y0, x1, y1);
  grad.addColorStop(0, ColorToCanvasRGBA(c0));
  grad.addColorStop(1, ColorToCanvasRGBA(c1));

  gCtx.save;
  gCtx.fillStyle := grad;
  gCtx.fillRect(rec.x, rec.y, rec.width, rec.height);
  gCtx.restore;
end;

// ========== Tekst z obrysem ==========
procedure DrawTextOutline(const text: String; x, y, size: Integer; const fillColor, outlineColor: TColor; outlinePx: Integer);
begin
  gCtx.save;
  EnsureFont(size);
  gCtx.textAlign := 'left';
  gCtx.textBaseline := 'top';

  // obrys
  if outlinePx > 0 then
  begin
    gCtx.lineJoin := 'round';
    gCtx.lineWidth := outlinePx * 2; // wizualnie „grubość” obrysu
    gCtx.strokeStyle := ColorToCanvasRGBA(outlineColor);
    gCtx.strokeText(text, x, y);
  end;

  // wypełnienie
  gCtx.fillStyle := ColorToCanvasRGBA(fillColor);
  gCtx.fillText(text, x, y);

  gCtx.restore;
end;

// ========== Clip dowolnym path ==========
procedure BeginPathClip(const BuildPath: TNoArgProc);
begin
  gCtx.save;
  gCtx.beginPath;
  if Assigned(BuildPath) then BuildPath();
  gCtx.clip;
end;

procedure EndClip;
begin
  gCtx.restore;
end;

procedure DrawRectangleRounded(x, y, w, h, radius: double; const color: TColor; filled: Boolean = True);
var
  maxRadius, halfW, halfH: double;
begin
  if radius <= 0 then
  begin
    if filled then
      DrawRectangle(x, y, w, h, color)
    else
      DrawRectangleLines(x, y, w, h, color);
    Exit;
  end;

  // zamiast Min(w div 2, h div 2):
  halfW := w / 2; // to samo co w div 2
  halfH := h / 2; // to samo co h div 2
  if halfW < halfH then
    maxRadius := halfW
  else
    maxRadius := halfH;

  if radius > maxRadius then
    radius := maxRadius;

  gCtx.beginPath;
  gCtx.moveTo(x + radius, y);
  gCtx.arcTo(x + w, y, x + w, y + h, radius);
  gCtx.arcTo(x + w, y + h, x, y + h, radius);
  gCtx.arcTo(x, y + h, x, y, radius);
  gCtx.arcTo(x, y, x + w, y, radius);
  gCtx.closePath;

  if filled then
  begin
    gCtx.fillStyle := ColorToCanvasRGBA(color);
    gCtx.fill;
  end
  else
  begin
    gCtx.strokeStyle := ColorToCanvasRGBA(color);
    gCtx.stroke;
  end;
end;

procedure DrawRectangleRoundedRec(const rec: TRectangle; radius: Double; const color: TColor; filled: Boolean = True);
begin
  DrawRectangleRounded(Round(rec.x), Round(rec.y), Round(rec.width), Round(rec.height), 
                      Round(radius), color, filled);
end;
procedure DrawRectangleLines(x, y, w, h: double; const color: TColor; thickness: Integer = 1);
var off: Double;
begin
  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  if (thickness and 1) = 1 then off := 0.5 else off := 0.0;
  gCtx.strokeRect(x + off, y + off, w, h);
end;

{ ====== TRANSFORMACJE I MACIERZE ====== }
function MatrixIdentity: TMatrix2D;
begin
  Result.m0 := 1; Result.m1 := 0; Result.m2 := 0;
  Result.m3 := 0; Result.m4 := 1; Result.m5 := 0;
end;

function MatrixTranslate(tx, ty: Double): TMatrix2D;
begin
  Result.m0 := 1; Result.m1 := 0; Result.m2 := tx;
  Result.m3 := 0; Result.m4 := 1; Result.m5 := ty;
end;

function MatrixRotate(radians: Double): TMatrix2D;
var c, s: Double;
begin
  c := Cos(radians); s := Sin(radians);
  Result.m0 := c;  Result.m1 := -s; Result.m2 := 0;
  Result.m3 := s;  Result.m4 :=  c; Result.m5 := 0;
end;

function MatrixRotateDeg(deg: Double): TMatrix2D;
begin
  Result := MatrixRotate(DegToRad(deg));
end;

function MatrixScale(sx, sy: Double): TMatrix2D;
begin
  Result.m0 := sx; Result.m1 := 0;  Result.m2 := 0;
  Result.m3 := 0;  Result.m4 := sy; Result.m5 := 0;
end;

function MatrixMultiply(const a, b: TMatrix2D): TMatrix2D;
begin
  Result.m0 := a.m0*b.m0 + a.m1*b.m3;
  Result.m1 := a.m0*b.m1 + a.m1*b.m4;
  Result.m2 := a.m0*b.m2 + a.m1*b.m5 + a.m2;
  Result.m3 := a.m3*b.m0 + a.m4*b.m3;
  Result.m4 := a.m3*b.m1 + a.m4*b.m4;
  Result.m5 := a.m3*b.m2 + a.m4*b.m5 + a.m5;
end;

function Vector2Transform(v: TInputVector; mat: TMatrix2D): TInputVector;
begin
  Result.x := v.x * mat.m0 + v.y * mat.m1 + mat.m2;
  Result.y := v.x * mat.m3 + v.y * mat.m4 + mat.m5;
end;

// Memory pooling
function GetVectorFromPool(x, y: Double): TInputVector;
begin
  if Length(gVectorPool) > 0 then
  begin
    Result := gVectorPool[High(gVectorPool)];
    SetLength(gVectorPool, Length(gVectorPool) - 1);
    Result.x := x; Result.y := y;
  end
  else
    Result := NewVector(x, y);
end;

procedure ReturnVectorToPool(var v: TInputVector);
begin
  SetLength(gVectorPool, Length(gVectorPool) + 1);
  gVectorPool[High(gVectorPool)] := v;
end;

function GetMatrixFromPool: TMatrix2D;
begin
  if Length(gMatrixPool) > 0 then
  begin
    Result := gMatrixPool[High(gMatrixPool)];
    SetLength(gMatrixPool, Length(gMatrixPool) - 1);
  end
  else
    Result := MatrixIdentity;
end;

procedure ReturnMatrixToPool(var mat: TMatrix2D);
begin
  SetLength(gMatrixPool, Length(gMatrixPool) + 1);
  gMatrixPool[High(gMatrixPool)] := mat;
end;

{ ====== KAMERA ====== }
function DefaultCamera: TCamera2D;
begin
  Result.target := NewVector(0, 0);
  Result.offset := NewVector(0, 0);
  Result.rotation := 0.0;
  Result.zoom := 1.0;
end;

procedure BeginMode2D(const camera: TCamera2D);
var
  z, tx, ty, a, b, c_, d, e, f, coss, sinn: Double;
begin
  gCtx.save;

  z := camera.zoom; if z = 0 then z := 1.0;

  // (opcjonalnie) zapamiętaj stan, jeśli gdzieś używasz
  // gCamActive := True; gCamZoom := z;

  if camera.rotation = 0.0 then
  begin
    // M = S(z) + T((-target)*z + offset)
    tx := -camera.target.x * z + camera.offset.x;
    ty := -camera.target.y * z + camera.offset.y;

    // pixel-snapping translacji w screen-space
    {tx := Round(tx);
    ty := Round(ty);}

    gCtx.setTransform(z, 0, 0, z, tx, ty);
  end
  else
  begin
    // M = T(offset) * R(rot) * S(z) * T(-target)
    coss := Cos(camera.rotation);
    sinn := Sin(camera.rotation);

    a :=  coss * z;   b :=  sinn * z;
    c_ := -sinn * z;  d :=  coss * z;

    tx := -camera.target.x;
    ty := -camera.target.y;

    // ostateczna translacja w screen-space:
    e := camera.offset.x + (a * tx + c_ * ty);
    f := camera.offset.y + (b * tx + d * ty);

    {// snap translacji (przy rotacji to best-effort)
    e := Round(e); f := Round(f);

    gCtx.setTransform(a, b, c_, d, e, f);}
  end;
end;

procedure EndMode2D;
begin
  gCtx.restore;
  // gCamActive := False;
end;


function ScreenToWorld(p: TVector2; const cam: TCamera2D): TVector2;
var mat: TMatrix2D;
begin
  mat := MatrixMultiply(MatrixMultiply(MatrixTranslate(cam.target.x, cam.target.y),
                                       MatrixRotate(-cam.rotation)),
                        MatrixScale(1/cam.zoom, 1/cam.zoom));
  Result := Vector2Transform(Vector2Subtract(p, cam.offset), mat);
end;

function WorldToScreen(p: TVector2; const cam: TCamera2D): TVector2;
var mat: TMatrix2D;
begin
  mat := MatrixMultiply(MatrixMultiply(MatrixTranslate(-cam.target.x, -cam.target.y),
                                       MatrixRotate(cam.rotation)),
                        MatrixScale(cam.zoom, cam.zoom));
  Result := Vector2Add(Vector2Transform(p, mat), cam.offset);
end;

{ ====== KOLIZJE I GEOMETRIA ====== }
function CheckCollisionPointRec(point: TInputVector; const rec: TRectangle): Boolean;
begin
  Result := (point.x >= rec.x) and (point.x <= rec.x + rec.width) and
            (point.y >= rec.y) and (point.y <= rec.y + rec.height);
end;

function CheckCollisionCircles(center1: TInputVector; radius1: Double;
                              center2: TInputVector; radius2: Double): Boolean;
var d: Double;
begin
  d := Vector2Length(Vector2Subtract(center1, center2));
  Result := d <= (radius1 + radius2);
end;

function ClampD(value, minVal, maxVal: Double): Double;
begin
  if value < minVal then Exit(minVal);
  if value > maxVal then Exit(maxVal);
  Result := value;
end;

function CheckCollisionCircleRec(center: TInputVector; radius: Double; const rec: TRectangle): Boolean;
var closestX, closestY: Double;
begin
  closestX := ClampD(center.x, rec.x, rec.x + rec.width);
  closestY := ClampD(center.y, rec.y, rec.y + rec.height);
  Result := Vector2Length(Vector2Subtract(center, NewVector(closestX, closestY))) <= radius;
end;

function CheckCollisionRecs(const a, b: TRectangle): Boolean;
begin
  Result := not ((a.x + a.width  <= b.x) or
                 (b.x + b.width  <= a.x) or
                 (a.y + a.height <= b.y) or
                 (b.y + b.height <= a.y));
end;

function CheckCollisionPointCircle(point, center: TInputVector; radius: Double): Boolean;
begin
  Result := Vector2Length(Vector2Subtract(point, center)) <= radius;
end;

function CheckCollisionPointPoly(point: TInputVector; const points: array of TInputVector): Boolean;
var
  i, j: Integer;
  inside: Boolean;
begin
  inside := False;
  j := High(points);
  
  for i := 0 to High(points) do
  begin
    if ((points[i].y > point.y) <> (points[j].y > point.y)) and
       (point.x < (points[j].x - points[i].x) * (point.y - points[i].y) / 
                 (points[j].y - points[i].y) + points[i].x) then
    begin
      inside := not inside;
    end;
    j := i;
  end;
  
  Result := inside;
end;

function CheckCollisionLineLine(a1, a2, b1, b2: TInputVector): Boolean;
var
  t, u: Double;
begin
  Result := LinesIntersect(a1, a2, b1, b2, t, u);
end;

function CheckCollisionLineRec(const line: TLine; const rec: TRectangle): Boolean;
var
  corners: array[0..3] of TInputVector;
  i: Integer;
  t, u: Double;
begin
  corners[0] := NewVector(rec.x, rec.y);
  corners[1] := NewVector(rec.x + rec.width, rec.y);
  corners[2] := NewVector(rec.x + rec.width, rec.y + rec.height);
  corners[3] := NewVector(rec.x, rec.y + rec.height);

  for i := 0 to 3 do
  begin
    if LinesIntersect(line.startPoint, line.endPoint,
                     corners[i], corners[(i+1) mod 4], t, u) then
      Exit(True);
  end;

  Result := False;
end;

function LinesIntersect(p1, p2, p3, p4: TInputVector; out t, u: Double): Boolean;
var
  denom, numT, numU: Double;
begin
  denom := (p1.x - p2.x)*(p3.y - p4.y) - (p1.y - p2.y)*(p3.x - p4.x);
  if denom = 0 then Exit(False);
  numT := (p1.x - p3.x)*(p3.y - p4.y) - (p1.y - p3.y)*(p3.x - p4.x);
  numU := (p1.x - p3.x)*(p1.y - p2.y) - (p1.y - p3.y)*(p1.x - p2.x);
  t := numT / denom;
  u := numU / denom;
  Result := (t >= 0) and (t <= 1) and (u >= 0) and (u <= 1);
end;

{ ====== ŁADOWANIE I RYSOWANIE OBRAZÓW ====== }
procedure LoadImageFromURL(const url: String; OnReady: TOnTextureReady); overload;
var
  img: TJSHTMLImageElement;
  tex: TTexture;
begin
  tex.canvas := TJSHTMLCanvasElement(document.createElement('canvas'));
  tex.width  := 0;
  tex.height := 0;
  tex.loaded := False;

  img := TJSHTMLImageElement(document.createElement('img'));
  img.crossOrigin := 'anonymous';

  img.onload := TJSEventHandler(
    procedure (event: TJSEvent)
    var
      ctx: TJSCanvasRenderingContext2D;
    begin
      tex.width  := img.width;
      tex.height := img.height;
      tex.canvas.width  := img.width;
      tex.canvas.height := img.height;
      ctx := TJSCanvasRenderingContext2D(tex.canvas.getContext('2d'));
      ctx.drawImage(img, 0, 0);
      tex.loaded := True;
      {$ifdef WILGA_DEBUG} DBG_Inc(dbg_TexturesAlive); {$endif}
      if Assigned(OnReady) then OnReady(tex);
    end
  );

  // 🔧 POPRAWIONY onerror:
  img.onerror := TJSErrorEventHandler(
    procedure (event: TJSErrorEvent)
    begin
      console.warn('LoadImageFromURL failed: ' + url);
      tex.canvas := nil;
      tex.width := 0;
      tex.height := 0;
      tex.loaded := False;
      if Assigned(OnReady) then OnReady(tex); // ← callback przy błędzie
    end
  );

  img.src := url;
end;


function  LoadImageFromURL(const url: String): TTexture; overload;
var
  img: TJSHTMLImageElement;
  tex: TTexture;
begin
  tex.canvas := TJSHTMLCanvasElement(document.createElement('canvas'));
  tex.width  := 0;
  tex.height := 0;
  tex.loaded := False;

  img := TJSHTMLImageElement(document.createElement('img'));
  img.crossOrigin := 'anonymous';

  img.onload := TJSEventHandler(
    procedure (event: TJSEvent)
    var
      ctx: TJSCanvasRenderingContext2D;
    begin
      tex.width  := img.width;
      tex.height := img.height;
      tex.canvas.width  := img.width;
      tex.canvas.height := img.height;
      ctx := TJSCanvasRenderingContext2D(tex.canvas.getContext('2d'));
      ctx.drawImage(img, 0, 0);
      tex.loaded := True;
    end
  );

  img.onerror := TJSErrorEventHandler(
    procedure (event: TJSErrorEvent)
    begin
      console.warn('LoadImageFromURL failed: ' + url);
    end
  );

  img.src := url;
  Result := tex;
end;

procedure ReleaseTexture(var tex: TTexture);
begin
  if tex.canvas <> nil then
  begin
    // kasujemy referencje – GC może zebrać
    tex.canvas.width := 0;
    tex.canvas.height := 0;
    tex.canvas := nil;
    {$ifdef WILGA_DEBUG} DBG_Dec(dbg_TexturesAlive); {$endif}
  end;
  tex.loaded := False;
  tex.width := 0;
  tex.height := 0;
end;


procedure ReleaseRenderTexture(var rtex: TRenderTexture2D);
begin
  if (rtex.texture.canvas <> nil) then
  begin
    {$ifdef WILGA_DEBUG} DBG_Dec(dbg_RenderTexturesAlive); {$endif}
  end;
  ReleaseTexture(rtex.texture);
end;

procedure DrawTexture(const tex: TTexture; x, y: Integer; const tint: TColor);
begin
  DrawTexturePro(tex,
    RectangleCreate(0, 0, tex.width, tex.height),
    RectangleCreate(x, y, tex.width, tex.height),
    Vector2Zero, 0, tint);
end;
// Proste rysowanie z pozycją, skalą, rotacją i tintem
// === Tekstury ===

// Rysowanie z pozycją, skalą, rotacją i tintem
procedure DrawTextureEx(const tex: TTexture; position: TVector2; scale: Double; rotation: Double; const tint: TColor);
var
  src, dst: TRectangle;
  origin: TVector2;
begin
  src := RectangleCreate(0, 0, tex.width, tex.height);
  dst := RectangleCreate(position.x, position.y, tex.width * scale, tex.height * scale);
  origin := Vector2Create(0,0);
  DrawTexturePro(tex, src, dst, origin, rotation, tint);
end;

// Rysowanie wycinka tekstury (source rectangle)
procedure DrawTextureRec(const tex: TTexture; const src: TRectangle; position: TVector2; const tint: TColor);
var
  dst: TRectangle;
  origin: TVector2;
begin
  dst := RectangleCreate(position.x, position.y, src.width, src.height);
  origin := Vector2Create(0, 0);
  DrawTexturePro(tex, src, dst, origin, 0, tint);
end;

// Rysowanie powtarzającej się tekstury na obszarze (tiling)
procedure DrawTextureTiled(const tex: TTexture; const src, dst: TRectangle; origin: TVector2; rotation: Double; scale: Double; const tint: TColor);
var
  x, y: Integer;
  tileDst: TRectangle;
begin
  for y := 0 to Trunc(dst.height / (src.height * scale)) do
    for x := 0 to Trunc(dst.width / (src.width * scale)) do
    begin
      tileDst := RectangleCreate(
        dst.x + x * src.width * scale,
        dst.y + y * src.height * scale,
        src.width * scale,
        src.height * scale
      );
      DrawTexturePro(tex, src, tileDst, origin, rotation, tint);
    end;
end;

// Rysowanie z originem w proporcjach (0..1)
procedure DrawTextureProRelOrigin(const tex: TTexture; const src, dst: TRectangle; originRel: TVector2; rotation: Double; const tint: TColor);
var
  origin: TVector2;
begin
  origin := Vector2Create(dst.width * originRel.x, dst.height * originRel.y);
  DrawTexturePro(tex, src, dst, origin, rotation, tint);
end;

// Rysowanie ramki z atlasu po indeksie
procedure DrawAtlasFrame(const tex: TTexture; frameIndex, frameWidth, frameHeight: Integer; position: TVector2; const tint: TColor);
var
  cols, srcX, srcY: Integer;
  src: TRectangle;
begin
  cols := tex.width div frameWidth;
  srcX := (frameIndex mod cols) * frameWidth;
  srcY := (frameIndex div cols) * frameHeight;
  src := RectangleCreate(srcX, srcY, frameWidth, frameHeight);
  DrawTextureRec(tex, src, position, tint);
end;


// === Tekst ===
procedure ApplyFont;
begin
  SetTextFont(IntToStr(GFontSize) + 'px ' + GFontFamily);
end;


function BuildFontString(const sizePx: Integer; const family: String = ''): String;
begin
  if (family <> '') then
    Result := IntToStr(sizePx) + 'px "' + family + '", ' + GFontFamily
  else
    Result := IntToStr(sizePx) + 'px ' + GFontFamily;
end;

procedure EnsureFont(const sizePx: Integer; const family: String = '');
var desired: String;
begin
  desired := BuildFontString(sizePx, family);
  if gCtx.font <> desired then
    gCtx.font := desired;
end;
procedure SetFontSize(const sizePx: Integer);
begin
  if sizePx <> GFontSize then
  begin
    GFontSize := sizePx;
    ApplyFont;
  end;
end;

procedure SetFontFamily(const family: String);
begin
  if family <> GFontFamily then
  begin
    GFontFamily := family;
    ApplyFont;
  end;
end;
// Proste rysowanie tekstu w punkcie
procedure DrawTextSimple(const text: String; pos: TVector2; fontSize: Integer; const color: TColor);
begin
  DrawText(text, Round(pos.x), Round(pos.y), fontSize, color);
end;

// Rysowanie tekstu wyśrodkowanego względem punktu
procedure DrawTextCentered(const text: String; center: TVector2; fontSize: Integer; const color: TColor);
var
  w, h: Double;
begin
  w := MeasureTextWidth(text, fontSize);
  h := MeasureTextHeight(text, fontSize);
  DrawText(text, Round(center.x - w / 2), Round(center.y - h / 2), fontSize, color);
end;

// Rysowanie tekstu wyrównanego do prawej
procedure DrawTextRightAligned(const text: String; rightPos: TVector2; fontSize: Integer; const color: TColor);
var
  w: Double;
begin
  w := MeasureTextWidth(text, fontSize);
  DrawText(text, Round(rightPos.x - w), Round(rightPos.y), fontSize, color);
end;

// Tekst z obramowaniem (outline)
procedure DrawTextOutlineAdv(const text: String; pos: TVector2; fontSize: Integer; const color, outlineColor: TColor; thickness: Integer);
var
  dx, dy: Integer;
begin
  for dy := -thickness to thickness do
    for dx := -thickness to thickness do
      if (dx <> 0) or (dy <> 0) then
        DrawText(text, Round(pos.x) + dx, Round(pos.y) + dy, fontSize, outlineColor);
  DrawText(text, Round(pos.x), Round(pos.y), fontSize, color);
end;

// Tekst z cieniem
procedure DrawTextShadow(const text: String; pos: TVector2; fontSize: Integer; const color, shadowColor: TColor; shadowOffset: TVector2);
begin
  DrawText(text, Round(pos.x + shadowOffset.x), Round(pos.y + shadowOffset.y), fontSize, shadowColor);
  DrawText(text, Round(pos.x), Round(pos.y), fontSize, color);
end;

// Tekst w ramce (word wrap)
// Tekst w ramce o szerokości boxWidth z łamaniem wierszy.
// Parametry:
//   text           – treść
//   pos            – lewy-górny narożnik ramki (zewnętrznej)
//   boxWidth       – szerokość ramki (px)
//   fontSize       – rozmiar czcionki
//   textColor      – kolor tekstu
//   lineSpacing    – odstęp między wierszami (px, może być 0)
//   borderColor    – kolor obrysu ramki
//   borderThickness– grubość obrysu (px, np. 2)
procedure DrawTextBoxed(const text: String; pos: TVector2; boxWidth: Integer;
  fontSize: Integer; const textColor: TColor; lineSpacing: Integer;
  const borderColor: TColor; borderThickness: Integer);
var
  words: array of String;
  lines: array of String;
  currentLine, tryLine: String;
  i, j, y, pad, totalH, lineH: Integer;

  function Fits(const s: String): Boolean;
  begin
    Result := Round(MeasureTextWidth(s, fontSize)) <= (boxWidth - 2*pad);
  end;

  procedure BreakLongWord(const w: String);
  var
    seg: String;
  begin
    seg := '';
    for j := 1 to Length(w) do
    begin
      if not Fits(seg + w[j]) then
      begin
        if seg <> '' then
        begin
          SetLength(lines, Length(lines)+1);
          lines[High(lines)] := seg + '-';
          seg := w[j];
        end
        else
        begin
          SetLength(lines, Length(lines)+1);
          lines[High(lines)] := w[j];
          seg := '';
        end;
      end
      else
        seg := seg + w[j];
    end;
    if seg <> '' then
    begin
      SetLength(lines, Length(lines)+1);
      lines[High(lines)] := seg;
    end;
  end;

begin
  if text = '' then Exit;

  pad := 4;
  lineH := Round(fontSize * 1.35) + lineSpacing;

  words := text.Split([' ']);
  SetLength(lines, 0);
  currentLine := '';
  y := Round(pos.y) + pad;

  for i := 0 to High(words) do
  begin
    if currentLine = '' then
      tryLine := words[i]
    else
      tryLine := currentLine + ' ' + words[i];

    if Fits(tryLine) then
      currentLine := tryLine
    else
    begin
      if currentLine <> '' then
      begin
        SetLength(lines, Length(lines)+1);
        lines[High(lines)] := currentLine;
        currentLine := '';
      end;

      if not Fits(words[i]) then
        BreakLongWord(words[i])
      else
        currentLine := words[i];
    end;
  end;

  if currentLine <> '' then
  begin
    SetLength(lines, Length(lines)+1);
    lines[High(lines)] := currentLine;
  end;

  // rysowanie tekstu
  for i := 0 to High(lines) do
    DrawText(lines[i], Round(pos.x) + pad, y + i*lineH, fontSize, textColor);

  // wysokość ramki
  if Length(lines) > 0 then
    totalH := Length(lines)*lineH - lineSpacing + 2*pad
  else
    totalH := fontSize + 2*pad;

  // ramka jednym wywołaniem, z zadaną grubością
  DrawRectangleLines(Round(pos.x), Round(pos.y),
                     boxWidth, totalH,
                     borderColor, borderThickness);
end;



// Tekst na okręgu
procedure DrawTextOnCircle(const text: String; center: TVector2; radius: Double; startAngle: Double; fontSize: Integer; const color: TColor);
var
  i: Integer;
  angleStep: Double;
  charPos: TVector2;
  ch: String;
begin
  if Length(text) = 0 then Exit;
  angleStep := 360 / Length(text);

  for i := 0 to Length(text) - 1 do
  begin
    charPos.x := center.x + radius * Cos(DegToRad(startAngle + i * angleStep));
    charPos.y := center.y + radius * Sin(DegToRad(startAngle + i * angleStep));
    ch := text[i+1];
    DrawTextCentered(ch, charPos, fontSize, color);
  end;
end;

// Tekst z gradientem (poziomy)
procedure DrawTextGradient(const text: String; pos: TVector2; fontSize: Integer; const color1, color2: TColor);
var
  i: Integer;
  t: Double;
  c: TColor;
  x: Double;
  ch: String;
begin
  x := pos.x;
  for i := 1 to Length(text) do
  begin
    t := (i - 1) / Max(1, (Length(text) - 1));
    c := color1.Blend(color2, t);
    ch := text[i];
    DrawText(ch, Round(x), Round(pos.y), fontSize, c);
    x += MeasureTextWidth(ch, fontSize);
  end;
end;

procedure DrawTextureV(const tex: TTexture; position: TInputVector; const tint: TColor);
begin
  DrawTexture(tex, Round(position.x), Round(position.y), tint);
end;

// Pełny tint RGBA z offscreenem (multiply + destination-in)
procedure DrawTexturePro(const tex: TTexture; const src, dst: TRectangle;
  origin: TVector2; rotationDeg: Double; const tint: TColor);
var
  sx, sy, sw, sh: Double;
  savedAlpha: Double;
  oldComp: String;
  useTint: Boolean;
begin
  if (tex.canvas = nil) or (tex.width <= 0) or (tex.height <= 0) then Exit;

  // Normalizacja źródła (pozwala na ujemne width/height = odwrócenie)
  sx := src.x; sy := src.y; sw := src.width; sh := src.height;
  if sh < 0 then begin sy := sy + sh; sh := -sh; end;
  if sw < 0 then begin sx := sx + sw; sw := -sw; end;

  useTint := not ((tint.r = 255) and (tint.g = 255) and (tint.b = 255));

  // --- WSPÓLNY BLOK TRANSFORMACJI ---
  // ZASADA: po transformacjach punkt (0,0) ma leżeć w miejscu KOTWICY,
  // a lewy-górny róg obrazka rysujemy w (-origin.x, -origin.y).
  gCtx.save;

  // (opcjonalnie) kamera – użyj JEŚLI ją masz (zamiast kombinować w drawImage)
  // Przykład: gCtx.translate(-gCamX, -gCamY);

  // świat: przenosimy układ na punkt dst.x, dst.y (pozycja KOTWICY)
  gCtx.translate(dst.x, dst.y);

  // obrót wokół kotwicy
  if rotationDeg <> 0 then
    gCtx.rotate(DegToRad(rotationDeg));

  // --- TINT / ALFA ---
  savedAlpha := gCtx.globalAlpha;
  gCtx.globalAlpha := savedAlpha * (tint.a / 255.0);

  if useTint then
  begin
    EnsureTintCanvas(Round(sw), Round(sh));
    // wyczyść offscreen
    gTintCtx.clearRect(0, 0, gTintCanvas.width, gTintCanvas.height);

    // 1) wypełnij kolorem
    gTintCtx.fillStyle := 'rgb(' + IntToStr(tint.r) + ',' + IntToStr(tint.g) + ',' + IntToStr(tint.b) + ')';
    gTintCtx.fillRect(0, 0, sw, sh);

    // 2) multiply obraz
    oldComp := gTintCtx.globalCompositeOperation;
    gTintCtx.globalCompositeOperation := 'multiply';
    gTintCtx.drawImage(tex.canvas, sx, sy, sw, sh, 0, 0, sw, sh);

    // 3) destination-in: maska alfa oryginału
    gTintCtx.globalCompositeOperation := 'destination-in';
    gTintCtx.drawImage(tex.canvas, sx, sy, sw, sh, 0, 0, sw, sh);

    // restore blend mode
    gTintCtx.globalCompositeOperation := oldComp;

    // RYSUJEMY KOLOROWANY OFFSCREEN — względem ORIGINU
    gCtx.drawImage(gTintCanvas, 0, 0, sw, sh, -origin.x, -origin.y, dst.width, dst.height);
  end
  else
  begin
    // BEZ TINTU: ten sam układ współrzędnych, ten sam offset względem ORIGINU
    gCtx.drawImage(tex.canvas, sx, sy, sw, sh, -origin.x, -origin.y, dst.width, dst.height);
  end;

  // restore
  gCtx.globalAlpha := savedAlpha;
  gCtx.restore;
end;


function TextureIsReady(const tex: TTexture): Boolean;
begin
  Result := tex.loaded and (tex.width>0) and (tex.height>0) and (tex.canvas<>nil);
end;
procedure WaitTextureReady(const tex: TTexture; const OnReady, OnTimeout: TNoArgProc; msTimeout: Integer = 10000);
var
  t0: Double;
  procedure Check(ts: Double);
  begin
    if TextureIsReady(tex) then
    begin
      if Assigned(OnReady) then OnReady();
    end
    else if (window.performance.now - t0) >= msTimeout then
    begin
      if Assigned(OnTimeout) then OnTimeout();
    end
    else
      window.requestAnimationFrame(@Check);
  end;
begin
  t0 := window.performance.now;
  window.requestAnimationFrame(@Check);
end;

procedure WaitAllTexturesReady(const arr: array of TTexture; const OnReady: TNoArgProc);
  function AllReady: Boolean;
  var
    i: Integer;
  begin
    Result := Length(arr) > 0;
    for i := Low(arr) to High(arr) do
      if not (arr[i].loaded and (arr[i].width > 0) and (arr[i].height > 0) and (arr[i].canvas <> nil)) then
        Exit(False);
  end;
  procedure Check(ts: Double);
  begin
    if AllReady then
    begin
      if Assigned(OnReady) then OnReady();
    end
    else
      window.requestAnimationFrame(@Check);
  end;
begin
  window.requestAnimationFrame(@Check);
end;

{ ====== ZDARZENIA MYSZY ====== }
function GetMouseWheelMove: Integer;
var d: Integer;
begin
  d := gMouseWheelDelta;
  gMouseWheelDelta := 0;
  Result := -d;
end;

function IsMouseButtonDown(button: Integer): Boolean;
begin
  if (button < 0) or (button > 2) then Exit(False);
  Result := gMouseButtonsDown[button];
end;

function IsMouseButtonPressed(button: Integer): Boolean;
begin
  if (button < 0) or (button > 2) then Exit(False);
  Result := (not gMouseButtonsPrev[button]) and gMouseButtonsDown[button];
end;

function IsMouseButtonReleased(button: Integer): Boolean;
begin
  if (button < 0) or (button > 2) then Exit(False);
  Result := gMouseButtonsPrev[button] and (not gMouseButtonsDown[button]);
end;

function GetMousePosition: TInputVector; begin Result := gMousePos; end;
function GetMouseDelta: TInputVector; begin Result := NewVector(gMousePos.x - gMousePrevPos.x, gMousePos.y - gMousePrevPos.y); end;

{ ====== ZARZĄDZANIE CZASEM ====== }
procedure WaitTime(ms: Double);
var
  start: Double;
begin
  // Busy-wait (tylko debug); nie używać w produkcji.
  start := window.performance.now();
  while (window.performance.now() - start) < ms do ;
end;

{ ====== MATEMATYKA ====== }
function Lerp(start, stop, amount: Double): Double;
begin
  Result := start + amount * (stop - start);
end;

function Normalize(value, start, stop: Double): Double;
begin
  if start = stop then Exit(0.0);
  Result := (value - start) / (stop - start);
end;

function Map(value, inStart, inStop, outStart, outStop: Double): Double;
begin
  if inStart = inStop then Exit(outStart);
  Result := outStart + (outStop - outStart) * ((value - inStart) / (inStop - inStart));
end;

function Max(a, b: Double): Double; begin if a > b then Result := a else Result := b; end;
function Min(a, b: Double): Double; begin if a < b then Result := a else Result := b; end;

function Clamp(value, minVal, maxVal: Double): Double;
begin
  if value < minVal then Exit(minVal);
  if value > maxVal then Exit(maxVal);
  Result := value;
end;

function MaxI(a, b: Integer): Integer; begin if a > b then Result := a else Result := b; end;
function MinI(a, b: Integer): Integer; begin if a < b then Result := a else Result := b; end;
function ClampI(value, minVal, maxVal: Integer): Integer;
begin
  if value < minVal then Exit(minVal);
  if value > maxVal then Exit(maxVal);
  Result := value;
end;

function SmoothStep(edge0, edge1, x: Double): Double;
var
  t: Double;
begin
  t := Clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  Result := t * t * (3.0 - 2.0 * t);
end;

function Approach(current, target, delta: Double): Double;
begin
  if current < target then
    Result := Min(current + delta, target)
  else if current > target then
    Result := Max(current - delta, target)
  else
    Result := target;
end;

{ ====== DŹWIĘK ====== }
function PlaySound(const url: String): Boolean;
var
  audio: TJSHTMLAudioElement;
begin
  Result := False;
  audio := TJSHTMLAudioElement(document.createElement('audio'));
  {$ifdef WILGA_DEBUG} DBG_Inc(dbg_AudioElemsAlive); {$endif}
  audio.src := url;
  try
    audio.play();
    SetLength(gActiveSounds, Length(gActiveSounds) + 1);
    gActiveSounds[High(gActiveSounds)] := audio;
    Result := True;
  except
    Result := False;
  end;
end;

function PlaySoundLoop(const url: String): Boolean;
var
  audio: TJSHTMLAudioElement;
begin
  Result := False;
  audio := TJSHTMLAudioElement(document.createElement('audio'));
  {$ifdef WILGA_DEBUG} DBG_Inc(dbg_AudioElemsAlive); {$endif}
  audio.src := url;
  audio.loop := True;
  try
    audio.play();
    SetLength(gActiveSounds, Length(gActiveSounds) + 1);
    gActiveSounds[High(gActiveSounds)] := audio;
    Result := True;
  except
    Result := False;
  end;
end;

procedure StopAllSounds;
var
  i: Integer;
begin
  for i := 0 to High(gActiveSounds) do
  begin
    gActiveSounds[i].pause();
    gActiveSounds[i].src := '';
  end;
  {$ifdef WILGA_DEBUG}
  // gActiveSounds zawiera wszystkie tymczasowe audio utworzone przez PlaySound/Loop
  while Length(gActiveSounds) > 0 do
  begin
    // każdy element usuwamy z licznika
    DBG_Dec(dbg_AudioElemsAlive);
    SetLength(gActiveSounds, Length(gActiveSounds)-1);
  end;
{$else}
  SetLength(gActiveSounds, 0);
{$endif}

  SetLength(gActiveSounds, 0);
end;

type
  TSoundPoolItem = record
    el: TJSHTMLAudioElement;
  end;

  TSoundPool = record
    url: String;
    items: array of TSoundPoolItem; // pre-załadowane elementy
    nextIdx: Integer;
    volume: Double; // 0..1
    looped: Boolean;
    valid: Boolean;
  end;

var
  gSoundPools: array of TSoundPool;

function  LoadSoundEx(const url: String; voices: Integer = 4; volume: Double = 1.0; looped: Boolean = False): TSoundHandle;
var
  i: Integer;
  h: Integer;
  a: TJSHTMLAudioElement;
begin
  if voices <= 0 then voices := 1;
  if volume < 0 then volume := 0 else if volume > 1 then volume := 1;

  // nowy slot
  SetLength(gSoundPools, Length(gSoundPools)+1);
  h := High(gSoundPools);
  gSoundPools[h].url := url;
  gSoundPools[h].nextIdx := 0;
  gSoundPools[h].volume := volume;
  gSoundPools[h].looped := looped;
  gSoundPools[h].valid := True;

  SetLength(gSoundPools[h].items, voices);
  for i := 0 to voices-1 do
  begin
    a := TJSHTMLAudioElement(document.createElement('audio'));
    {$ifdef WILGA_DEBUG} DBG_Inc(dbg_AudioElemsAlive); {$endif}

    a.src := url;
    a.preload := 'auto';
    a.loop := looped;
    a.volume := volume;
    gSoundPools[h].items[i].el := a;
  end;

  Result := h;
end;

procedure UnloadSoundEx(handle: TSoundHandle);
var
  i: Integer;
begin
  if (handle < 0) or (handle > High(gSoundPools)) then Exit;
  if not gSoundPools[handle].valid then Exit;

  for i := 0 to High(gSoundPools[handle].items) do
  begin
    try
      gSoundPools[handle].items[i].el.pause();
      gSoundPools[handle].items[i].el.src := '';
    except end;
    {$ifdef WILGA_DEBUG} DBG_Dec(dbg_AudioElemsAlive); {$endif}
  end;

  gSoundPools[handle].valid := False;
  SetLength(gSoundPools[handle].items, 0);
end;

procedure PlaySoundEx(handle: TSoundHandle);
begin
  PlaySoundEx(handle, -1.0); // -1 → użyj domyślnej głośności z poola
end;

procedure PlaySoundEx(handle: TSoundHandle; volume: Double);
var
  pool: ^TSoundPool;
  a: TJSHTMLAudioElement;
begin
  if (handle < 0) or (handle > High(gSoundPools)) then Exit;
  if not gSoundPools[handle].valid then Exit;

  pool := @gSoundPools[handle];
  if Length(pool^.items) = 0 then Exit;

  a := pool^.items[pool^.nextIdx].el;
  pool^.nextIdx := (pool^.nextIdx + 1) mod Length(pool^.items);

  // reset i parametry
  try
    if volume >= 0 then a.volume := volume
                   else a.volume := pool^.volume;
    a.loop := pool^.looped;

    try a.currentTime := 0; except end;

    a.play();
  except
    // ignoruj (autoplay blokada)
  end;
end;

procedure StopSoundEx(handle: TSoundHandle);
var
  i: Integer;
  a: TJSHTMLAudioElement;
begin
  if (handle < 0) or (handle > High(gSoundPools)) then Exit;
  if not gSoundPools[handle].valid then Exit;

  for i := 0 to High(gSoundPools[handle].items) do
  begin
    a := gSoundPools[handle].items[i].el;
    try
      a.pause();
      try a.currentTime := 0; except end;
    except end;
  end;
end;

procedure SetSoundVolume(handle: TSoundHandle; volume: Double);
var
  i: Integer;
begin
  if (handle < 0) or (handle > High(gSoundPools)) then Exit;
  if not gSoundPools[handle].valid then Exit;
  if volume < 0 then volume := 0 else if volume > 1 then volume := 1;

  gSoundPools[handle].volume := volume;
  for i := 0 to High(gSoundPools[handle].items) do
    gSoundPools[handle].items[i].el.volume := volume;
end;

procedure SetSoundLoop(handle: TSoundHandle; looped: Boolean);
var
  i: Integer;
begin
  if (handle < 0) or (handle > High(gSoundPools)) then Exit;
  if not gSoundPools[handle].valid then Exit;

  gSoundPools[handle].looped := looped;
  for i := 0 to High(gSoundPools[handle].items) do
    gSoundPools[handle].items[i].el.loop := looped;
end;

{ ====== FABRYKI ====== }
function NewVector(ax, ay: Double): TInputVector; begin Result.x := ax; Result.y := ay; end;
function Vector2Create(x, y: Double): TInputVector; begin Result := NewVector(x, y); end;
function ColorRGBA(ar, ag, ab, aa: Integer): TColor; begin Result.r:=ar; Result.g:=ag; Result.b:=ab; Result.a:=aa; end;
function ColorCreate(r, g, b, a: Integer): TColor; begin Result := ColorRGBA(r,g,b,a); end;
function RectangleCreate(x, y, width, height: Double): TRectangle; begin Result.x:=x; Result.y:=y; Result.width:=width; Result.height:=height; end;
function LineCreate(startX, startY, endX, endY: Double): TLine; begin Result.startPoint := NewVector(startX, startY); Result.endPoint := NewVector(endX, endY); end;
function TriangleCreate(p1x, p1y, p2x, p2y, p3x, p3y: Double): TTriangle; begin Result.p1 := NewVector(p1x, p1y); Result.p2 := NewVector(p2x, p2y); Result.p3 := NewVector(p3x, p3y); end;

{ ====== WEKTORY ====== }
function Vector2Zero: TInputVector; begin Result := NewVector(0,0); end;
function Vector2One: TInputVector; begin Result := NewVector(1,1); end;
function Vector2Add(v1, v2: TInputVector): TInputVector; begin Result := NewVector(v1.x+v2.x, v1.y+v2.y); end;
function Vector2Subtract(v1, v2: TInputVector): TInputVector; begin Result := NewVector(v1.x-v2.x, v1.y-v2.y); end;
function Vector2Scale(v: TInputVector; scale: Double): TInputVector; begin Result := NewVector(v.x*scale, v.y*scale); end;
function Vector2Length(v: TInputVector): Double; begin Result := Sqrt(v.x*v.x + v.y*v.y); end;

function Vector2Normalize(v: TInputVector): TInputVector;
var len: Double;
begin
  len := Vector2Length(v);
  if len > 0 then Result := Vector2Scale(v, 1.0/len) else Result := Vector2Zero;
end;

function Vector2Rotate(v: TInputVector; radians: Double): TInputVector;
var c, s: Double;
begin
  c := Cos(radians); s := Sin(radians);
  Result := NewVector(v.x*c - v.y*s, v.x*s + v.y*c);
end;

function Vector2RotateDeg(v: TInputVector; deg: Double): TInputVector;
begin
  Result := Vector2Rotate(v, DegToRad(deg));
end;

function Vector2Dot(a, b: TInputVector): Double; begin Result := a.x*b.x + a.y*b.y; end;
function Vector2Perp(v: TInputVector): TInputVector; begin Result := NewVector(-v.y, v.x); end;
function Vector2Lerp(a, b: TInputVector; t: Double): TInputVector; begin Result := NewVector(Lerp(a.x,b.x,t), Lerp(a.y,b.y,t)); end;
function Vector2Distance(v1, v2: TInputVector): Double; begin Result := Sqrt(Sqr(v1.x - v2.x) + Sqr(v1.y - v2.y)); end;
function Vector2Angle(v1, v2: TInputVector): Double; begin Result := ArcTan2(v2.y - v1.y, v2.x - v1.x); end;

{ ====== OKNO / INICJALIZACJA ====== }
procedure InitWindow(awidth, aheight: Integer; const title: String);
var
  el: TJSElement;
  cw, ch: Integer;
  opts: TJSObject;
  i: Integer;
begin
  // Jeśli DOM niegotowy – opóźnij inicjalizację
  if (document.body = nil) then
  begin
    window.addEventListener('load', TJSRawEventHandler(
      procedure (e: TJSEvent)
      begin
        InitWindow(awidth, aheight, title);
      end
    ));
    Exit;
  end;

  gStartTime := window.performance.now();
  document.title := title;
  cw := awidth; ch := aheight;

  // Canvas
  el := document.querySelector('#game');
  if (el = nil) then
  begin
    gCanvas := TJSHTMLCanvasElement(document.createElement('canvas'));
    gCanvas.id := 'game';
    document.body.appendChild(gCanvas);
  end
  else
    gCanvas := TJSHTMLCanvasElement(el);

  // Rozmiary CSS (logiczne)
  gCanvas.style.setProperty('width',  IntToStr(cw) + 'px');
  gCanvas.style.setProperty('height', IntToStr(ch) + 'px');

  // DPR / HiDPI
  gDPR := window.devicePixelRatio;
  if (not gUseHiDPI) or (gDPR <= 0) then gDPR := 1;
  gCanvas.width  := Round(cw * gDPR);
  gCanvas.height := Round(ch * gDPR);

  // Kontekst 2D
  opts := TJSObject.new;
  opts['alpha'] := gCanvasAlpha;
  gCtx := TJSCanvasRenderingContext2D(gCanvas.getContext('2d', opts));
  if gCtx = nil then
    gCtx := TJSCanvasRenderingContext2D(gCanvas.getContext('2d'));

  gCtx.setTransform(gDPR, 0, 0, gDPR, 0, 0);
  TJSObject(gCtx)['imageSmoothingEnabled'] := gImageSmoothingWanted;

  // ===== Stany wejścia itp. =====
  gKeys := TJSObject.new;
  gKeysPressed := TJSObject.new;
  gKeysReleased := TJSObject.new;

  gMousePos := NewVector(cw / 2, ch / 2);
  gMousePrevPos := gMousePos;
  for i := 0 to 2 do
  begin
    gMouseButtonsDown[i] := false;
    gMouseButtonsPrev[i] := false;
  end;
  gMouseWheelDelta := 0;

  gProfileData := TJSObject.new;

  // Focus na canvasie
  gCanvas.tabIndex := 0;
  gCanvas.style.setProperty('outline', 'none');
  gCanvas.focus();

  // ===== Handlery (zapisywane w globalnych zmiennych) =====

  // --- Klawiatura ---
   onKeyDownH := function (event: TJSEvent): boolean
  var
    e: TJSKeyBoardEvent;
    k: String;
  begin
    e := TJSKeyBoardEvent(event);

    // --- Fallback i normalizacja nazwy klawisza ---
    k := e.code;
    if (k = '') then k := e.key;          // np. 'Right'
    if (k = 'Right') then k := 'ArrowRight';
    if (k = 'Left')  then k := 'ArrowLeft';
    if (k = 'Up')    then k := 'ArrowUp';
    if (k = 'Down')  then k := 'ArrowDown';

    // Zablokuj default przeglądarki dla nawigacyjnych:
    if (k = KEY_SPACE) or
       (k = KEY_UP) or (k = KEY_DOWN) or (k = KEY_LEFT) or (k = KEY_RIGHT) or
       (k = 'PageUp') or (k = 'PageDown') or (k = 'Home') or (k = 'End') or
       (k = KEY_TAB) then
    begin
      e.preventDefault();
      e.stopPropagation();
    end;

    if not gKeys.hasOwnProperty(k) then
    begin
      gKeys[k] := false;
      gKeysPressed[k] := false;
      gKeysReleased[k] := false;
    end;

    if not Boolean(gKeys[k]) then
      gKeysPressed[k] := true;

    gKeys[k] := true;
    if (gCloseOnEscape) and (k = KEY_ESCAPE) then gWantsClose := true;

    Result := True;
  end;

  onKeyUpH := function (event: TJSEvent): boolean
  var
    e: TJSKeyBoardEvent;
    k: String;
  begin
    e := TJSKeyBoardEvent(event);

    k := e.code;
    if (k = '') then k := e.key;
    if (k = 'Right') then k := 'ArrowRight';
    if (k = 'Left')  then k := 'ArrowLeft';
    if (k = 'Up')    then k := 'ArrowUp';
    if (k = 'Down')  then k := 'ArrowDown';

    if not gKeys.hasOwnProperty(k) then
    begin
      gKeys[k] := false;
      gKeysPressed[k] := false;
      gKeysReleased[k] := false;
    end;

    gKeys[k] := false;
    gKeysReleased[k] := true;

    Result := True;
  end;


  window.addEventListener('keydown', onKeyDownH); // capture = true
  window.addEventListener('keyup',   onKeyUpH);

  // --- Mysz ---
  onMouseMoveH := function (event: TJSEvent): boolean
  var
    e: TJSMouseEvent;
  begin
    e := TJSMouseEvent(event);
    gMousePrevPos := gMousePos;
    gMousePos.x := e.offsetX;
    gMousePos.y := e.offsetY;
    Result := True;
  end;

  onMouseDownH := function (event: TJSEvent): boolean
  var
    e: TJSMouseEvent;
  begin
    e := TJSMouseEvent(event);
    if (e.button >= 0) and (e.button <= 2) then
      gMouseButtonsDown[e.button] := true;
    Result := True;
  end;

  onMouseUpH := function (event: TJSEvent): boolean
  var
    e: TJSMouseEvent;
  begin
    e := TJSMouseEvent(event);
    if (e.button >= 0) and (e.button <= 2) then
      gMouseButtonsDown[e.button] := false;
    Result := True;
  end;

  onWheelH := function (event: TJSEvent): boolean
  var
    e: TJSWheelEvent;
  begin
    e := TJSWheelEvent(event);
    if e.deltaY > 0 then Inc(gMouseWheelDelta) else
    if e.deltaY < 0 then Dec(gMouseWheelDelta);
    e.preventDefault();
    Result := True;
  end;

  gCanvas.addEventListener('mousemove', onMouseMoveH);
  gCanvas.addEventListener('mousedown', onMouseDownH);
  gCanvas.addEventListener('mouseup',   onMouseUpH);
  gCanvas.addEventListener('wheel',     onWheelH);

  // --- Dotyk (RawEventHandler zostaje procedurą) ---
  onTouchStartH := TJSRawEventHandler(procedure (event: TJSEvent)
  var
    touches: TJSArray; first: TJSObject;
  begin
    touches := TJSArray(event['touches']);
    if (touches <> nil) and (touches.length > 0) then
    begin
      first := TJSObject(touches[0]);
      gMousePos.x := Double(first['clientX']) - gCanvas.offsetLeft;
      gMousePos.y := Double(first['clientY']) - gCanvas.offsetTop;
      gMouseButtonsDown[0] := true;
    end;
    event.preventDefault();
  end);

  onTouchMoveH := TJSRawEventHandler(procedure (event: TJSEvent)
  var
    touches: TJSArray; first: TJSObject;
  begin
    touches := TJSArray(event['touches']);
    if (touches <> nil) and (touches.length > 0) then
    begin
      first := TJSObject(touches[0]);
      gMousePos.x := Double(first['clientX']) - gCanvas.offsetLeft;
      gMousePos.y := Double(first['clientY']) - gCanvas.offsetTop;
    end;
    event.preventDefault();
  end);

  onTouchEndH := TJSRawEventHandler(procedure (event: TJSEvent)
  begin
    gMouseButtonsDown[0] := false;
    event.preventDefault();
  end);

  gCanvas.addEventListener('touchstart', onTouchStartH);
  gCanvas.addEventListener('touchmove',  onTouchMoveH);
  gCanvas.addEventListener('touchend',   onTouchEndH);

  // --- Blur / Click ---
  onBlurH := function (event: TJSEvent): boolean
  var
    key: String;
  begin
    for key in TJSObject.getOwnPropertyNames(gKeys) do
      gKeys[key] := false;
    gMouseButtonsDown[0] := false;
    gMouseButtonsDown[1] := false;
    gMouseButtonsDown[2] := false;
    Result := True;
  end;

  onClickH := function (event: TJSEvent): boolean
  begin
    gCanvas.focus();
    Result := True;
  end;

  gCanvas.addEventListener('blur', onBlurH);
  gCanvas.addEventListener('click', onClickH);

  // Start
  gRunning := true;
    gWantsClose := False;  // <<< resetujemy żądanie zamknięcia
 asm
  document.addEventListener('contextmenu', function(e) {
    e.preventDefault();
  });
end;

end;





procedure CloseWindow;
var
  i: Integer;
begin
  // --- DŹWIĘK ---
  StopAllSounds;
  for i := 0 to High(gSoundPools) do
    if gSoundPools[i].valid then
      UnloadSoundEx(i);
  SetLength(gSoundPools, 0);

  // --- PARTICLE SYSTEMS ---
  for i := 0 to High(gParticleSystems) do
    if Assigned(gParticleSystems[i]) then
      gParticleSystems[i].Free;
  SetLength(gParticleSystems, 0);

  // --- POOLE PAMIĘCI ---
  SetLength(gVectorPool, 0);
  SetLength(gMatrixPool, 0);

  // --- OFFSCREEN DO TINTU ---
  if gTintCanvas <> nil then
  begin
    try
      gTintCanvas.width := 0;
      gTintCanvas.height := 0;
    except end;
    gTintCanvas := nil;
    gTintCtx := nil;
  end;

  // --- ODCZEPIENIE NASŁUCHIWACZY (2-param. wersje) ---
  if Assigned(gCanvas) then
  begin
    gCanvas.removeEventListener('mousemove', onMouseMoveH);
    gCanvas.removeEventListener('mousedown', onMouseDownH);
    gCanvas.removeEventListener('mouseup',   onMouseUpH);
    gCanvas.removeEventListener('wheel',     onWheelH);

    gCanvas.removeEventListener('touchstart', onTouchStartH);
    gCanvas.removeEventListener('touchmove',  onTouchMoveH);
    gCanvas.removeEventListener('touchend',   onTouchEndH);

    gCanvas.removeEventListener('blur',  onBlurH);
    gCanvas.removeEventListener('click', onClickH);
  end;

  window.removeEventListener('keydown', onKeyDownH);
  window.removeEventListener('keyup',   onKeyUpH);

  // Zerowanie referencji do handlerów (pozwala GC uwolnić closury)
  onKeyDownH := nil; onKeyUpH := nil;
  onMouseMoveH := nil; onMouseDownH := nil; onMouseUpH := nil; onWheelH := nil;
  onTouchStartH := nil; onTouchMoveH := nil; onTouchEndH := nil;
  onBlurH := nil; onClickH := nil;

  // --- STOSY KONTEXTÓW / BATCH / KLUCZE ---
  SetLength(gCtxStack, 0);
  SetLength(gCanvasStack, 0);

  SetLength(gLineBatch, 0);
  gLineBatchActive := False;

  gKeys := nil;
  gKeysPressed := nil;
  gKeysReleased := nil;

  // --- PROFILER ---
  SetLength(gProfileStack, 0);
  gProfileData := TJSObject.new;

  // --- ZEROWANIE KONTEKSTU I CANVASA ---
  gCtx := nil;
  if gCanvas <> nil then
  begin
    try
      gCanvas.width := 0;
      gCanvas.height := 0;
      // (opcjonalnie) usuń canvas z DOM, jeśli chcesz:
      if gCanvas.parentElement <> nil then
        gCanvas.parentElement.removeChild(gCanvas);
    except end;
    gCanvas := nil;
  end;

  gRunning := False;

  {$ifdef WILGA_DEBUG}
  try
    console.log(DumpLeakReport);
  except end;
  {$endif}
end;



procedure SetFPS(fps: Integer);
begin
  SetTargetFPS(fps);
end;

procedure SetTargetFPS(fps: Integer);
begin
  if fps < 0 then fps := 0;
  gTargetFPS := fps;
end;

procedure SetWindowSize(width, height: Integer);
begin
  gCanvas.style.setProperty('width', IntToStr(width) + 'px');
  gCanvas.style.setProperty('height', IntToStr(height) + 'px');
  gCanvas.width := Round(width * gDPR);
  gCanvas.height := Round(height * gDPR);
  gCtx.setTransform(gDPR, 0, 0, gDPR, 0, 0);
end;

procedure SetWindowTitle(const title: String);
begin
  document.title := title;
end;

procedure ToggleFullscreen;
begin
  asm
    var doc = document;
    var el  = document.getElementById('game');

    var isFS = doc.fullscreenElement
            || doc.webkitFullscreenElement
            || doc.mozFullScreenElement
            || doc.msFullscreenElement;

    if (!isFS) {
      if (el && el.requestFullscreen) el.requestFullscreen();
      else if (el && el.webkitRequestFullscreen) el.webkitRequestFullscreen();
      else if (el && el.mozRequestFullScreen) el.mozRequestFullScreen();
      else if (el && el.msRequestFullscreen) el.msRequestFullscreen();
    } else {
      if (doc.exitFullscreen) doc.exitFullscreen();
      else if (doc.webkitExitFullscreen) doc.webkitExitFullscreen();
      else if (doc.mozCancelFullScreen) doc.mozCancelFullScreen();
      else if (doc.msExitFullscreen) doc.msExitFullscreen();
    }
  end;
end;

{ ====== RYSOWANIE PODSTAWOWE ====== }
procedure BeginDrawing;
begin
  gCtx.save;
end;

procedure EndDrawing;
begin
  gCtx.restore;

  // Update mouse previous state
  gMouseButtonsPrev[0] := gMouseButtonsDown[0];
  gMouseButtonsPrev[1] := gMouseButtonsDown[1];
  gMouseButtonsPrev[2] := gMouseButtonsDown[2];
  gMousePrevPos := gMousePos;

  // Reset key pressed/released states (frame-based)
  gKeysPressed := TJSObject.new;
  gKeysReleased := TJSObject.new;
  gMouseWheelDelta := 0;
end;

procedure ClearBackground(const color: TColor);
var Wcss, Hcss: Integer;
begin
  Wcss := GetScreenWidth; Hcss := GetScreenHeight;
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  gCtx.fillRect(0, 0, Wcss, Hcss);
end;

procedure DrawRectangle(x, y, w, h: double; const color: TColor);
begin
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  gCtx.fillRect(x, y, w, h);
end;
function RectangleFromCenter(cx, cy, w, h: Double): TRectangle;
begin
  Result := RectangleCreate(cx - w/2, cy - h/2, w, h);
end;

function RectCenter(const R: TRectangle): TVector2;
begin
  Result := Vector2Create(R.x + R.width/2, R.y + R.height/2);
end;

procedure DrawRectangleRec(const rec: TRectangle; const color: TColor);
begin
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  gCtx.fillRect(rec.x, rec.y, rec.width, rec.height);  // bez Round!
end;


procedure DrawCircle(cx, cy, radius: double; const color: TColor);
begin
  gCtx.beginPath;
  gCtx.arc(cx, cy, radius, 0, 2 * Pi);
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  gCtx.fill;
end;

procedure DrawCircleLines(cx, cy, radius, thickness: double; const color: TColor);
begin
  gCtx.beginPath;
  gCtx.arc(cx, cy, radius, 0, 2 * Pi);
  gCtx.lineWidth := thickness;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.stroke;
end;
procedure DrawCircleV(center: TInputVector; radius: double; const color: TColor);
begin
  if Assigned(gCtx) then
  begin
    // rysuj w world-space na floatach — transform (BeginMode2D) zrobi resztę
    gCtx.beginPath;
    gCtx.arc(center.x, center.y, radius, 0, 2 * Pi);
    gCtx.fillStyle := ColorToCanvasRGBA(color);
    gCtx.fill;
  end
  else
  begin
    // awaryjnie (bez kontekstu) nic nie rób albo użyj DrawCircle
  end;
end;



procedure DrawEllipse(cx, cy, rx, ry: Integer; const color: TColor);
begin
  gCtx.beginPath;
  gCtx.ellipse(cx, cy, rx, ry, 0, 0, 2 * Pi);
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  gCtx.fill;
end;
procedure DrawEllipseLines(cx, cy, rx, ry, thickness: Integer; const color: TColor);
begin
  if (rx <= 0) or (ry <= 0) then Exit;

  gCtx.beginPath;
  gCtx.ellipse(cx, cy, rx, ry, 0, 0, 2*Pi);
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.lineWidth := thickness;
  gCtx.stroke;
end;

procedure DrawEllipseV(center: TInputVector; radiusX, radiusY: Double; const color: TColor);
begin
  DrawEllipse(Round(center.x), Round(center.y), Round(radiusX), Round(radiusY), color);
end;

procedure DrawText(const text: String; x, y, size: Integer; const color: TColor);
begin
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  EnsureFont(size);
  gCtx.textBaseline := 'top';
  gCtx.fillText(text, x, y);
end;

function MeasureTextWidth(const text: String; size: Integer): Double;
begin
  gCtx.save;
  EnsureFont(size);
  Result := gCtx.measureText(text).width;
  gCtx.restore;
end;

function MeasureTextHeight(const text: String; size: Integer): Double;
var m: TJSObject;
begin
  gCtx.save;
  EnsureFont(size);
  m := TJSObject(gCtx.measureText(text));
  if m.hasOwnProperty('actualBoundingBoxAscent') and m.hasOwnProperty('actualBoundingBoxDescent') then
    Result := Double(m['actualBoundingBoxAscent']) + Double(m['actualBoundingBoxDescent'])
  else
    Result := size * 1.2;
  gCtx.restore;
end;

procedure SetTextFont(const cssFont: String);
begin
  gCtx.font := cssFont;
end;

procedure SetTextAlign(const hAlign: String; const vAlign: String);
begin
  gCtx.textAlign := hAlign;
  gCtx.textBaseline := vAlign;
end;

procedure DrawTextCentered(const text: String; cx, cy, size: Integer; const color: TColor);
begin
  gCtx.save;
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  EnsureFont(size);
  gCtx.textAlign := 'center';
  gCtx.textBaseline := 'middle';
  gCtx.fillText(text, cx, cy);
  gCtx.restore;
end;

// Tekst z obramowaniem (outline)
procedure DrawTextOutline(const text: String; pos: TVector2; fontSize: Integer; const color, outlineColor: TColor; thickness: Integer);
var
  dx, dy: Integer;
begin
  for dy := -thickness to thickness do
    for dx := -thickness to thickness do
      if (dx <> 0) or (dy <> 0) then
        DrawText(text, Round(pos.x) + dx, Round(pos.y) + dy, fontSize, outlineColor);
  DrawText(text, Round(pos.x), Round(pos.y), fontSize, color);
end;


procedure DrawTextPro(const text: String; x, y, size: Integer; const color: TColor;
                     rotation: Double; originX, originY: Double);
begin
  gCtx.save;
  gCtx.translate(x + originX, y + originY);
  gCtx.rotate(rotation);
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  EnsureFont(size);
  gCtx.textAlign := 'left';
  gCtx.textBaseline := 'top';
  gCtx.fillText(text, -originX, -originY);
  gCtx.restore;
end;


// === Text helpers with explicit font ===
procedure DrawTextWithFont(const text: String; x, y, size: Integer; const family: String; const color: TColor);
begin
  gCtx.save;
  if family <> '' then
    gCtx.font := IntToStr(size) + 'px "' + family + '", system-ui, sans-serif'
  else EnsureFont(size);
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  gCtx.textBaseline := 'top';
  gCtx.fillText(text, x, y);
  gCtx.restore;
end;

function MeasureTextWidthWithFont(const text: String; size: Integer; const family: String): Double;
begin
  gCtx.save;
  if family <> '' then
    gCtx.font := IntToStr(size) + 'px "' + family + '", system-ui, sans-serif'
  else EnsureFont(size);
  Result := gCtx.measureText(text).width;
  gCtx.restore;
end;

function MeasureTextHeightWithFont(const text: String; size: Integer; const family: String): Double;
var m: TJSObject;
begin
  gCtx.save;
  if family <> '' then
    gCtx.font := IntToStr(size) + 'px "' + family + '", system-ui, sans-serif'
  else EnsureFont(size);
  m := TJSObject(gCtx.measureText(text));
  if m.hasOwnProperty('actualBoundingBoxAscent') and m.hasOwnProperty('actualBoundingBoxDescent') then
    Result := Double(m['actualBoundingBoxAscent']) + Double(m['actualBoundingBoxDescent'])
  else
    Result := size; // fallback
  gCtx.restore;
end;
{ ====== RYSOWANIE ROZSZERZONE ====== }
procedure DrawRectangleProDeg(const rec: TRectangle; origin: TVector2; rotationDeg: Double; const color: TColor);
begin
  gCtx.save;
  gCtx.translate(rec.x + origin.x, rec.y + origin.y);
  gCtx.rotate(DegToRad(rotationDeg));
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  gCtx.fillRect(-origin.x, -origin.y, rec.width, rec.height);
  gCtx.restore;
end;

procedure DrawPolyDeg(center: TVector2; sides: Integer; radius: Double; rotationDeg: Double; const color: TColor);
var
  i: Integer;
  ang: Double;
  rot: Double;
begin
  if sides < 3 then Exit;
  rot := DegToRad(rotationDeg);
  gCtx.save;
  gCtx.beginPath;
  for i := 0 to sides-1 do
  begin
    ang := rot + (2*Pi * i / sides);
    if i = 0 then
      gCtx.moveTo(center.x + Cos(ang)*radius, center.y + Sin(ang)*radius)
    else
      gCtx.lineTo(center.x + Cos(ang)*radius, center.y + Sin(ang)*radius);
  end;
  gCtx.closePath;
  gCtx.fillStyle := ColorToCanvasRGBA(color);
  gCtx.fill;
  gCtx.restore;
end;

procedure DrawRectanglePro(const rec: TRectangle; origin: TVector2; rotation: Double; const color: TColor);
begin
  DrawRectangleProDeg(rec, origin, RadToDeg(rotation), color);
end;

procedure DrawPoly(center: TVector2; sides: Integer; radius: Double; rotation: Double; const color: TColor);
begin
  DrawPolyDeg(center, sides, radius, RadToDeg(rotation), color);
end;

procedure DrawCircleGradient(cx, cy: Integer; radius: Integer; const inner, outer: TColor);
var
  grad: TJSCanvasGradient;
begin
  grad := gCtx.createRadialGradient(cx, cy, 0, cx, cy, radius);
  grad.addColorStop(0, ColorToCanvasRGBA(inner));
  grad.addColorStop(1, ColorToCanvasRGBA(outer));
  gCtx.fillStyle := grad;
  gCtx.beginPath;
  gCtx.arc(cx, cy, radius, 0, 2*Pi);
  gCtx.fill;
end;

{ ====== TEKSTURY / RENDER-TO-TEXTURE ====== }
function MakeOffscreenCanvas(w, h: Integer): TJSHTMLCanvasElement;
begin
  Result := TJSHTMLCanvasElement(document.createElement('canvas'));
  Result.width := w;
  Result.height := h;
end;

function LoadRenderTexture(w, h: Integer): TRenderTexture2D;
begin
  Result.texture.canvas := MakeOffscreenCanvas(w, h);
  Result.texture.width := w;
  Result.texture.height := h;
  Result.texture.loaded := True;
  {$ifdef WILGA_DEBUG}
DBG_Inc(dbg_TexturesAlive);
DBG_Inc(dbg_RenderTexturesAlive);
{$endif}
end;

procedure BeginTextureMode(const rt: TRenderTexture2D);
begin
  SetLength(gCtxStack, Length(gCtxStack)+1);
  gCtxStack[High(gCtxStack)] := gCtx;

  SetLength(gCanvasStack, Length(gCanvasStack)+1);
  gCanvasStack[High(gCanvasStack)] := gCanvas;

  gCanvas := rt.texture.canvas;
  gCtx := TJSCanvasRenderingContext2D(gCanvas.getContext('2d'));
  gCtx.save;
end;

procedure EndTextureMode;
begin
  gCtx.restore;
  if Length(gCtxStack) > 0 then
  begin
    gCtx := gCtxStack[High(gCtxStack)];
    SetLength(gCtxStack, Length(gCtxStack)-1);
  end;
  if Length(gCanvasStack) > 0 then
  begin
    gCanvas := gCanvasStack[High(gCanvasStack)];
    SetLength(gCanvasStack, Length(gCanvasStack)-1);
  end;
end;

function CreateTextureFromCanvas(canvas: TJSHTMLCanvasElement): TTexture;
begin
  Result.canvas := canvas;
  Result.width := canvas.width;
  Result.height := canvas.height;
  Result.loaded := True;
  {$ifdef WILGA_DEBUG} DBG_Inc(dbg_TexturesAlive); {$endif}

end;

{ ====== WEJŚCIE ====== }
procedure ClearAllKeys;
var
  key: String;
begin
  for key in TJSObject.getOwnPropertyNames(gKeys) do
  begin
    gKeys[key] := false;
    gKeysPressed[key] := false;
    gKeysReleased[key] := false;
  end;
end;
function KeyCodeToCode(keyCode: Integer): String;
begin
  case keyCode of
    // Litery
    65..90:   Exit('Key' + Chr(keyCode));   // A..Z → KeyA..KeyZ
    // Górny rząd cyfr
    48..57:   Exit('Digit' + Chr(keyCode)); // 0..9 → Digit0..Digit9

    // Spacje i kontrolne
    32: Exit(KEY_SPACE);
    27: Exit(KEY_ESCAPE);
    13: Exit(KEY_ENTER);
     9: Exit(KEY_TAB);

    // Modyfikatory (traktujemy generycznie jako 'Left' – patrz krok 4)
    16: Exit(KEY_SHIFT);
    17: Exit(KEY_CONTROL);
    18: Exit(KEY_ALT);
    91,92: Exit(KEY_META);     // Windows / Command
    93:    Exit(KEY_CONTEXT);  // Context menu

    // Strzałki
    37: Exit(KEY_LEFT);
    38: Exit(KEY_UP);
    39: Exit(KEY_RIGHT);
    40: Exit(KEY_DOWN);

    // Edycja / nawigacja
     8: Exit(KEY_BACKSPACE);
    46: Exit(KEY_DELETE);
    45: Exit(KEY_INSERT);
    36: Exit(KEY_HOME);
    35: Exit(KEY_END);
    33: Exit(KEY_PAGEUP);
    34: Exit(KEY_PAGEDOWN);

    // Funkcyjne
    112: Exit(KEY_F1);   113: Exit(KEY_F2);   114: Exit(KEY_F3);
    115: Exit(KEY_F4);   116: Exit(KEY_F5);   117: Exit(KEY_F6);
    118: Exit(KEY_F7);   119: Exit(KEY_F8);   120: Exit(KEY_F9);
    121: Exit(KEY_F10);  122: Exit(KEY_F11);  123: Exit(KEY_F12);

    // Symbole (wartości keyCode wg typowych map w Chromium/Gecko)
    192: Exit(KEY_BACKQUOTE);   // `
    189: Exit(KEY_MINUS);       // -
    187: Exit(KEY_EQUAL);       // =
    219: Exit(KEY_BRACKETLEFT); // [
    221: Exit(KEY_BRACKETRIGHT);// ]
    220: Exit(KEY_BACKSLASH);   // \
    186: Exit(KEY_SEMICOLON);   // ;
    222: Exit(KEY_QUOTE);       // '
    188: Exit(KEY_COMMA);       // ,
    190: Exit(KEY_PERIOD);      // .
    191: Exit(KEY_SLASH);       // /

    // Numpad
    96: Exit(KEY_NUMPAD0);  97: Exit(KEY_NUMPAD1);  98: Exit(KEY_NUMPAD2);
    99: Exit(KEY_NUMPAD3); 100: Exit(KEY_NUMPAD4); 101: Exit(KEY_NUMPAD5);
   102: Exit(KEY_NUMPAD6); 103: Exit(KEY_NUMPAD7); 104: Exit(KEY_NUMPAD8);
   105: Exit(KEY_NUMPAD9);
   106: Exit(KEY_NUMPAD_MULTIPLY);
   107: Exit(KEY_NUMPAD_ADD);
   109: Exit(KEY_NUMPAD_SUBTRACT);
   110: Exit(KEY_NUMPAD_DECIMAL);
   111: Exit(KEY_NUMPAD_DIVIDE);
  end;
  Result := ''; // fallback – brak mapy
end;



function IsKeyPressed(keyCode: Integer): Boolean; overload;
var c: String;
begin
  c := KeyCodeToCode(keyCode);
  if c = '' then Exit(False);
  Result := IsKeyPressed(c);
end;
function IsKeyPressed(const code: String): Boolean; overload;
begin
  if gKeysPressed.hasOwnProperty(code) and Boolean(gKeysPressed[code]) then
  begin
    gKeysPressed[code] := false; Exit(True);
  end;

  // Paruj tylko modyfikatory:
  if (code = 'ShiftLeft') and gKeysPressed.hasOwnProperty('ShiftRight') and Boolean(gKeysPressed['ShiftRight']) then
  begin gKeysPressed['ShiftRight'] := false; Exit(True); end;

  if (code = 'ControlLeft') and gKeysPressed.hasOwnProperty('ControlRight') and Boolean(gKeysPressed['ControlRight']) then
  begin gKeysPressed['ControlRight'] := false; Exit(True); end;

  if (code = 'AltLeft') and gKeysPressed.hasOwnProperty('AltRight') and Boolean(gKeysPressed['AltRight']) then
  begin gKeysPressed['AltRight'] := false; Exit(True); end;

  if (code = 'MetaLeft') and gKeysPressed.hasOwnProperty('MetaRight') and Boolean(gKeysPressed['MetaRight']) then
  begin gKeysPressed['MetaRight'] := false; Exit(True); end;

  Result := False;
end;
function IsKeyDown(keyCode: Integer): Boolean; overload;
var c: String;
begin
  c := KeyCodeToCode(keyCode);
  if c = '' then Exit(False);
  Result := IsKeyDown(c);
end;
function IsKeyDown(const code: String): Boolean; overload;
begin
  if gKeys.hasOwnProperty(code) and Boolean(gKeys[code]) then Exit(True);

  // Paruj tylko modyfikatory:
  if (code = 'ShiftLeft')   and gKeys.hasOwnProperty('ShiftRight')   and Boolean(gKeys['ShiftRight'])   then Exit(True);
  if (code = 'ControlLeft') and gKeys.hasOwnProperty('ControlRight') and Boolean(gKeys['ControlRight']) then Exit(True);
  if (code = 'AltLeft')     and gKeys.hasOwnProperty('AltRight')     and Boolean(gKeys['AltRight'])     then Exit(True);
  if (code = 'MetaLeft')    and gKeys.hasOwnProperty('MetaRight')    and Boolean(gKeys['MetaRight'])    then Exit(True);

  Result := False;
end;

function IsKeyReleased(const code: String): Boolean; overload;
var wasReleased: Boolean;
begin
  if not gKeysReleased.hasOwnProperty(code) then
    Exit(False);

  wasReleased := Boolean(gKeysReleased[code]);
  if wasReleased then gKeysReleased[code] := false;
  Result := wasReleased;
end;

function IsKeyReleased(keyCode: Integer): Boolean; overload;
var c: String;
begin
  c := KeyCodeToCode(keyCode);
  if c = '' then Exit(False);
  Result := IsKeyReleased(c);
end;


function GetAllPressedKeys: array of String;
var
  props: array of String;
  key: String;
  i, count: Integer;
begin
  props := TJSObject.getOwnPropertyNames(gKeys);
  SetLength(Result, Length(props));
  
  count := 0;
  for i := 0 to High(props) do
  begin
    key := props[i];
    if Boolean(gKeys[key]) then
    begin
      Result[count] := key;
      Inc(count);
    end;
  end;
  
  SetLength(Result, count);
end;


function GetKeyPressed: String;
var
  key: String;
begin
  for key in TJSObject.getOwnPropertyNames(gKeysPressed) do
  begin
    if Boolean(gKeysPressed[key]) then
    begin
      gKeysPressed[key] := false;
      Exit(key);
    end;
  end;
  Result := '';
end;

function GetCharPressed: String;
begin
  Result := GetKeyPressed;
end;

{ ====== PROFILER ====== }
procedure BeginProfile(const name: String);
begin
  SetLength(gProfileStack, Length(gProfileStack) + 1);
  gProfileStack[High(gProfileStack)].name := name;
  gProfileStack[High(gProfileStack)].startTime := window.performance.now();
end;

procedure EndProfile(const name: String);
var
  duration: Double;
  current: TProfileEntry;
  data: TJSObject;
  total, count, minv, maxv: Double;
begin
  if Length(gProfileStack) = 0 then Exit;

  current := gProfileStack[High(gProfileStack)];
  SetLength(gProfileStack, Length(gProfileStack) - 1);

  if current.name <> name then
    console.warn('Profile mismatch: expected ' + name + ', got ' + current.name);

  duration := window.performance.now() - current.startTime;

  if not gProfileData.hasOwnProperty(name) then
    gProfileData[name] := TJSObject.new;

  data := TJSObject(gProfileData[name]);

  if data.hasOwnProperty('total') then total := Double(data['total']) else total := 0.0;
  if data.hasOwnProperty('count') then count := Double(data['count']) else count := 0.0;
  if data.hasOwnProperty('min')   then minv  := Double(data['min'])   else minv  := MaxDouble;
  if data.hasOwnProperty('max')   then maxv  := Double(data['max'])   else maxv  := 0.0;

  total := total + duration;
  count := count + 1.0;
  if duration < minv then minv := duration;
  if duration > maxv then maxv := duration;

  data['total'] := total;
  data['count'] := count;
  data['min']   := minv;
  data['max']   := maxv;
end;

function GetProfileData: String;
var
  key: String;
  data: TJSObject;
  avg: Double;
begin
  Result := 'Profile Data:'#10;
  for key in TJSObject.getOwnPropertyNames(gProfileData) do
  begin
    data := TJSObject(gProfileData[key]);
    if Integer(data['count']) > 0 then
      avg := Double(data['total']) / Integer(data['count'])
    else
      avg := 0.0;
    Result := Result + Format('%s: %.2fms avg (min: %.2fms, max: %.2fms, count: %d)'#10,
      [key, avg, Double(data['min']), Double(data['max']), Integer(data['count'])]);
  end;
end;

procedure ResetProfileData;
begin
  gProfileData := TJSObject.new;
end;

{ ====== PARTICLE SYSTEM ====== }
function CreateParticleSystem(maxParticles: Integer): TParticleSystem;
begin
  Result := TParticleSystem.Create(maxParticles);
  SetLength(gParticleSystems, Length(gParticleSystems) + 1);
  gParticleSystems[High(gParticleSystems)] := Result;
end;

procedure DrawParticles(particleSystem: TParticleSystem);
begin
  if Assigned(particleSystem) then
    particleSystem.Draw;
end;

procedure UpdateParticles(particleSystem: TParticleSystem; dt: Double);
begin
  if Assigned(particleSystem) then
    particleSystem.Update(dt);
end;

{ ====== LOOP / RAF ====== }
procedure GlobalAnimFrame(time: Double);
var
  desiredMs, elapsedMs: Double;
  stepMs, stepSec: Double;
  instFps: Double;
  steps, i: Integer;
const
  EPS_MS    = 2.0;
  FIXED_FPS = 60;
  MAX_STEPS = 5;
  FPS_ALPHA = 0.12;
begin
  // jeśli ktoś zatrzymał pętlę z zewnątrz – wyjdź
  if not gRunning then Exit;

  // żądanie zamknięcia (np. ESC w onKeyDownH)
  if gWantsClose then
  begin
    gRunning := False;
    CloseWindow;
    Exit;
  end;

  if gLastTime = 0 then
    gLastTime := time;

  elapsedMs := time - gLastTime;

  // Throttling do gTargetFPS (jeśli ustawiony)
  if (gTargetFPS > 0) then
  begin
    desiredMs := 1000.0 / gTargetFPS;
    if (elapsedMs + EPS_MS) < desiredMs then
    begin
      if gRunning then
        window.requestAnimationFrame(@GlobalAnimFrame);
      Exit;
    end;
  end;

  // --- FIXED STEP parametry (potrzebne zaraz do capów akumulatora)
  stepMs  := 1000.0 / FIXED_FPS;
  stepSec := stepMs / 1000.0;

  // aktualizacja punktu odniesienia czasu
  gLastTime := time;

  // górny limit skoku czasu (po alt-tab, hiccup itp.)
  if elapsedMs > 100.0 then
    elapsedMs := 100.0;

  // akumulacja czasu
  gTimeAccum := gTimeAccum + elapsedMs;

  // HARD CAP akumulatora – nie pozwól urosnąć bardziej niż MAX_STEPS
  if gTimeAccum > (MAX_STEPS * stepMs) then
    gTimeAccum := (MAX_STEPS * stepMs);

  // --- stały krok aktualizacji
  steps := 0;
  while (gTimeAccum >= stepMs) and (steps < MAX_STEPS) do
  begin
    gLastDt := stepSec;

    if Assigned(gCurrentUpdate) then
      gCurrentUpdate(gLastDt);

    // Update systemów cząsteczek (jak było)
    for i := 0 to High(gParticleSystems) do
      gParticleSystems[i].Update(gLastDt);

    gTimeAccum := gTimeAccum - stepMs;
    Inc(steps);

    // pozwól wyjść w trakcie „doganiania” czasu
    if gWantsClose then
    begin
      gRunning := False;
      CloseWindow;
      Exit;
    end;
  end;

  // jeżeli dojechaliśmy do MAX_STEPS, przytnij nadmiar, by nie „ciągnąć ogona”
  if steps = MAX_STEPS then
    if gTimeAccum > stepMs then
      gTimeAccum := stepMs;

  // rysowanie (przy stałym kroku możesz ewentualnie wyliczyć alfa = gTimeAccum/stepMs)
  // jeśli nie zmieniasz sygnatury Draw, zostaw tak jak było:
  if Assigned(gCurrentDraw) then
    gCurrentDraw(gLastDt);

  // FPS wygładzony
  if elapsedMs <= 0.0001 then
    instFps := 1000.0
  else
    instFps := 1000.0 / elapsedMs;

  if gCurrentFps <= 0 then
    gCurrentFps := Longint(Round(instFps))
  else
    gCurrentFps := Longint(Round(FPS_ALPHA * instFps + (1.0 - FPS_ALPHA) * Double(gCurrentFps)));

  Inc(gFrameCount);
  if (window.performance.now() - gLastFpsTime) >= 1000 then
  begin
    gFrameCount := 0;
    gLastFpsTime := window.performance.now();
  end;

  if gRunning then
    window.requestAnimationFrame(@GlobalAnimFrame);
end;


procedure Run(UpdateProc: TDeltaProc);
begin
  if not Assigned(UpdateProc) then Exit;
  gCurrentUpdate := UpdateProc;
  if not gRunning then gRunning := True;

  if Assigned(gCurrentUpdate) then
  begin
    gLastDt := 0.0;
    gCurrentUpdate(gLastDt);
  end;

  window.requestAnimationFrame(@GlobalAnimFrame);
end;

procedure Run(UpdateProc: TDeltaProc; DrawProc: TDeltaProc);
begin
  gCurrentDraw := DrawProc;
  Run(UpdateProc);
end;

{ ====== FPS / ZAMKNIĘCIE ====== }
procedure DrawFPS(x, y: Integer; color: TColor);
begin
  DrawText('FPS: ' + IntToStr(GetFPS), x, y, 16, color);
end;

function WindowShouldClose: Boolean;
begin
  Result := gWantsClose;
end;

procedure SetCloseOnEscape(enable: Boolean);
begin
  gCloseOnEscape := enable;
end;

function GetCloseOnEscape: Boolean;
begin
  Result := gCloseOnEscape;
end;

{ ====== KOLORY KLASYCZNE (HTML/CSS/X11) ====== }
function COLOR_ALICEBLUE: TColor; begin Result := ColorRGBA(240, 248, 255, 255); end;
function COLOR_ANTIQUEWHITE: TColor; begin Result := ColorRGBA(250, 235, 215, 255); end;
function COLOR_AQUA: TColor; begin Result := ColorRGBA(0, 255, 255, 255); end;        { alias CYAN }
function COLOR_AQUAMARINE: TColor; begin Result := ColorRGBA(127, 255, 212, 255); end;
function COLOR_AZURE: TColor; begin Result := ColorRGBA(240, 255, 255, 255); end;
function COLOR_BEIGE: TColor; begin Result := ColorRGBA(245, 245, 220, 255); end;
function COLOR_BISQUE: TColor; begin Result := ColorRGBA(255, 228, 196, 255); end;
function COLOR_BLACK: TColor; begin Result := ColorRGBA(0, 0, 0, 255); end;
function COLOR_BLANCHEDALMOND: TColor; begin Result := ColorRGBA(255, 235, 205, 255); end;
function COLOR_BLUE: TColor; begin Result := ColorRGBA(0, 0, 255, 255); end;
function COLOR_BLUEVIOLET: TColor; begin Result := ColorRGBA(138, 43, 226, 255); end;
function COLOR_BROWN: TColor; begin Result := ColorRGBA(165, 42, 42, 255); end;
function COLOR_BURLYWOOD: TColor; begin Result := ColorRGBA(222, 184, 135, 255); end;
function COLOR_CADETBLUE: TColor; begin Result := ColorRGBA(95, 158, 160, 255); end;
function COLOR_CHARTREUSE: TColor; begin Result := ColorRGBA(127, 255, 0, 255); end;
function COLOR_CHOCOLATE: TColor; begin Result := ColorRGBA(210, 105, 30, 255); end;
function COLOR_CORAL: TColor; begin Result := ColorRGBA(255, 127, 80, 255); end;
function COLOR_CORNFLOWERBLUE: TColor; begin Result := ColorRGBA(100, 149, 237, 255); end;
function COLOR_CORNSILK: TColor; begin Result := ColorRGBA(255, 248, 220, 255); end;
function COLOR_CRIMSON: TColor; begin Result := ColorRGBA(220, 20, 60, 255); end;
function COLOR_CYAN: TColor; begin Result := ColorRGBA(0, 255, 255, 255); end;          { alias AQUA }
function COLOR_DARKBLUE: TColor; begin Result := ColorRGBA(0, 0, 139, 255); end;
function COLOR_DARKCYAN: TColor; begin Result := ColorRGBA(0, 139, 139, 255); end;
function COLOR_DARKGOLDENROD: TColor; begin Result := ColorRGBA(184, 134, 11, 255); end;
function COLOR_DARKGRAY: TColor; begin Result := ColorRGBA(169, 169, 169, 255); end;
function COLOR_DARKGREY: TColor; begin Result := ColorRGBA(169, 169, 169, 255); end;   { alias }
function COLOR_DARKGREEN: TColor; begin Result := ColorRGBA(0, 100, 0, 255); end;
function COLOR_DARKKHAKI: TColor; begin Result := ColorRGBA(189, 183, 107, 255); end;
function COLOR_DARKMAGENTA: TColor; begin Result := ColorRGBA(139, 0, 139, 255); end;
function COLOR_DARKOLIVEGREEN: TColor; begin Result := ColorRGBA(85, 107, 47, 255); end;
function COLOR_DARKORANGE: TColor; begin Result := ColorRGBA(255, 140, 0, 255); end;
function COLOR_DARKORCHID: TColor; begin Result := ColorRGBA(153, 50, 204, 255); end;
function COLOR_DARKRED: TColor; begin Result := ColorRGBA(139, 0, 0, 255); end;
function COLOR_DARKSALMON: TColor; begin Result := ColorRGBA(233, 150, 122, 255); end;
function COLOR_DARKSEAGREEN: TColor; begin Result := ColorRGBA(143, 188, 143, 255); end;
function COLOR_DARKSLATEBLUE: TColor; begin Result := ColorRGBA(72, 61, 139, 255); end;
function COLOR_DARKSLATEGRAY: TColor; begin Result := ColorRGBA(47, 79, 79, 255); end;
function COLOR_DARKSLATEGREY: TColor; begin Result := ColorRGBA(47, 79, 79, 255); end;  { alias }
function COLOR_DARKTURQUOISE: TColor; begin Result := ColorRGBA(0, 206, 209, 255); end;
function COLOR_DARKVIOLET: TColor; begin Result := ColorRGBA(148, 0, 211, 255); end;
function COLOR_DEEPPINK: TColor; begin Result := ColorRGBA(255, 20, 147, 255); end;
function COLOR_DEEPSKYBLUE: TColor; begin Result := ColorRGBA(0, 191, 255, 255); end;
function COLOR_DIMGRAY: TColor; begin Result := ColorRGBA(105, 105, 105, 255); end;
function COLOR_DIMGREY: TColor; begin Result := ColorRGBA(105, 105, 105, 255); end;     { alias }
function COLOR_DODGERBLUE: TColor; begin Result := ColorRGBA(30, 144, 255, 255); end;
function COLOR_FIREBRICK: TColor; begin Result := ColorRGBA(178, 34, 34, 255); end;
function COLOR_FLORALWHITE: TColor; begin Result := ColorRGBA(255, 250, 240, 255); end;
function COLOR_FORESTGREEN: TColor; begin Result := ColorRGBA(34, 139, 34, 255); end;
function COLOR_FUCHSIA: TColor; begin Result := ColorRGBA(255, 0, 255, 255); end;       { alias MAGENTA }
function COLOR_GAINSBORO: TColor; begin Result := ColorRGBA(220, 220, 220, 255); end;
function COLOR_GHOSTWHITE: TColor; begin Result := ColorRGBA(248, 248, 255, 255); end;
function COLOR_GOLD: TColor; begin Result := ColorRGBA(255, 215, 0, 255); end;
function COLOR_GOLDENROD: TColor; begin Result := ColorRGBA(218, 165, 32, 255); end;
function COLOR_GRAY: TColor; begin Result := ColorRGBA(128, 128, 128, 255); end;
function COLOR_GREY: TColor; begin Result := ColorRGBA(128, 128, 128, 255); end;        { alias }
function COLOR_GREEN: TColor; begin Result := ColorRGBA(0, 128, 0, 255); end;
function COLOR_GREENYELLOW: TColor; begin Result := ColorRGBA(173, 255, 47, 255); end;
function COLOR_HONEYDEW: TColor; begin Result := ColorRGBA(240, 255, 240, 255); end;
function COLOR_HOTPINK: TColor; begin Result := ColorRGBA(255, 105, 180, 255); end;
function COLOR_INDIANRED: TColor; begin Result := ColorRGBA(205, 92, 92, 255); end;
function COLOR_INDIGO: TColor; begin Result := ColorRGBA(75, 0, 130, 255); end;
function COLOR_IVORY: TColor; begin Result := ColorRGBA(255, 255, 240, 255); end;
function COLOR_KHAKI: TColor; begin Result := ColorRGBA(240, 230, 140, 255); end;
function COLOR_LAVENDER: TColor; begin Result := ColorRGBA(230, 230, 250, 255); end;
function COLOR_LAVENDERBLUSH: TColor; begin Result := ColorRGBA(255, 240, 245, 255); end;
function COLOR_LAWNGREEN: TColor; begin Result := ColorRGBA(124, 252, 0, 255); end;
function COLOR_LEMONCHIFFON: TColor; begin Result := ColorRGBA(255, 250, 205, 255); end;
function COLOR_LIGHTBLUE: TColor; begin Result := ColorRGBA(173, 216, 230, 255); end;
function COLOR_LIGHTCORAL: TColor; begin Result := ColorRGBA(240, 128, 128, 255); end;
function COLOR_LIGHTCYAN: TColor; begin Result := ColorRGBA(224, 255, 255, 255); end;
function COLOR_LIGHTGOLDENRODYELLOW: TColor; begin Result := ColorRGBA(250, 250, 210, 255); end;
function COLOR_LIGHTGRAY: TColor; begin Result := ColorRGBA(211, 211, 211, 255); end;
function COLOR_LIGHTGREY: TColor; begin Result := ColorRGBA(211, 211, 211, 255); end;    { alias }
function COLOR_LIGHTGREEN: TColor; begin Result := ColorRGBA(144, 238, 144, 255); end;
function COLOR_LIGHTPINK: TColor; begin Result := ColorRGBA(255, 182, 193, 255); end;
function COLOR_LIGHTSALMON: TColor; begin Result := ColorRGBA(255, 160, 122, 255); end;
function COLOR_LIGHTSEAGREEN: TColor; begin Result := ColorRGBA(32, 178, 170, 255); end;
function COLOR_LIGHTSKYBLUE: TColor; begin Result := ColorRGBA(135, 206, 250, 255); end;
function COLOR_LIGHTSLATEGRAY: TColor; begin Result := ColorRGBA(119, 136, 153, 255); end;
function COLOR_LIGHTSLATEGREY: TColor; begin Result := ColorRGBA(119, 136, 153, 255); end; { alias }
function COLOR_LIGHTSTEELBLUE: TColor; begin Result := ColorRGBA(176, 196, 222, 255); end;
function COLOR_LIGHTYELLOW: TColor; begin Result := ColorRGBA(255, 255, 224, 255); end;
function COLOR_LIME: TColor; begin Result := ColorRGBA(0, 255, 0, 255); end;
function COLOR_LIMEGREEN: TColor; begin Result := ColorRGBA(50, 205, 50, 255); end;
function COLOR_LINEN: TColor; begin Result := ColorRGBA(250, 240, 230, 255); end;
function COLOR_MAGENTA: TColor; begin Result := ColorRGBA(255, 0, 255, 255); end;        { alias FUCHSIA }
function COLOR_MAROON: TColor; begin Result := ColorRGBA(128, 0, 0, 255); end;
function COLOR_MEDIUMAQUAMARINE: TColor; begin Result := ColorRGBA(102, 205, 170, 255); end;
function COLOR_MEDIUMBLUE: TColor; begin Result := ColorRGBA(0, 0, 205, 255); end;
function COLOR_MEDIUMORCHID: TColor; begin Result := ColorRGBA(186, 85, 211, 255); end;
function COLOR_MEDIUMPURPLE: TColor; begin Result := ColorRGBA(147, 112, 219, 255); end;
function COLOR_MEDIUMSEAGREEN: TColor; begin Result := ColorRGBA(60, 179, 113, 255); end;
function COLOR_MEDIUMSLATEBLUE: TColor; begin Result := ColorRGBA(123, 104, 238, 255); end;
function COLOR_MEDIUMSPRINGGREEN: TColor; begin Result := ColorRGBA(0, 250, 154, 255); end;
function COLOR_MEDIUMTURQUOISE: TColor; begin Result := ColorRGBA(72, 209, 204, 255); end;
function COLOR_MEDIUMVIOLETRED: TColor; begin Result := ColorRGBA(199, 21, 133, 255); end;
function COLOR_MIDNIGHTBLUE: TColor; begin Result := ColorRGBA(25, 25, 112, 255); end;
function COLOR_MINTCREAM: TColor; begin Result := ColorRGBA(245, 255, 250, 255); end;
function COLOR_MISTYROSE: TColor; begin Result := ColorRGBA(255, 228, 225, 255); end;
function COLOR_MOCCASIN: TColor; begin Result := ColorRGBA(255, 228, 181, 255); end;
function COLOR_NAVAJOWHITE: TColor; begin Result := ColorRGBA(255, 222, 173, 255); end;
function COLOR_NAVY: TColor; begin Result := ColorRGBA(0, 0, 128, 255); end;
function COLOR_OLDLACE: TColor; begin Result := ColorRGBA(253, 245, 230, 255); end;
function COLOR_OLIVE: TColor; begin Result := ColorRGBA(128, 128, 0, 255); end;
function COLOR_OLIVEDRAB: TColor; begin Result := ColorRGBA(107, 142, 35, 255); end;
function COLOR_ORANGE: TColor; begin Result := ColorRGBA(255, 165, 0, 255); end;
function COLOR_ORANGERED: TColor; begin Result := ColorRGBA(255, 69, 0, 255); end;
function COLOR_ORCHID: TColor; begin Result := ColorRGBA(218, 112, 214, 255); end;
function COLOR_PALEGOLDENROD: TColor; begin Result := ColorRGBA(238, 232, 170, 255); end;
function COLOR_PALEGREEN: TColor; begin Result := ColorRGBA(152, 251, 152, 255); end;
function COLOR_PALETURQUOISE: TColor; begin Result := ColorRGBA(175, 238, 238, 255); end;
function COLOR_PALEVIOLETRED: TColor; begin Result := ColorRGBA(219, 112, 147, 255); end;
function COLOR_PAPAYAWHIP: TColor; begin Result := ColorRGBA(255, 239, 213, 255); end;
function COLOR_PEACHPUFF: TColor; begin Result := ColorRGBA(255, 218, 185, 255); end;
function COLOR_PERU: TColor; begin Result := ColorRGBA(205, 133, 63, 255); end;
function COLOR_PINK: TColor; begin Result := ColorRGBA(255, 192, 203, 255); end;
function COLOR_PLUM: TColor; begin Result := ColorRGBA(221, 160, 221, 255); end;
function COLOR_POWDERBLUE: TColor; begin Result := ColorRGBA(176, 224, 230, 255); end;
function COLOR_PURPLE: TColor; begin Result := ColorRGBA(128, 0, 128, 255); end;
function COLOR_REBECCAPURPLE: TColor; begin Result := ColorRGBA(102, 51, 153, 255); end;
function COLOR_RED: TColor; begin Result := ColorRGBA(255, 0, 0, 255); end;
function COLOR_ROSYBROWN: TColor; begin Result := ColorRGBA(188, 143, 143, 255); end;
function COLOR_ROYALBLUE: TColor; begin Result := ColorRGBA(65, 105, 225, 255); end;
function COLOR_SADDLEBROWN: TColor; begin Result := ColorRGBA(139, 69, 19, 255); end;
function COLOR_SALMON: TColor; begin Result := ColorRGBA(250, 128, 114, 255); end;
function COLOR_SANDYBROWN: TColor; begin Result := ColorRGBA(244, 164, 96, 255); end;
function COLOR_SEAGREEN: TColor; begin Result := ColorRGBA(46, 139, 87, 255); end;
function COLOR_SEASHELL: TColor; begin Result := ColorRGBA(255, 245, 238, 255); end;
function COLOR_SIENNA: TColor; begin Result := ColorRGBA(160, 82, 45, 255); end;
function COLOR_SILVER: TColor; begin Result := ColorRGBA(192, 192, 192, 255); end;
function COLOR_SKYBLUE: TColor; begin Result := ColorRGBA(135, 206, 235, 255); end;
function COLOR_SLATEBLUE: TColor; begin Result := ColorRGBA(106, 90, 205, 255); end;
function COLOR_SLATEGRAY: TColor; begin Result := ColorRGBA(112, 128, 144, 255); end;
function COLOR_SLATEGREY: TColor; begin Result := ColorRGBA(112, 128, 144, 255); end;    { alias }
function COLOR_SNOW: TColor; begin Result := ColorRGBA(255, 250, 250, 255); end;
function COLOR_SPRINGGREEN: TColor; begin Result := ColorRGBA(0, 255, 127, 255); end;
function COLOR_STEELBLUE: TColor; begin Result := ColorRGBA(70, 130, 180, 255); end;
function COLOR_TAN: TColor; begin Result := ColorRGBA(210, 180, 140, 255); end;
function COLOR_TEAL: TColor; begin Result := ColorRGBA(0, 128, 128, 255); end;
function COLOR_THISTLE: TColor; begin Result := ColorRGBA(216, 191, 216, 255); end;
function COLOR_TOMATO: TColor; begin Result := ColorRGBA(255, 99, 71, 255); end;
function COLOR_TURQUOISE: TColor; begin Result := ColorRGBA(64, 224, 208, 255); end;
function COLOR_VIOLET: TColor; begin Result := ColorRGBA(238, 130, 238, 255); end;
function COLOR_WHEAT: TColor; begin Result := ColorRGBA(245, 222, 179, 255); end;
function COLOR_WHITE: TColor; begin Result := ColorRGBA(255, 255, 255, 255); end;
function COLOR_WHITESMOKE: TColor; begin Result := ColorRGBA(245, 245, 245, 255); end;
function COLOR_YELLOW: TColor; begin Result := ColorRGBA(255, 255, 0, 255); end;
function COLOR_YELLOWGREEN: TColor; begin Result := ColorRGBA(154, 205, 50, 255); end;
function COLOR_TRANSPARENT : TColor; begin Result := ColorRGBA(0, 0, 0, 0); end;

// ====== DODATKOWE POMOCNICZE PROCEDURY – KWADRATY I OBRYSY ======

procedure DrawSquare(x, y, size: double; const color: TColor);
begin
  DrawRectangle(x, y, size, size, color);
end;

procedure DrawSquareLines(x, y, size: double; const color: TColor; thickness: Integer = 1);
begin
  DrawRectangleLines(x, y, size, size, color, thickness);
end;

procedure DrawSquareFromCenter(cx, cy, size: double; const color: TColor);
var
  x, y: double;
begin
  x := cx - (size / 2);
  y := cy - (size / 2);
  DrawRectangle(x, y, size, size, color);
end;

procedure DrawSquareFromCenterLines(cx, cy, size: double; const color: TColor; thickness: Integer = 1);
var
  x, y: double;
begin
  x := cx - (size / 2);
  y := cy - (size / 2);
  DrawRectangleLines(x, y, size, size, color, thickness);
end;

// Obrys zaokrąglonego prostokąta z kontrolą grubości
procedure DrawRectangleRoundedStroke(x, y, w, h, radius: double; const color: TColor; thickness: Integer = 1);
begin
  gCtx.lineWidth := thickness;
  DrawRectangleRounded(x, y, w, h, radius, color, False);
end;

procedure DrawRectangleRoundedRecStroke(const rec: TRectangle; radius: Double; const color: TColor; thickness: Integer = 1);
begin
  gCtx.lineWidth := thickness;
  DrawRectangleRounded(Round(rec.x), Round(rec.y), Round(rec.width), Round(rec.height), Round(radius), color, False);
end;

// Batch obrysów prostokątów (analogiczny do batch fill)
procedure BeginRectStrokeBatch(const color: TColor; thickness: Integer = 1);
begin
  gCtx.beginPath;
  gCtx.strokeStyle := ColorToCanvasRGBA(color);
  gCtx.lineWidth := thickness;
end;

procedure BatchRectStroke(x, y, w, h: Integer);
begin
  gCtx.rect(x, y, w, h);
end;

procedure EndRectStrokeBatch;
begin
  gCtx.stroke;
end;
procedure Push; inline;
begin
  gCtx.save;
end;

procedure Pop; inline;
begin
  gCtx.restore;
end;

end.
