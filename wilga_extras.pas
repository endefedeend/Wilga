unit wilga_extras;
 {$mode objfpc}{$H+} {$modeswitch advancedrecords}  {$inline on}

{*
  Wilga Extras — add-ons for wilga.pas (pas2js, canvas 2D)

  Zawiera:
    - Sprite + Animation + SpriteBatch
    - SpriteSheet + Animator
    - Tiled: tile layers + object layers + custom properties + chunk cache
    - Arcade physics (AABB sweep) + one-way + triggery
    - Scene manager (stack)
    - InputMap (mapowanie akcji)
    - Camera helpers (follow, clamp, shake)
    - Tween system (getter/setter, bez zagnieżdżania typów)
    - Resource manager (AssetsLoad/GetTextureByName)
    - Audio: grupy (Master/Music/SFX), mute, group volume, MusicCrossFade
    - Debug overlay (toggle, draw calls, tweens, FPS)
*}

interface

uses JS, Web, SysUtils, Math, wilga;
 var
  gCrossFading :boolean= False;

{ ==== Perlin Noise (2D/3D + FBM) =========================================== }
type
  { Prosty PRNG (xorshift32) dla powtarzalnych wyników }
  TXorShift32 = record
    s: LongWord;
    procedure Seed(aSeed: LongWord);
    function NextU32: LongWord;
    function NextFloat: Double; // [0,1)
  end;

  TPerlin = record
  private
    perm: array[0..511] of Byte; // tablica permutacji (x2)
    class function Fade(t: Double): Double; static; inline;
    class function Lerp(a, b, t: Double): Double; static; inline;
    class function Grad2(hash: Integer; x, y: Double): Double; static; inline;
    class function Grad3(hash: Integer; x, y, z: Double): Double; static; inline;
  public
    class function Create(seed: LongInt): TPerlin; static;
    function Noise2D(x, y: Double): Double;
    function Noise3D(x, y, z: Double): Double;
    function FBM2D(x, y: Double; octaves: Integer = 4; lacunarity: Double = 2.0; persistence: Double = 0.5): Double;
  end;
procedure AssetsFree;

{ Mapowanie [-1,1] -> [0,1] }
function Normalize01(v: Double): Double; inline;

{ Wygodne wrapery dla Wilgi }
function PerlinNoise2D(seed: LongInt; x, y, scale: Double): Double; overload; // 1 oktawa
function PerlinFBM2D(seed: LongInt; x, y, scale: Double; octaves: Integer = 4; lacunarity: Double = 2.0; persistence: Double = 0.5): Double; overload;
{ ==== Sprites =============================================================== }
type
  PSprite = ^TSprite;
  TSprite = record
    position, scale: TInputVector;
    rotationDeg: Double;
    origin: TInputVector;  // 0..1 (rel.) (0.5,0.5)=center
    tint: TColor;
    flipX, flipY: Boolean;
    z: Integer;
    texture: TTexture;
    src: TRectangle; // source rect in texture
  end;

procedure SpriteInit(out s: TSprite; const tex: TTexture);
procedure SpriteDraw(const s: TSprite);
procedure SpriteSetFrame(var s: TSprite; const src: TRectangle);

procedure BeginSpriteBatch;
procedure BatchSprite(const s: TSprite);
procedure EndSpriteBatch;

// === Pauza (API publiczne) ===
procedure PauseOn;
procedure PauseOff;
procedure PauseToggle;
function IsPaused: Boolean;
{ ==== Animation ============================================================= }
type
  TAnimFrame = record
    src: TRectangle;
    dur: Double; // seconds
  end;

  TLoopMode = (amLoop, amOnce, amPingPong);

  TAnimation = class
  private
    fTime: Double;
    fIdx: Integer;
    fDir: Integer;
  public
    frames: array of TAnimFrame;
    speed: Double;
    mode: TLoopMode;
    finished: Boolean;
    constructor Create;
    procedure Reset;
    procedure Update(dt: Double);
    function  Current: TRectangle;
  end;

{ ==== SpriteSheet + Animator =============================================== }
type
  TSpriteFrame = record
    name: String;
    rect: TRectangle;
    dur: Double;
  end;

  TSpriteSheet = class
  public
    texture: TTexture;
    frames: array of TSpriteFrame;
    function  FindFrame(const name: String): Integer;
    procedure AddFrame(const name: String; const rect: TRectangle; dur: Double);
  end;

  TAnimator = class
  private
    fTime: Double;
    fIdx: Integer;
  public
    sheet: TSpriteSheet;
    current: array of Integer; // indeksy w sheet.frames
    speed: Double;
    loop: Boolean;
    constructor Create(aSheet: TSpriteSheet);
    procedure SetClip(const names: array of String; aLoop: Boolean = True);
    procedure Update(dt: Double);
    procedure ApplyTo(var spr: TSprite);
  end;

{ ==== Tiled Map + Cache ===================================================== }
type
  TTiledTileset = record
    firstgid: Integer;
    image: TTexture;
    columns, tilecount, tilewidth, tileheight: Integer;
    imagewidth, imageheight: Integer;
  end;

  TTiledLayerKind = (lkTiles, lkObjects);

  TTiledLayer = record
    name: String;
    kind: TTiledLayerKind;
    visible: Boolean;
    opacity: Double;
    data: TJSObject; // JS obiekt oryginalnej warstwy
    parallaxX, parallaxY: Double;
  end;

  TTiledObject = record
    name, objType: String;
    x, y, w, h: Double;
    props: TJSObject; // mapowanie "name" -> value (JS)
  end;

  TTiledObjectLayer = record
    name: String;
    objects: array of TTiledObject;
  end;

  // --- Tile chunk cache (Canvas2D offscreen na bloki CHUNK×CHUNK kafli) ---
  TTileChunk = record
    canvas: TJSHTMLCanvasElement;
    dirty: Boolean;
    cx, cy: Integer;        // indeks chunku w siatce (x,y)
  end;

  TTileLayerCache = record
    enabled: Boolean;
    chunkSize: Integer;     // liczba kafli na krawędź chunku (np. 32)
    chunksW, chunksH: Integer;
    chunks: array of array of TTileChunk; // [cy][cx]
  end;

  TTiledMap = class
  private
    solid: array of array of Boolean;
    objLayers: array of TTiledObjectLayer;

    // cache dla każdej warstwy tiles
    layerCache: array of TTileLayerCache;
    procedure EnsureLayerCacheAllocated(layerIdx, chunkSize: Integer);
    procedure RenderChunk(layerIdx, cx, cy: Integer);
  public
    tileW, tileH: Integer;
    width, height: Integer; // in tiles
    layers: array of TTiledLayer;
    tilesets: array of TTiledTileset;

    procedure Draw(const cam: TCamera2D);
    function  TileToWorld(tx, ty: Integer): TInputVector;
    function  WorldToTile(px, py: Double): TInputVector;

    // Nowe:
    function  GetObjectLayer(const name: String; out ol: TTiledObjectLayer): Boolean;
    procedure BuildSolidGrid(const solidLayerName: String); // z tile layer
    function  IsSolid(tx, ty: Integer): Boolean;

    // cache API:
    procedure EnableChunkCache(aChunkSize: Integer = 32);
    procedure InvalidateAllChunks;                        // oznacz wszystkie „dirty”
    procedure InvalidateTile(layerIdx, tx, ty: Integer);  // „dirty” chunk dla podanej płytki
  end;

  // Callbacki nazwane (unikamy zagnieżdżonych anonimów w sygnaturach)
  TAtlasResolver = reference to function(const imageSource: String): TTexture;
  TTiledReady    = reference to procedure(const m: TTiledMap);

procedure LoadTiledJSON(const url: String; const atlasResolver: TAtlasResolver;
                        const onReady: TTiledReady);
// Proste IO (tekst / JSON / bin)
type
  TOnText  = reference to procedure(const text: String);
  TOnJSON  = reference to procedure(const obj: TJSObject);
  TOnBytes = reference to procedure(const bytes: TJSUint8Array);

procedure LoadText(const url: String; const onReady: TOnText);
procedure LoadJSON(const url: String; const onReady: TOnJSON);
procedure LoadBIN (const url: String; const onReady: TOnBytes);

type
  // callback bez argumentów, pozwala przekazywać procedury anonimowe
  TNoArgCallback = reference to procedure;

procedure InjectCss(const css: String);
function  ExtToMime(const Url: string): string;
function  ExtToFormat(const Url: string): string;
procedure PreloadFont(const Url: string);
function  FontIsLoaded(const CssFont: string): Boolean;
procedure StartFontLoad(const Sample: string);
procedure LoadWebFont(const Family, Url: string; OnReady: TNoArgCallback = nil);
procedure UseWebFont(const Family: string; SizePx: Integer);
{ ==== Arcade Physics + one-way + triggery ================================== }
type
  TRigidBody = record
    aabb: TRectangle;
    vel: TInputVector;
    onGround: Boolean;
  end;

  TOneWay = record
    rect: TRectangle;
  end;

  TTrigger = record
    rect: TRectangle;
    name: String;
  end;

function MoveAndCollide(var body: TRigidBody; const solids: array of TRectangle; dt: Double): TInputVector;
function MoveAndCollideOneWay(var body: TRigidBody; const solids: array of TRectangle;
                              const oneWay: array of TOneWay; dt: Double): TInputVector;
function TriggerCheck(const body: TRigidBody; const triggers: array of TTrigger; out name: String): Boolean;
function Raycast(const startPos, dir: TInputVector; maxDist: Double; const solids: array of TRectangle; out hitPos: TInputVector): Boolean;

{ ==== Scene Manager (stack) ================================================= }
type
  IScene = interface
    ['{0A4B0C30-9E8B-4B8A-AD8B-0F3B2D6A9F11}']
    procedure Enter;
    procedure Exit;
    procedure Update(dt: Double);
    procedure Draw;
  end;

procedure ScenePush(const s: IScene);
procedure ScenePop;
procedure SceneReplace(const s: IScene);
procedure SceneUpdate(const dt: Double);
procedure SceneDraw(const dt: Double);


{ ==== Input Map ============================================================= }
type
  TAction = (ActUp, ActDown, ActLeft, ActRight, ActJump, ActShoot, ActDash, ActPause);

procedure BindKey(action: TAction; const code: String);
function  ActionDown(action: TAction): Boolean;
function  ActionPressed(action: TAction): Boolean;

{ ==== Camera Helpers ======================================================== }
procedure CameraFollow(var cam: TCamera2D; target: TInputVector; stiffness: Double; dt: Double);
procedure CameraClampToWorld(var cam: TCamera2D; worldRect: TRectangle; viewportW, viewportH: Integer);
procedure CameraShakeInit(amplitude, frequency: Double; time: Double);
function  CameraShakeOffset(dt: Double): TInputVector; // tymczasowe przesunięcie na klatkę

{ ==== Tween (getter/setter) ================================================ }
type
  TEase = (easeLinear, easeInQuad, easeOutQuad, easeInOutCubic);
  TDoubleGetter = reference to function: Double;
  TDoubleSetter = reference to procedure(v: Double);
  TNoArgProcRef = reference to procedure;

procedure TweenValue(getter: TDoubleGetter; setter: TDoubleSetter;
                     toValue, time: Double; ease: TEase; OnDone: TNoArgProcRef = nil);
procedure TweenUpdate(dt: Double);
function  TweensActive: Integer;

{ ==== Resource manager (po nazwach) ======================================== }
procedure AssetsLoad(const names, urls: array of String; const onAll: TNoArgProc);
function  GetTextureByName(const name: String): TTexture;

{ ==== Audio: grupy, mute, cross-fade ======================================= }
type
  TAudioGroup = (agMaster, agMusic, agSFX);

procedure AudioRegister(handle: TSoundHandle; group: TAudioGroup; baseVolume: Double = 1.0; looped: Boolean = False);
procedure AudioPlay(handle: TSoundHandle);
procedure AudioSetBaseVolume(handle: TSoundHandle; baseVolume: Double);
procedure AudioSetGroupVolume(g: TAudioGroup; v: Double);
procedure AudioMuteAll(mute: Boolean);
procedure MusicCrossFade(oldH, newH: TSoundHandle; time: Double);

{ ==== Debug overlay / stats ================================================= }
procedure DebugToggle;
procedure DebugCountDrawCall;
procedure DebugOverlayDraw(x, y: Integer);

{==== rysowanietekstupro ========================================================}
// Tekst pionowy (vertical text)
procedure DrawTextVertical(const text: String; pos: TVector2; fontSize: Integer; const color: TColor);

// Efekt "typewriter" (pojawianie się liter z czasem)
procedure DrawTextTypewriter(const text: String; pos: TVector2; fontSize: Integer; const color: TColor; elapsedTime: Double; charsPerSecond: Double);

// Efekt "fala" (wave) – litery unoszą się sinusoidalnie
procedure DrawTextWave(const text: String; pos: TVector2; fontSize: Integer; const color: TColor; time: Double; amplitude, speed: Double);

// Efekt "pulsowanie" (scale pulse)
procedure DrawTextPulse(const text: String; pos: TVector2; fontSize: Integer; const color: TColor; time: Double; pulseSpeed, pulseAmount: Double);


// Tekst z wypełnieniem teksturą
procedure DrawTextTextureFill(const text: String; pos: TVector2; fontSize: Integer; const tex: TTexture);

// Efekt "shaking text" (drżenie)
procedure DrawTextShake(const text: String; pos: TVector2; fontSize: Integer; const color: TColor; time: Double; intensity: Double);

//ineksztlaty
// === Extras: Gwiazda i Serce ===
procedure DrawStar(cx, cy: Double; points: Integer; rOuter, rInner: Double;
  rotationDeg: Double; const color: TColor; filled: Boolean = True; thickness: Integer = 1);
procedure DrawStarV(center: TVector2; points: Integer; rOuter, rInner: Double;
  rotationDeg: Double; const color: TColor; filled: Boolean = True; thickness: Integer = 1);

procedure DrawHeart(cx, cy: Double; width, height: Double; rotationDeg: Double;
  const color: TColor; filled: Boolean = True; thickness: Integer = 1; samples: Integer = 120);
procedure DrawHeartV(center: TVector2; width, height: Double; rotationDeg: Double;
  const color: TColor; filled: Boolean = True; thickness: Integer = 1; samples: Integer = 120);



implementation

{ ==== Helpers (lokalne) ===================================================== }
function FloorI(x: Double): Integer; inline; begin Result := Trunc(Floor(x)); end;
function CeilI(x: Double): Integer;  inline; begin Result := Trunc(Ceil(x));  end;

{ ==== Sprite & Batch ======================================================== }
type
  TSpriteBatchItem = record
    s: TSprite;
  end;

var
  gBatch: array of TSpriteBatchItem;
  gBatchActive: Boolean = False;
  gPaused: Boolean = False;
  // debug
  gDebugOn: Boolean = True;
  gDrawCalls: Integer = 0;

procedure PauseOn; begin gPaused := True; end;
procedure PauseOff; begin gPaused := False; end;
procedure PauseToggle; begin gPaused := not gPaused; end;
function IsPaused: Boolean; begin Exit(gPaused); end;


procedure DebugCountDrawCall;
begin
  Inc(gDrawCalls);
end;

procedure SpriteInit(out s: TSprite; const tex: TTexture);
begin
  s.texture := tex;
  s.position := NewVector(0,0);
  s.scale := NewVector(1,1);
  s.rotationDeg := 0;
  s.origin := NewVector(0,0);
  s.tint := COLOR_WHITE;
  s.flipX := False; s.flipY := False;
  s.z := 0;
  s.src := RectangleCreate(0,0,tex.width, tex.height);
end;

procedure SpriteSetFrame(var s: TSprite; const src: TRectangle);
begin
  s.src := src;
end;

procedure SpriteDraw(const s: TSprite);
var
  dst: TRectangle;
  ox, oy, rw, rh: Double;
  origin: TInputVector;
  srcCopy: TRectangle;
begin
  rw := Abs(s.src.width) * s.scale.x;
  rh := Abs(s.src.height) * s.scale.y;

  dst := RectangleFromCenter(s.position.x, s.position.y, rw, rh);

  origin := s.origin;
  ox := origin.x * rw;
  oy := origin.y * rh;

  srcCopy := s.src;
  if s.flipX then srcCopy.width := -srcCopy.width;
  if s.flipY then srcCopy.height := -srcCopy.height;

  DrawTexturePro(s.texture, srcCopy, dst, NewVector(ox, oy), s.rotationDeg, s.tint);
  DebugCountDrawCall;
end;

procedure BeginSpriteBatch;
begin
  SetLength(gBatch, 0);
  gBatchActive := True;
end;

procedure BatchSprite(const s: TSprite);
begin
  if not gBatchActive then Exit;
  SetLength(gBatch, Length(gBatch)+1);
  gBatch[High(gBatch)].s := s;
end;

procedure EndSpriteBatch;
var
  i, j: Integer;
  tmp: TSpriteBatchItem;
begin
  if not gBatchActive then Exit;

  // sort by z (prosty insertion sort)
  for i := 1 to High(gBatch) do
  begin
    tmp := gBatch[i];
    j := i - 1;
    while (j >= 0) and (gBatch[j].s.z > tmp.s.z) do
    begin
      gBatch[j+1] := gBatch[j];
      Dec(j);
    end;
    gBatch[j+1] := tmp;
  end;

  for i := 0 to High(gBatch) do
    SpriteDraw(gBatch[i].s);

  SetLength(gBatch, 0);
  gBatchActive := False;
end;

{ ==== Animation ============================================================= }
constructor TAnimation.Create;
begin
  inherited Create;
  speed := 1.0;
  mode := amLoop;
  fTime := 0;
  fIdx := 0;
  fDir := 1;
  finished := False;
end;

procedure TAnimation.Reset;
begin
  fTime := 0;
  fIdx := 0;
  fDir := 1;
  finished := False;
end;

function EnsureRangeInt(v, lo, hi: Integer): Integer;
begin
  if v < lo then Exit(lo);
  if v > hi then Exit(hi);
  Result := v;
end;

procedure TAnimation.Update(dt: Double);
var
  curDur: Double;
begin
  if Length(frames)=0 then Exit;
  if finished then Exit;
  fTime := fTime + dt * speed;
  curDur := frames[fIdx].dur;
  while (curDur>0) and (fTime >= curDur) do
  begin
    fTime := fTime - curDur;
    case mode of
      amLoop:    fIdx := (fIdx + 1) mod Length(frames);
      amOnce:    begin Inc(fIdx); if fIdx >= Length(frames) then begin fIdx := High(frames); finished := True; Break; end; end;
      amPingPong:begin
                  fIdx := fIdx + fDir;
                  if (fIdx >= Length(frames)) or (fIdx < 0) then
                  begin
                    fDir := -fDir;
                    fIdx := fIdx + 2*fDir;
                    fIdx := EnsureRangeInt(fIdx, 0, High(frames));
                  end;
                end;
    end;
    if finished then Break;
    curDur := frames[fIdx].dur;
  end;
end;

function TAnimation.Current: TRectangle;
begin
  if Length(frames)=0 then Exit(RectangleCreate(0,0,0,0));
  Result := frames[fIdx].src;
end;

{ ==== SpriteSheet + Animator =============================================== }
function TSpriteSheet.FindFrame(const name: String): Integer;
var i: Integer;
begin
  for i := 0 to High(frames) do
    if frames[i].name = name then Exit(i);
  Result := -1;
end;

procedure TSpriteSheet.AddFrame(const name: String; const rect: TRectangle; dur: Double);
var n: Integer;
begin
  n := Length(frames);
  SetLength(frames, n+1);
  frames[n].name := name;
  frames[n].rect := rect;
  frames[n].dur  := Max(0.01, dur);
end;

constructor TAnimator.Create(aSheet: TSpriteSheet);
begin
  inherited Create;
  sheet := aSheet;
  speed := 1.0;
  loop := True;
  fTime := 0;
  fIdx := 0;
  SetLength(current, 0);
end;

procedure TAnimator.SetClip(const names: array of String; aLoop: Boolean);
var i, idx: Integer;
begin
  loop := aLoop;
  SetLength(current, Length(names));
  for i := 0 to High(names) do
  begin
    idx := sheet.FindFrame(names[i]);
    if idx < 0 then idx := 0;
    current[i] := idx;
  end;
  fTime := 0; fIdx := 0;
end;

procedure TAnimator.Update(dt: Double);
var dur: Double;
begin
  if Length(current)=0 then Exit;
  fTime := fTime + dt * speed;
  dur := sheet.frames[current[fIdx]].dur;
  while (dur>0) and (fTime >= dur) do
  begin
    fTime := fTime - dur;
    Inc(fIdx);
    if fIdx >= Length(current) then
      if loop then fIdx := 0 else fIdx := High(current);
    dur := sheet.frames[current[fIdx]].dur;
  end;
end;

procedure TAnimator.ApplyTo(var spr: TSprite);
begin
  if (sheet=nil) or (Length(current)=0) then Exit;
  if (spr.texture.canvas = nil) then spr.texture := sheet.texture;
  SpriteSetFrame(spr, sheet.frames[current[fIdx]].rect);
end;

{ ==== Tiled + Cache ========================================================= }
procedure TTiledMap.EnsureLayerCacheAllocated(layerIdx, chunkSize: Integer);
var
  chW, chH, y, x: Integer;
begin
  if (layerIdx < 0) or (layerIdx > High(layers)) then Exit;

  if Length(layerCache) <> Length(layers) then
    SetLength(layerCache, Length(layers));

  // tylko dla tilelayer
  if layers[layerIdx].kind <> lkTiles then Exit;

  if chunkSize <= 0 then chunkSize := 32;
  if not layerCache[layerIdx].enabled then
    Exit;

  chW := CeilI(width  / chunkSize);
  chH := CeilI(height / chunkSize);

  // jeśli już jest poprawnie zaalokowane, kończ
  if (layerCache[layerIdx].chunksW = chW) and (layerCache[layerIdx].chunksH = chH) and
     (layerCache[layerIdx].chunkSize = chunkSize) and
     (Length(layerCache[layerIdx].chunks) = chH) then Exit;

  // alokacja
  layerCache[layerIdx].chunkSize := chunkSize;
  layerCache[layerIdx].chunksW := chW;
  layerCache[layerIdx].chunksH := chH;
  SetLength(layerCache[layerIdx].chunks, chH);
  for y := 0 to chH-1 do
  begin
    SetLength(layerCache[layerIdx].chunks[y], chW);
    for x := 0 to chW-1 do
    begin
      layerCache[layerIdx].chunks[y][x].cx := x;
      layerCache[layerIdx].chunks[y][x].cy := y;
      layerCache[layerIdx].chunks[y][x].dirty := True;
      layerCache[layerIdx].chunks[y][x].canvas := TJSHTMLCanvasElement(document.createElement('canvas'));
      layerCache[layerIdx].chunks[y][x].canvas.width  := tileW * chunkSize;
      layerCache[layerIdx].chunks[y][x].canvas.height := tileH * chunkSize;
    end;
  end;
end;

procedure TTiledMap.RenderChunk(layerIdx, cx, cy: Integer);
var
  cache: ^TTileLayerCache;
  ch: ^TTileChunk;
  ctx: TJSCanvasRenderingContext2D;
  cs, tx0, ty0, tx1, ty1, tx, ty, idx, gid, j, setIdx, sx, sy, col, localId: Integer;
  tiles: TJSArray;
  tileset: ^TTiledTileset;
begin
  if (layerIdx < 0) or (layerIdx > High(layers)) then Exit;
  if layers[layerIdx].kind <> lkTiles then Exit;
  if (cx < 0) or (cy < 0) then Exit;
  if (Length(layerCache) = 0) or (not layerCache[layerIdx].enabled) then Exit;

  cache := @layerCache[layerIdx];
  if (cy >= cache^.chunksH) or (cx >= cache^.chunksW) then Exit;

  ch := @cache^.chunks[cy][cx];
  if not ch^.dirty then Exit;

  ctx := TJSCanvasRenderingContext2D(ch^.canvas.getContext('2d'));
  // wyczyść
  ctx.clearRect(0, 0, ch^.canvas.width, ch^.canvas.height);

  cs := cache^.chunkSize;

  // zakres kafli w tym chunku
  tx0 := cx * cs;
  ty0 := cy * cs;
  tx1 := MinI(width-1,  tx0 + cs - 1);
  ty1 := MinI(height-1, ty0 + cs - 1);

  tiles := TJSArray(layers[layerIdx].data['data']);
  if tiles = nil then
  begin
    ch^.dirty := False; Exit;
  end;

  // rysujemy kafle do offscreen
  for ty := ty0 to ty1 do
    for tx := tx0 to tx1 do
    begin
      idx := ty*width + tx;
      if (idx < 0) or (idx >= tiles.length) then Continue;
      gid := Integer(tiles[idx]);
      if gid = 0 then Continue;

      // wybór tilesetu
      setIdx := -1;
      for j := High(tilesets) downto 0 do
        if gid >= tilesets[j].firstgid then begin setIdx := j; Break; end;
      if setIdx < 0 then Continue;

      tileset := @tilesets[setIdx];
      col := tileset^.columns;
      if col <= 0 then Continue;

      localId := gid - tileset^.firstgid;
      sx := (localId mod col) * tileset^.tilewidth;
      sy := (localId div col) * tileset^.tileheight;

      if TextureIsReady(tileset^.image) then
        ctx.drawImage(tileset^.image.canvas,
          sx, sy, tileset^.tilewidth, tileset^.tileheight,
          (tx - tx0) * tileW, (ty - ty0) * tileH, tileW, tileH);
    end;

  ch^.dirty := False;
end;

procedure TTiledMap.EnableChunkCache(aChunkSize: Integer);
var i: Integer;
begin
  if aChunkSize <= 0 then aChunkSize := 32;
  if Length(layerCache) <> Length(layers) then
    SetLength(layerCache, Length(layers));
  for i := 0 to High(layers) do
  begin
    if layers[i].kind = lkTiles then
    begin
      layerCache[i].enabled := True;
      EnsureLayerCacheAllocated(i, aChunkSize);
    end;
  end;
end;

procedure TTiledMap.InvalidateAllChunks;
var i, y, x: Integer;
begin
  for i := 0 to High(layerCache) do
    if layerCache[i].enabled then
      for y := 0 to layerCache[i].chunksH-1 do
        for x := 0 to layerCache[i].chunksW-1 do
          layerCache[i].chunks[y][x].dirty := True;
end;

procedure TTiledMap.InvalidateTile(layerIdx, tx, ty: Integer);
var
  cs, cx, cy: Integer;
begin
  if (layerIdx < 0) or (layerIdx > High(layerCache)) then Exit;
  if not layerCache[layerIdx].enabled then Exit;
  cs := layerCache[layerIdx].chunkSize;
  if cs <= 0 then Exit;
  cx := tx div cs;
  cy := ty div cs;
  if (cy >= 0) and (cy < layerCache[layerIdx].chunksH) and
     (cx >= 0) and (cx < layerCache[layerIdx].chunksW) then
    layerCache[layerIdx].chunks[cy][cx].dirty := True;
end;

procedure TTiledMap.Draw(const cam: TCamera2D);
var
  viewW, viewH: Integer;
  view: TRectangle;
  ly, i, j, gid, setIdx: Integer;
  layer: TTiledLayer;
  tiles: TJSArray;
  tx, ty: Integer;
  dst: TRectangle;
  tileset: ^TTiledTileset;
  sx, sy, col, localId: Integer;
  src: TRectangle;
  parx, pary: Double;
  tx0, ty0, tx1, ty1: Integer;
  tint: TColor;

  // cache draw
  cache: ^TTileLayerCache;
  cs, cx0, cy0, cx1, cy1, cx, cy: Integer;
  ch: ^TTileChunk;
begin
  viewW := GetScreenWidth;
  viewH := GetScreenHeight;
  view := RectangleCreate(cam.target.x - cam.offset.x/cam.zoom,
                          cam.target.y - cam.offset.y/cam.zoom,
                          viewW / cam.zoom, viewH / cam.zoom);

  for ly := 0 to High(layers) do
  begin
    layer := layers[ly];
    if not layer.visible then Continue;
    if layer.kind <> lkTiles then Continue;

    tiles := TJSArray(layer.data['data']);
    if tiles = nil then Continue;

    parx := layer.parallaxX; if parx = 0 then parx := 1.0;
    pary := layer.parallaxY; if pary = 0 then pary := 1.0;

    // jeśli cache aktywne dla warstwy:
    if (Length(layerCache)>ly) and layerCache[ly].enabled then
    begin
      cache := @layerCache[ly];
      cs := cache^.chunkSize;

      // zakres chunków widocznych
      cx0 := MaxI(0, FloorI(view.x / (tileW*cs)) - 1);
      cy0 := MaxI(0, FloorI(view.y / (tileH*cs)) - 1);
      cx1 := MinI(cache^.chunksW-1, CeilI((view.x+view.width)/(tileW*cs)) + 1);
      cy1 := MinI(cache^.chunksH-1, CeilI((view.y+view.height)/(tileH*cs)) + 1);

      // upewnij się, że chunk canvasy są gotowe
      for cy := cy0 to cy1 do
        for cx := cx0 to cx1 do
        begin
          ch := @cache^.chunks[cy][cx];
          if ch^.dirty then RenderChunk(ly, cx, cy);

          // miejsce docelowe chunku w świecie (z parallax)
          dst := RectangleCreate(
            (cx*cs*tileW) * parx,
            (cy*cs*tileH) * pary,
            cs*tileW, cs*tileH);

          // narysuj offscreen (używamy DrawTexturePro przez CreateTextureFromCanvas)
          if ch^.canvas <> nil then
          begin
            DrawTexturePro(CreateTextureFromCanvas(ch^.canvas),
              RectangleCreate(0,0,ch^.canvas.width, ch^.canvas.height),
              dst, Vector2Zero, 0, COLOR_WHITE.WithAlpha(Round(Clamp(layer.opacity,0,1)*255)));
            DebugCountDrawCall;
          end;
        end;

      Continue; // poszła warstwa z cache
    end;

    // fallback: rysowanie kafel po kaflu
    tx0 := MaxI(0, FloorI(view.x / tileW) - 1);
    ty0 := MaxI(0, FloorI(view.y / tileH) - 1);
    tx1 := MinI(width-1,  CeilI((view.x+view.width)/tileW) + 1);
    ty1 := MinI(height-1, CeilI((view.y+view.height)/tileH) + 1);

    for ty := ty0 to ty1 do
      for tx := tx0 to tx1 do
      begin
        i := ty*width + tx;
        if (i < 0) or (i >= tiles.length) then Continue;
        gid := Integer(tiles[i]);
        if gid = 0 then Continue;

        // tileset
        setIdx := -1;
        for j := High(tilesets) downto 0 do
          if gid >= tilesets[j].firstgid then begin setIdx := j; Break; end;
        if setIdx < 0 then Continue;

        tileset := @tilesets[setIdx];
        col := tileset^.columns;
        if col <= 0 then Continue;

        localId := gid - tileset^.firstgid;
        sx := (localId mod col) * tileset^.tilewidth;
        sy := (localId div col) * tileset^.tileheight;
        src := RectangleCreate(sx, sy, tileset^.tilewidth, tileset^.tileheight);

        dst := RectangleCreate(tx*tileW, ty*tileH, tileW, tileH);
        dst.x := dst.x * parx;
        dst.y := dst.y * pary;

        if TextureIsReady(tileset^.image) then
        begin
          tint := COLOR_WHITE.WithAlpha(Round(Clamp(layer.opacity,0,1)*255));
          DrawTexturePro(tileset^.image, src, dst, Vector2Zero, 0, tint);
          DebugCountDrawCall;
        end;
      end;
  end;
end;

function TTiledMap.TileToWorld(tx, ty: Integer): TInputVector;
begin
  Result := NewVector(tx * tileW, ty * tileH);
end;

function TTiledMap.WorldToTile(px, py: Double): TInputVector;
begin
  Result := NewVector(Floor(px / tileW), Floor(py / tileH));
end;

function TTiledMap.GetObjectLayer(const name: String; out ol: TTiledObjectLayer): Boolean;
var i: Integer;
begin
  for i := 0 to High(objLayers) do
    if objLayers[i].name = name then begin ol := objLayers[i]; Exit(True); end;
  Result := False;
end;

procedure TTiledMap.BuildSolidGrid(const solidLayerName: String);
var
  i, x, y, gid, idx: Integer;
  lyr: TTiledLayer;
  arr: TJSArray;
begin
  SetLength(solid, height);
  for y := 0 to height-1 do SetLength(solid[y], width);
  for i := 0 to High(layers) do
    if (layers[i].kind=lkTiles) and (layers[i].name=solidLayerName) then
    begin
      lyr := layers[i];
      arr := TJSArray(lyr.data['data']);
      if arr = nil then Exit;
      for y := 0 to height-1 do
        for x := 0 to width-1 do
        begin
          idx := y*width + x;
          gid := Integer(arr[idx]);
          solid[y][x] := (gid<>0);
        end;
      Exit;
    end;
end;

function TTiledMap.IsSolid(tx, ty: Integer): Boolean;
begin
  if (ty<0) or (ty>=Length(solid)) then Exit(True);
  if (tx<0) or (tx>=Length(solid[ty])) then Exit(True);
  Result := solid[ty][tx];
end;

procedure LoadTiledJSON(const url: String; const atlasResolver: TAtlasResolver;
                        const onReady: TTiledReady);
var
  xhr: TJSXMLHttpRequest;
begin
  xhr := TJSXMLHttpRequest.new;
  xhr.open('GET', url, True);
  xhr.onreadystatechange := procedure
  var
    obj: TJSObject;
    map: TTiledMap;
    lyArr: TJSArray;
    i: Integer;
    lyr: TJSObject;
    kindStr: String;
    tsArr: TJSArray;
    ts: TJSObject;
    imgSrc: String;

    // helper do properties[] -> JS object {name:value}
    function PropertiesToObject(propsArr: TJSArray): TJSObject;
    var k: Integer; po: TJSObject; nm: String; v: JSValue;
    begin
      Result := TJSObject.new;
      if propsArr = nil then Exit;
      for k := 0 to propsArr.length-1 do
      begin
        po := TJSObject(propsArr[k]);
        nm := String(po['name']);
        v := po['value'];
        Result[nm] := v;
      end;
    end;

    // budowa object layer
    procedure ParseObjectLayer(const layerObj: TJSObject);
    var
      objectsArr: TJSArray; o: TJSObject; k: Integer; ol: TTiledObjectLayer;
      propsArr: TJSArray;
    begin
      ol.name := String(layerObj['name']);
      objectsArr := TJSArray(layerObj['objects']);
      SetLength(ol.objects, objectsArr.length);
      for k := 0 to objectsArr.length-1 do
      begin
        o := TJSObject(objectsArr[k]);
        ol.objects[k].name    := String(o['name']);
        if o.hasOwnProperty('type') then
          ol.objects[k].objType := String(o['type'])
        else
          ol.objects[k].objType := '';
        ol.objects[k].x := Double(o['x']);
        ol.objects[k].y := Double(o['y']);
        if o.hasOwnProperty('width') then ol.objects[k].w := Double(o['width']) else ol.objects[k].w := 0;
        if o.hasOwnProperty('height') then ol.objects[k].h := Double(o['height']) else ol.objects[k].h := 0;
        propsArr := TJSArray(o['properties']);
        ol.objects[k].props := PropertiesToObject(propsArr);
      end;

      // dopisz do map.objLayers
      SetLength(map.objLayers, Length(map.objLayers)+1);
      map.objLayers[High(map.objLayers)] := ol;
    end;

  begin
    if xhr.readyState = 4 then
    begin
      if xhr.status = 200 then
      begin
        obj := TJSObject(TJSJSON.parse(xhr.responseText));
        map := TTiledMap.Create;
        map.tileW := Integer(obj['tilewidth']);
        map.tileH := Integer(obj['tileheight']);
        map.width := Integer(obj['width']);
        map.height:= Integer(obj['height']);

        // tilesets
        tsArr := TJSArray(obj['tilesets']);
        if tsArr <> nil then
        begin
          SetLength(map.tilesets, tsArr.length);
          for i := 0 to tsArr.length-1 do
          begin
            ts := TJSObject(tsArr[i]);
            map.tilesets[i].firstgid    := Integer(ts['firstgid']);
            map.tilesets[i].columns     := Integer(ts['columns']);
            map.tilesets[i].tilecount   := Integer(ts['tilecount']);
            map.tilesets[i].tilewidth   := Integer(ts['tilewidth']);
            map.tilesets[i].tileheight  := Integer(ts['tileheight']);
            map.tilesets[i].imagewidth  := Integer(ts['imagewidth']);
            map.tilesets[i].imageheight := Integer(ts['imageheight']);
            if ts.hasOwnProperty('image') then
            begin
              imgSrc := String(ts['image']);
              if Assigned(atlasResolver) then
                map.tilesets[i].image := atlasResolver(imgSrc);
            end;
          end;
        end;

        // layers
        lyArr := TJSArray(obj['layers']);
        if lyArr <> nil then
        begin
          SetLength(map.layers, lyArr.length);
          for i := 0 to lyArr.length-1 do
          begin
            lyr := TJSObject(lyArr[i]);
            map.layers[i].name    := String(lyr['name']);
            kindStr               := String(lyr['type']);
            if kindStr = 'tilelayer' then map.layers[i].kind := lkTiles
                                      else map.layers[i].kind := lkObjects;
            map.layers[i].visible := Boolean(lyr['visible']);
            if lyr.hasOwnProperty('opacity')
              then map.layers[i].opacity := Double(lyr['opacity'])
              else map.layers[i].opacity := 1.0;
            map.layers[i].data := lyr;
            if lyr.hasOwnProperty('parallaxx')
              then map.layers[i].parallaxX := Double(lyr['parallaxx'])
              else map.layers[i].parallaxX := 1.0;
            if lyr.hasOwnProperty('parallaxy')
              then map.layers[i].parallaxY := Double(lyr['parallaxy'])
              else map.layers[i].parallaxY := 1.0;

            // object layer parse
            if map.layers[i].kind = lkObjects then
              ParseObjectLayer(lyr);
          end;
        end;

        if Assigned(onReady) then onReady(map);
      end
      else
        console.warn('LoadTiledJSON failed: ' + url);
    end;
  end;
  xhr.send;
end;
procedure LoadText(const url: String; const onReady: TOnText);
var
  xhr: TJSXMLHttpRequest;
begin
  xhr := TJSXMLHttpRequest.new;
  xhr.open('GET', url, True);
  xhr.overrideMimeType('text/plain; charset=utf-8');
  xhr.onreadystatechange := procedure
  begin
    if (xhr.readyState = 4) then
    begin
      if (xhr.status = 200) then
      begin
        if Assigned(onReady) then onReady(String(xhr.responseText));
      end
      else
        console.warn('LoadText failed: ' + url + ' status=' + IntToStr(xhr.status));
    end;
  end;
  xhr.send;
end;

procedure LoadJSON(const url: String; const onReady: TOnJSON);
var
  xhr: TJSXMLHttpRequest;
begin
  xhr := TJSXMLHttpRequest.new;
  xhr.open('GET', url, True);
  xhr.overrideMimeType('application/json; charset=utf-8');
  xhr.onreadystatechange := procedure
  var
    obj: TJSObject;
  begin
    if (xhr.readyState = 4) then
    begin
      if (xhr.status = 200) then
      begin
        try
          // pas2js: JSON.parse zwraca JS Value; rzutujemy na TJSObject
          obj := TJSObject(TJSJSON.parse(xhr.responseText));
          if Assigned(onReady) then onReady(obj);
        except
          on E: Exception do
            console.warn('LoadJSON parse error: ' + E.Message + ' url=' + url);
        end;
      end
      else
        console.warn('LoadJSON failed: ' + url + ' status=' + IntToStr(xhr.status));
    end;
  end;
  xhr.send;
end;

procedure LoadBIN(const url: String; const onReady: TOnBytes);
var
  xhr: TJSXMLHttpRequest;
begin
  xhr := TJSXMLHttpRequest.new;
  xhr.open('GET', url, True);
  xhr.responseType := 'arraybuffer';
  xhr.onreadystatechange := procedure
  var
    buf: TJSArrayBuffer;
    u8 : TJSUint8Array;
  begin
    if (xhr.readyState = 4) then
    begin
      if (xhr.status = 200) then
      begin
        buf := TJSArrayBuffer(xhr.response);
        u8  := TJSUint8Array.new(buf);
        if Assigned(onReady) then onReady(u8);
      end
      else
        console.warn('LoadBIN failed: ' + url + ' status=' + IntToStr(xhr.status));
    end;
  end;
  xhr.send;
end;

procedure InjectCss(const css: String);
var
  styleEl: TJSHTMLStyleElement;
begin
  styleEl := TJSHTMLStyleElement(document.createElement('style'));
  styleEl.innerHTML := css;
  document.head.appendChild(styleEl);
end;

function ExtToMime(const Url: string): string;
var
  e: string;
begin
  e := LowerCase(ExtractFileExt(Url));
  if e = '.woff2' then Exit('font/woff2');
  if e = '.woff'  then Exit('font/woff');
  if e = '.ttf'   then Exit('font/ttf');
  if e = '.otf'   then Exit('font/otf');
  Result := '';
end;
function ExtToFormat(const Url: string): string;
var
  e: string;
begin
  e := LowerCase(ExtractFileExt(Url));
  if e = '.woff2' then Exit('woff2');
  if e = '.woff'  then Exit('woff');
  if e = '.ttf'   then Exit('truetype');
  if e = '.otf'   then Exit('opentype');
  Result := '';
end;


procedure PreloadFont(const Url: string);
var
  linkEl: TJSElement;
  mime: string;
begin
  linkEl := TJSElement(document.createElement('link'));
  linkEl.setAttribute('rel', 'preload');
  linkEl.setAttribute('as', 'font');
  linkEl.setAttribute('href', Url);
  linkEl.setAttribute('crossorigin', 'anonymous');

  mime := ExtToMime(Url);
  if mime <> '' then
    linkEl.setAttribute('type', mime);

  document.head.appendChild(linkEl);
end;

function FontIsLoaded(const CssFont: string): Boolean;
begin
  asm
    return !!(document.fonts && document.fonts.check(CssFont));
  end;
end;

procedure StartFontLoad(const Sample: string);
begin
  asm
    if (document.fonts && document.fonts.load) {
      document.fonts.load(Sample);
    } else {
      var s = document.createElement('span');
      s.textContent = 'AaŻżŁł';
      s.style.font = Sample;
      s.style.position = 'absolute';
      s.style.left = '-9999px';
      document.body.appendChild(s);
    }
  end;
end;

procedure LoadWebFont(const Family, Url: string; OnReady: TNoArgCallback = nil);
var
  css, sample, fmt: string;
  tries: Integer;

  procedure Poll;
  begin
    if FontIsLoaded(sample) or (tries >= 200) then
    begin
      if Assigned(OnReady) then OnReady();
      Exit;
    end;
    Inc(tries);
    window.setTimeout(@Poll, 50);
  end;

begin
  PreloadFont(Url);

  fmt := ExtToFormat(Url);
  if fmt = '' then fmt := 'truetype';

  css := '@font-face{' +
         'font-family:"' + Family + '";' +
         'src:url(' + Url + ') format("' + fmt + '");' +
         'font-display:swap;font-style:normal;font-weight:400;' +
         '}';
  InjectCss(css);

  sample := '12px "' + Family + '"';
  StartFontLoad(sample);

  tries := 0;
  if Assigned(OnReady) then Poll;
end;

procedure UseWebFont(const Family: string; SizePx: Integer);
begin
  SetTextFont(IntToStr(SizePx) + 'px "' + Family + '", system-ui, sans-serif');
end;

{ ==== Physics =============================================================== }
function Overlap(a, b: TRectangle): Boolean;
begin
  Result := not ((a.x + a.width  <= b.x) or (b.x + b.width  <= a.x) or
                 (a.y + a.height <= b.y) or (b.y + b.height <= a.y));
end;

function MoveAndCollide(var body: TRigidBody; const solids: array of TRectangle; dt: Double): TInputVector;
var
  goal, start: TRectangle;
  dx, dy: Double;
  i: Integer;
  step: TRectangle;
begin
  start := body.aabb;
  dx := body.vel.x * dt;
  dy := body.vel.y * dt;

  // Horizontal
  goal := start.Move(dx, 0);
  for i := 0 to High(solids) do
  begin
    if Overlap(goal, solids[i]) then
    begin
      if dx > 0 then goal.x := solids[i].x - start.width
                else goal.x := solids[i].x + solids[i].width;
      dx := goal.x - start.x;
    end;
  end;

  // Vertical
  step := goal.Move(0, dy);
  body.onGround := False;
  for i := 0 to High(solids) do
  begin
    if Overlap(step, solids[i]) then
    begin
      if dy > 0 then begin step.y := solids[i].y - start.height; body.onGround := True; end
                else step.y := solids[i].y + solids[i].height;
      dy := step.y - goal.y;
    end;
  end;

  body.aabb := step;
  Result := NewVector(dx, dy);
end;

function MoveAndCollideOneWay(var body: TRigidBody; const solids: array of TRectangle;
                              const oneWay: array of TOneWay; dt: Double): TInputVector;
var
  disp: TInputVector;
  i: Integer;
  start, step: TRectangle;
  dy: Double;
begin
  // najpierw standardowe kolizje z pełnymi solidami
  disp := MoveAndCollide(body, solids, dt);

  // one-way tylko przy ruchu w dół (dy>0) i wejściu od góry
  start := body.aabb.Move(-disp.x, -disp.y);
  dy := body.vel.y * dt;
  if dy > 0 then
  begin
    step := body.aabb; // po ruchu z solidami
    for i := 0 to High(oneWay) do
    begin
      // przecinamy od góry? start dół <= top platformy
      if (start.y + start.height) <= (oneWay[i].rect.y + 1) then
      begin
        // czy step wchodzi w platformę?
        if Overlap(step, oneWay[i].rect) then
        begin
          step.y := oneWay[i].rect.y - start.height;
          disp.y := step.y - (start.y + disp.y);
          body.aabb := step;
          body.onGround := True;
        end;
      end;
    end;
  end;

  Result := disp;
end;

function TriggerCheck(const body: TRigidBody; const triggers: array of TTrigger; out name: String): Boolean;
var i: Integer;
begin
  for i := 0 to High(triggers) do
    if Overlap(body.aabb, triggers[i].rect) then
    begin
      name := triggers[i].name;
      Exit(True);
    end;
  name := '';
  Result := False;
end;

function Raycast(const startPos, dir: TInputVector; maxDist: Double; const solids: array of TRectangle; out hitPos: TInputVector): Boolean;
const EPS = 1e-6;
var
  tmin, tx1, tx2, ty1, ty2, t0, t1: Double;
  i: Integer;
  b: TRectangle;
  invx, invy: Double;
begin
  if (Abs(dir.x) < EPS) and (Abs(dir.y) < EPS) then
  begin
    hitPos := startPos;
    Exit(False);
  end;

  if Abs(dir.x) < EPS then invx := 1.0/EPS else invx := 1.0 / dir.x;
  if Abs(dir.y) < EPS then invy := 1.0/EPS else invy := 1.0 / dir.y;

  Result := False;
  tmin := 1.0E30; hitPos := startPos;
  for i := 0 to High(solids) do
  begin
    b := solids[i];
    tx1 := (b.x - startPos.x) * invx;
    tx2 := (b.x + b.width - startPos.x) * invx;
    ty1 := (b.y - startPos.y) * invy;
    ty2 := (b.y + b.height - startPos.y) * invy;
    if tx1 < tx2 then t0 := tx1 else t0 := tx2;
    if tx1 < tx2 then t1 := tx2 else t1 := tx1;
    if ty1 < ty2 then t0 := Max(t0, ty1) else t0 := Max(t0, ty2);
    if ty1 < ty2 then t1 := Min(t1, ty2) else t1 := Min(t1, ty1);
    if (t1 >= 0) and (t0 <= t1) and (t0 <= maxDist) then
    begin
      if t0 < tmin then
      begin
        tmin := t0;
        hitPos := NewVector(startPos.x + dir.x * t0, startPos.y + dir.y * t0);
        Result := True;
      end;
    end;
  end;
end;

{ ==== Scene Manager ========================================================= }
var
  gSceneStack: array of IScene;

procedure ScenePush(const s: IScene);
begin
  if s = nil then Exit;
  SetLength(gSceneStack, Length(gSceneStack)+1);
  gSceneStack[High(gSceneStack)] := s;
  s.Enter;
end;

procedure ScenePop;
begin
  if Length(gSceneStack)=0 then Exit;
  gSceneStack[High(gSceneStack)].Exit;
  SetLength(gSceneStack, Length(gSceneStack)-1);
end;

procedure SceneReplace(const s: IScene);
begin
  ScenePop;
  ScenePush(s);
end;

procedure SceneUpdate(const dt: Double);
begin
  if gPaused then Exit;  // <<<< TUTAJ blokada przy pauzie
  if Length(gSceneStack) = 0 then Exit;
  gSceneStack[High(gSceneStack)].Update(dt);
end;

procedure SceneDraw(const dt: Double);
begin
  if Length(gSceneStack) = 0 then Exit;
  gSceneStack[High(gSceneStack)].Draw;
end;
{ ==== Input Map ============================================================= }
type
  TBinding = record
    code: String;
  end;
var
  gBindings: array[TAction] of TBinding;

procedure BindKey(action: TAction; const code: String);
begin
  gBindings[action].code := code;
end;

function ActionDown(action: TAction): Boolean;
var c: String;
begin
  c := gBindings[action].code;
  if c = '' then Exit(False);
  Result := IsKeyDown(c);
end;

function ActionPressed(action: TAction): Boolean;
var c: String;
begin
  c := gBindings[action].code;
  if c = '' then Exit(False);
  Result := IsKeyPressed(c);
end;

{ ==== Camera Helpers ======================================================== }
var
  shakeAmp, shakeFreq, shakeTime, shakeTimer: Double;
  shakePhase: Double;

procedure CameraFollow(var cam: TCamera2D; target: TInputVector; stiffness: Double; dt: Double);
var
  desired: TInputVector;
  k: Double;
begin
  desired := target;
  k := Clamp(stiffness*dt, 0, 1);
  cam.target := cam.target.Lerp(desired, k);
end;

procedure CameraClampToWorld(var cam: TCamera2D; worldRect: TRectangle; viewportW, viewportH: Integer);
var
  halfW, halfH: Double;
begin
  halfW := (viewportW / cam.zoom) * 0.5;
  halfH := (viewportH / cam.zoom) * 0.5;
  cam.target.x := Clamp(cam.target.x, worldRect.x + halfW, worldRect.x + worldRect.width - halfW);
  cam.target.y := Clamp(cam.target.y, worldRect.y + halfH, worldRect.y + worldRect.height - halfH);
end;

procedure CameraShakeInit(amplitude, frequency: Double; time: Double);
begin
  shakeAmp := amplitude;
  shakeFreq := frequency;
  shakeTime := Max(0, time);
  shakeTimer := shakeTime;
  shakePhase := 0;
end;

function CameraShakeOffset(dt: Double): TInputVector;
var
  decay: Double;
begin
  Result := NewVector(0,0);
  if shakeTimer <= 0 then Exit;
  shakeTimer := shakeTimer - dt;
  shakePhase := shakePhase + shakeFreq * dt * 2 * Pi;
  if shakeTime <= 0.0001 then decay := 0 else decay := shakeTimer / shakeTime;
  if decay < 0 then decay := 0;
  Result.x := Sin(shakePhase) * shakeAmp * decay;
  Result.y := Cos(shakePhase*0.9) * shakeAmp * decay;
end;

{ ==== Tween ================================================================= }
type
  TTween = record
    getter: TDoubleGetter;
    setter: TDoubleSetter;
    fromVal, toVal, timeLeft, totalTime: Double;
    ease: TEase;
    onDone: TNoArgProcRef;
    alive: Boolean;
  end;

var
  gTweens: array of TTween;

function EaseApply(e: TEase; t: Double): Double;
begin
  case e of
    easeLinear:      Exit(t);
    easeInQuad:      Exit(t*t);
    easeOutQuad:     Exit(t*(2-t));
    easeInOutCubic:  begin if t<0.5 then Exit(4*t*t*t) else Exit(1 - Power(-2*t+2,3)/2); end;
  end;
  Result := t;
end;

procedure TweenValue(getter: TDoubleGetter; setter: TDoubleSetter;
                     toValue, time: Double; ease: TEase; OnDone: TNoArgProcRef);
var
  tw: TTween;
begin
  tw.getter := getter;
  tw.setter := setter;
  tw.fromVal := getter();
  tw.toVal := toValue;
  if time <= 0 then time := 0.0001;
  tw.timeLeft := time;
  tw.totalTime := time;
  tw.ease := ease;
  tw.onDone := OnDone;
  tw.alive := True;
  SetLength(gTweens, Length(gTweens)+1);
  gTweens[High(gTweens)] := tw;
end;

procedure TweenUpdate(dt: Double);
var
  i: Integer;
  t, k, val: Double;
begin
  i := 0;
  while i < Length(gTweens) do
  begin
    if not gTweens[i].alive then
    begin
      gTweens[i] := gTweens[High(gTweens)];
      SetLength(gTweens, Length(gTweens)-1);
      Continue;
    end;

    gTweens[i].timeLeft := gTweens[i].timeLeft - dt;
    if gTweens[i].totalTime <= 0.0001 then t := 1.0
    else t := 1.0 - Max(0.0, gTweens[i].timeLeft) / gTweens[i].totalTime;
    if t < 0 then t := 0;
    if t > 1 then t := 1;
    k := EaseApply(gTweens[i].ease, t);
    val := gTweens[i].fromVal + (gTweens[i].toVal - gTweens[i].fromVal) * k;
    if Assigned(gTweens[i].setter) then gTweens[i].setter(val);

    if gTweens[i].timeLeft <= 0 then
    begin
      gTweens[i].alive := False;
      if Assigned(gTweens[i].onDone) then gTweens[i].onDone();
    end;

    Inc(i);
  end;
end;

function TweensActive: Integer;
begin
  Result := Length(gTweens);
end;

{ ==== Resource manager (po nazwach) ======================================== }
type
  TNamedTex = record
    name: String;
    url: String;
    tex: TTexture;
    ready: Boolean;
  end;

var
  gNamedTex: array of TNamedTex;
 gAssetsGen: Integer = 0;           
procedure AssetsLoad(const names, urls: array of String; const onAll: TNoArgProc);
var
  i, total: Integer;
  loadedCount: Integer;
  thisGen: Integer;

  procedure StartLoad(const idx: Integer; const aName, aUrl: String);
  begin
    gNamedTex[idx].name  := aName;
    gNamedTex[idx].url   := aUrl;
    gNamedTex[idx].ready := False;

    LoadImageFromURL(aUrl, procedure(const t: TTexture)
    begin
      // Jeżeli w międzyczasie zrobiono AssetsFree albo nowe AssetsLoad — zignoruj wynik
      if thisGen <> gAssetsGen then Exit;

      if idx < Length(gNamedTex) then
      begin
        gNamedTex[idx].tex   := t;
        gNamedTex[idx].ready := True;

        Inc(loadedCount);
        if (loadedCount = total) and Assigned(onAll) then
          onAll();
      end;
    end);
  end;

begin
  total := Length(names);
  if total <> Length(urls) then
  begin
    console.warn('AssetsLoad: names and urls length mismatch');
    Exit;
  end;

  // Nowa „generacja” zasobów — unieważnia trwające loady poprzedniej puli
  Inc(gAssetsGen);
  thisGen := gAssetsGen;

  SetLength(gNamedTex, total);
  loadedCount := 0;

  for i := 0 to total-1 do
    StartLoad(i, names[i], urls[i]);
end;
procedure AssetsFree;
var
  i: Integer;
begin
  // Unieważnij wszystkie w locie ładujące się callbacki
  Inc(gAssetsGen);

  for i := 0 to High(gNamedTex) do
    ReleaseTexture(gNamedTex[i].tex);

  SetLength(gNamedTex, 0);
end;

procedure DrawTextTextureFill(const text: String; pos: TVector2; fontSize: Integer; const tex: TTexture);
var
  textW, textH: Double;
  offCanvas: TJSHTMLCanvasElement;
  offCtx: TJSCanvasRenderingContext2D;
begin
  if not TextureIsReady(tex) then Exit;

  // zmierz rozmiar tekstu
  textW := MeasureTextWidth(text, fontSize);
  textH := MeasureTextHeight(text, fontSize);

  // utwórz offscreen
  offCanvas := TJSHTMLCanvasElement(document.createElement('canvas'));
  offCanvas.width := Round(textW);
  offCanvas.height := Round(textH);
  offCtx := TJSCanvasRenderingContext2D(offCanvas.getContext('2d'));

  // narysuj tekst jako maskę
  offCtx.font := IntToStr(fontSize) + 'px Arial, Helvetica, sans-serif';
  offCtx.textBaseline := 'top';
  offCtx.fillStyle := 'white';
  offCtx.fillText(text, 0, 0);

  // ustaw tryb mieszania i nałóż teksturę
  offCtx.globalCompositeOperation := 'source-in';
  offCtx.drawImage(tex.canvas, 0, 0, tex.width, tex.height, 0, 0, offCanvas.width, offCanvas.height);

  // narysuj gotowy obraz na głównym canvasie
  gCtx.drawImage(offCanvas, pos.x, pos.y);
end;

function GetTextureByName(const name: String): TTexture;
var i: Integer; dummy: TTexture;
begin
  for i := 0 to High(gNamedTex) do
    if gNamedTex[i].name = name then Exit(gNamedTex[i].tex);
  // fallback pusty
  dummy.canvas := nil; dummy.loaded := False; dummy.width := 0; dummy.height := 0;
  Result := dummy;
end;

{ ==== Audio: grupy, mute, cross-fade ======================================= }
type
  TSoundReg = record
    handle: TSoundHandle;
    group: TAudioGroup;
    baseVol: Double; // 0..1 preferencja użytkownika dla tego dźwięku
    curVol: Double;  // aktualnie ustawiona głośność na handle
    valid: Boolean;
  end;

var
  gSoundRegs: array of TSoundReg;
  gMasterVol: Double = 1.0;
  gMusicVol:  Double = 1.0;
  gSfxVol:    Double = 1.0;
  gMuted:     Boolean = False;

function FindSoundReg(h: TSoundHandle): Integer;
var i: Integer;
begin
  for i := 0 to High(gSoundRegs) do
    if gSoundRegs[i].valid and (gSoundRegs[i].handle = h) then Exit(i);
  Result := -1;
end;

function GroupVolume(g: TAudioGroup): Double;
begin
  case g of
    agMaster: Exit(gMasterVol);
    agMusic:  Exit(gMusicVol);
    agSFX:    Exit(gSfxVol);
  end;
  Result := 1.0;
end;

function EffectiveVolume(const r: TSoundReg): Double;
var master: Double; gv: Double;
begin
  master := gMasterVol;
  gv := GroupVolume(r.group);
  if gMuted then Exit(0.0);
  Result := Clamp(r.baseVol * master * gv, 0.0, 1.0);
end;

procedure AudioRegister(handle: TSoundHandle; group: TAudioGroup; baseVolume: Double; looped: Boolean);
var idx: Integer;
begin
  idx := FindSoundReg(handle);
  if idx < 0 then
  begin
    SetLength(gSoundRegs, Length(gSoundRegs)+1);
    idx := High(gSoundRegs);
    gSoundRegs[idx].valid := True;
    gSoundRegs[idx].handle := handle;
  end;
  gSoundRegs[idx].group := group;
  gSoundRegs[idx].baseVol := Clamp(baseVolume, 0.0, 1.0);
  gSoundRegs[idx].curVol := EffectiveVolume(gSoundRegs[idx]);
  SetSoundLoop(handle, looped);
  SetSoundVolume(handle, gSoundRegs[idx].curVol);
end;

procedure AudioPlay(handle: TSoundHandle);
var idx: Integer; vol: Double;
begin
  idx := FindSoundReg(handle);
  if idx < 0 then
  begin
    // niezarejestrowany – graj z 1.0 * master
    if gMuted then PlaySoundEx(handle, 0.0) else PlaySoundEx(handle, gMasterVol);
    Exit;
  end;
  vol := EffectiveVolume(gSoundRegs[idx]);
  gSoundRegs[idx].curVol := vol;
  PlaySoundEx(handle, vol);
end;

procedure AudioSetBaseVolume(handle: TSoundHandle; baseVolume: Double);
var idx: Integer;
begin
  idx := FindSoundReg(handle);
  if idx < 0 then Exit;
  gSoundRegs[idx].baseVol := Clamp(baseVolume, 0.0, 1.0);
  gSoundRegs[idx].curVol := EffectiveVolume(gSoundRegs[idx]);
  SetSoundVolume(handle, gSoundRegs[idx].curVol);
end;

procedure ReapplyAllVolumes;
var i: Integer;
begin
  for i := 0 to High(gSoundRegs) do
    if gSoundRegs[i].valid then
    begin
      gSoundRegs[i].curVol := EffectiveVolume(gSoundRegs[i]);
      SetSoundVolume(gSoundRegs[i].handle, gSoundRegs[i].curVol);
    end;
end;

procedure AudioSetGroupVolume(g: TAudioGroup; v: Double);
begin
  v := Clamp(v, 0.0, 1.0);
  case g of
    agMaster: gMasterVol := v;
    agMusic:  gMusicVol := v;
    agSFX:    gSfxVol := v;
  end;
  ReapplyAllVolumes;
end;

procedure AudioMuteAll(mute: Boolean);
begin
  gMuted := mute;
  ReapplyAllVolumes;
end;

procedure MusicCrossFade(oldH, newH: TSoundHandle; time: Double);
var
  idxOld, idxNew: Integer;
  getterOld: TDoubleGetter; setterOld: TDoubleSetter;
  getterNew: TDoubleGetter; setterNew: TDoubleSetter;
  targetNew: Double;
begin
  if time < 0 then time := 0;
  if gCrossFading then Exit;            // anty-reentrancy (proste, globalne)

  // jeśli czas ~0: ustaw docelowe wartości i zatrzymaj old
  if time = 0 then
  begin
    SetSoundVolume(oldH, 0.0);
    StopSoundEx(oldH);
    SetSoundVolume(newH, 1.0);
    AudioPlay(newH);
    Exit;
  end;

  gCrossFading := True;

  // znajdź rejestry (mogą nie istnieć)
  idxOld := FindSoundReg(oldH);
  idxNew := FindSoundReg(newH);

  // (opcjonalnie) ubij istniejące tweeny związane z tymi uchwytami
  // Jeśli masz takie API:
  //   TweenKillByHandle(oldH);
  //   TweenKillByHandle(newH);

  // przygotuj nowy: od 0, play, loop wg rejestru
  if idxNew >= 0 then
    gSoundRegs[idxNew].curVol := 0.0;
  SetSoundVolume(newH, 0.0);
  AudioPlay(newH);

  // policz target wg aktualnych grup (Master/Music)
  if idxNew >= 0 then
    targetNew := EffectiveVolume(gSoundRegs[idxNew])   // bazowa curVol*grupy
  else
    targetNew := 1.0;                                   // fallback

  // OLD getters/setters
  getterOld := function: Double
  begin
    if idxOld >= 0 then Result := gSoundRegs[idxOld].curVol else Result := 1.0;
  end;

  setterOld := procedure(v: Double)
  begin
    v := Max(0.0, v);
    if idxOld >= 0 then gSoundRegs[idxOld].curVol := v;
    SetSoundVolume(oldH, v);
  end;

  // NEW getters/setters
  getterNew := function: Double
  begin
    if idxNew >= 0 then Result := gSoundRegs[idxNew].curVol else Result := 0.0;
  end;

  setterNew := procedure(v: Double)
  begin
    v := Clamp(v, 0.0, 1.0);
    if idxNew >= 0 then gSoundRegs[idxNew].curVol := v;
    SetSoundVolume(newH, v);
  end;

  // uruchom tweeny (liniowe). Jeśli masz ease equal-power, możesz podmienić:
  //   easeLinear -> easeSinInOut i odpowiednio skalować.
  TweenValue(getterOld, setterOld, 0.0, time, easeLinear,
    procedure
    begin
      // Zatrzymaj na końcu nawet jeśli rejestr się zmienił
      SetSoundVolume(oldH, 0.0);
      StopSoundEx(oldH);
      gCrossFading := False;
    end);

  TweenValue(getterNew, setterNew, targetNew, time, easeLinear);
end;

{ ==== Debug overlay ========================================================= }
procedure DebugToggle;
begin
  gDebugOn := not gDebugOn;
end;

procedure DebugOverlayDraw(x, y: Integer);
var
  line: Integer;
  function NextY: Integer;
  begin
    Inc(line);
    Result := y + (line-1)*16;
  end;
begin
  if not gDebugOn then Exit;
  line := 0;
  DrawText('Wilga Extras (Debug)', x, NextY, 14, COLOR_YELLOW);
  DrawText('FPS: ' + IntToStr(GetFPS), x, NextY, 12, COLOR_WHITE);
  DrawText('DrawCalls: ' + IntToStr(gDrawCalls), x, NextY, 12, COLOR_WHITE);
  DrawText('Tweens: ' + IntToStr(TweensActive), x, NextY, 12, COLOR_WHITE);
  // reset licznik drawcalls co klatkę (opcjonalnie)
  gDrawCalls := 0;
end;
{=============================dodatki do rysowania tekstu=================================================== }
// Tekst pionowy (vertical text)
// Tekst pionowy (vertical text)
procedure DrawTextVertical(const text: String; pos: TVector2; fontSize: Integer; const color: TColor);
var
  i: Integer;
begin
  for i := 1 to Length(text) do
    DrawText(text[i], Round(pos.x), Round(pos.y + (i - 1) * fontSize), fontSize, color);
end;

// Efekt "typewriter" (pojawianie się liter z czasem)
procedure DrawTextTypewriter(const text: String; pos: TVector2; fontSize: Integer; const color: TColor; elapsedTime: Double; charsPerSecond: Double);
var
  visibleChars: Integer;
begin
  visibleChars := Trunc(elapsedTime * charsPerSecond);
  if visibleChars > Length(text) then
    visibleChars := Length(text);
  DrawText(Copy(text, 1, visibleChars), Round(pos.x), Round(pos.y), fontSize, color);
end;

// Efekt "fala" (wave)
procedure DrawTextWave(const text: String; pos: TVector2; fontSize: Integer; const color: TColor; time: Double; amplitude, speed: Double);
var
  i: Integer;
  x, y: Double;
  ch: String;
begin
  x := pos.x;
  for i := 1 to Length(text) do
  begin
    y := pos.y + Sin(time * speed + i * 0.5) * amplitude;
    ch := text[i];
    DrawText(ch, Round(x), Round(y), fontSize, color);
    x += MeasureTextWidth(ch, fontSize);
  end;
end;

// Efekt "pulsowanie"
procedure DrawTextPulse(const text: String; pos: TVector2; fontSize: Integer; const color: TColor; time: Double; pulseSpeed, pulseAmount: Double);
var
  scale: Double;
  w: Double;
begin
  scale := 1.0 + Sin(time * pulseSpeed) * pulseAmount;
  w := MeasureTextWidth(text, Round(fontSize * scale));
  DrawText(text, Round(pos.x - w / 2), Round(pos.y), Round(fontSize * scale), color);
end;

// Tekst z wypełnieniem teksturą



procedure DrawTextShake(const text: String; pos: TVector2; fontSize: Integer; const color: TColor; time: Double; intensity: Double);
var
  i: Integer;
  offsetX, offsetY: Double;
  x: Double;
  ch: String;
begin
  x := pos.x;
  for i := 1 to Length(text) do
  begin
    offsetX := (Random - 0.5) * intensity;
    offsetY := (Random - 0.5) * intensity;
    ch := text[i];
    DrawText(ch, Round(x + offsetX), Round(pos.y + offsetY), fontSize, color);
    x += MeasureTextWidth(ch, fontSize);
  end;
end;
// ===== Gwiazda =====
procedure DrawStarV(center: TVector2; points: Integer; rOuter, rInner: Double;
  rotationDeg: Double; const color: TColor; filled: Boolean; thickness: Integer);
var
  i, n: Integer;
  ang, step, rot, r: Double;
  pts: array of TInputVector;
begin
  if points < 2 then Exit;
  n := points * 2;
  SetLength(pts, n);

  // -90°, aby przy rotationDeg = 0 wierzchołek był u góry
  rot := DegToRad(rotationDeg - 90.0);
  step := Pi / points; // kąt między kolejnymi punktami (outer/inner)

  for i := 0 to n - 1 do
  begin
    r := rOuter;
    if (i and 1) = 1 then r := rInner;
    ang := rot + i * step;
    pts[i].x := center.x + r * Cos(ang);
    pts[i].y := center.y + r * Sin(ang);
  end;

  if filled then
    DrawPolygon(pts, color, True)
  else
    DrawPolyline(pts, color, thickness, True);
end;

procedure DrawStar(cx, cy: Double; points: Integer; rOuter, rInner: Double;
  rotationDeg: Double; const color: TColor; filled: Boolean; thickness: Integer);
var
  c: TVector2;
begin
  c.x := cx; c.y := cy;
  DrawStarV(c, points, rOuter, rInner, rotationDeg, color, filled, thickness);
end;

// ===== Serce =====
// Parametryzacja serca (samplowana krzywa):
// x = 16 sin^3(t)
// y = 13 cos t - 5 cos 2t - 2 cos 3t - cos 4t
procedure DrawHeartV(center: TVector2; width, height: Double; rotationDeg: Double;
  const color: TColor; filled: Boolean; thickness: Integer; samples: Integer);
var
  i: Integer;
  t, sx, sy, rot, x, y, xr, yr: Double;
  pts: array of TInputVector;
begin
  if samples < 16 then samples := 16;
  SetLength(pts, samples);

  sx := width / 32.0;
  sy := height / 30.0;

  // offset -90° aby przy rotationDeg=0 serce było „prosto”
  rot := DegToRad(rotationDeg -180.0);

  for i := 0 to samples - 1 do
  begin
    t := (2 * Pi) * (i / (samples - 1));
    x := 16 * Power(Sin(t), 3);
    y := 13 * Cos(t) - 5 * Cos(2*t) - 2 * Cos(3*t) - Cos(4*t);

    x := x * sx;
    y := y * sy;

    xr := x * Cos(rot) - y * Sin(rot);
    yr := x * Sin(rot) + y * Cos(rot);

    pts[i].x := center.x + xr;
    pts[i].y := center.y + yr;
  end;

  if filled then
    DrawPolygon(pts, color, True)
  else
    DrawPolyline(pts, color, thickness, True);
end;


procedure DrawHeart(cx, cy: Double; width, height: Double; rotationDeg: Double;
  const color: TColor; filled: Boolean; thickness: Integer; samples: Integer);
var
  c: TVector2;
begin
  c.x := cx; c.y := cy;
  DrawHeartV(c, width, height, rotationDeg, color, filled, thickness, samples);
end;


{ ==== Perlin Noise implementation ========================================== }

{ TXorShift32 }
procedure TXorShift32.Seed(aSeed: LongWord);
begin
  if aSeed = 0 then aSeed := $9E3779B9;
  s := aSeed;
end;

function TXorShift32.NextU32: LongWord;
var x: LongWord;
begin
  x := s;
  x := x xor (x shl 13);
  x := x xor (x shr 17);
  x := x xor (x shl 5);
  s := x;
  Result := x;
end;

function TXorShift32.NextFloat: Double;
begin
  Result := (NextU32 and $FFFFFF) / $1000000; // [0,1)
end;

{ TPerlin }
class function TPerlin.Create(seed: LongInt): TPerlin;
const
  N = 256;
var
  i, j: Integer;
  p: array[0..N-1] of Byte;
  rng: TXorShift32;
  tmp: Byte;
begin
  for i := 0 to N-1 do p[i] := i;
  rng.Seed(LongWord(seed));
  for i := N-1 downto 1 do
  begin
    j := Trunc(rng.NextFloat * (i + 1)); // 0..i
    tmp := p[i];
    p[i] := p[j];
    p[j] := tmp;
  end;
  for i := 0 to N-1 do
  begin
    Result.perm[i] := p[i];
    Result.perm[i + N] := p[i];
  end;
end;

class function TPerlin.Fade(t: Double): Double;
begin
  Result := t*t*t*(t*(t*6 - 15) + 10);
end;

class function TPerlin.Lerp(a, b, t: Double): Double;
begin
  Result := a + t*(b - a);
end;

class function TPerlin.Grad2(hash: Integer; x, y: Double): Double;
var h: Integer; u, v: Double;
begin
  h := hash and 7;
  if (h and 1) = 0 then u := x else u := -x;
  if (h and 2) = 0 then v := y else v := -y;
  if (h and 4) <> 0 then
    Result := u
  else
    Result := u + v;
end;

class function TPerlin.Grad3(hash: Integer; x, y, z: Double): Double;
var h: Integer; u, v: Double;
begin
  h := hash and 15;
  if (h < 8) then u := x else u := y;
  if (h < 4) then v := y
  else if (h = 12) or (h = 14) then v := x
  else v := z;
  if (h and 1) = 0 then u :=  u else u := -u;
  if (h and 2) = 0 then v :=  v else v := -v;
  Result := u + v;
end;

function TPerlin.Noise2D(x, y: Double): Double;
var
  Xi, Yi: Integer;
  xf, yf, u, v: Double;
  aa, ab, ba, bb: Integer;
  x1, x2: Double;
  idxA, idxB: Integer;
begin
  Xi := Floor(x) and 255;
  Yi := Floor(y) and 255;
  xf := x - Floor(x);
  yf := y - Floor(y);

  u := Fade(xf);
  v := Fade(yf);

  idxA := perm[Xi] + Yi;
  idxB := perm[Xi + 1] + Yi;

  aa := perm[idxA];
  ab := perm[idxA + 1];
  ba := perm[idxB];
  bb := perm[idxB + 1];

  x1 := Lerp(Grad2(aa,   xf,   yf),
             Grad2(ba,   xf-1, yf), u);
  x2 := Lerp(Grad2(ab,   xf,   yf-1),
             Grad2(bb,   xf-1, yf-1), u);
  Result := Lerp(x1, x2, v);
end;

function TPerlin.Noise3D(x, y, z: Double): Double;
var
  Xi, Yi, Zi: Integer;
  xf, yf, zf, u, v, w: Double;
  A, AA, AB, B, BA, BB: Integer;
  x1, x2, y1, y2: Double;
begin
  Xi := Floor(x) and 255;
  Yi := Floor(y) and 255;
  Zi := Floor(z) and 255;

  xf := x - Floor(x);
  yf := y - Floor(y);
  zf := z - Floor(z);

  u := Fade(xf);
  v := Fade(yf);
  w := Fade(zf);

AA := perm[A] + Zi;
AB := perm[A + 1] + Zi;
BA := perm[B] + Zi;
BB := perm[B + 1] + Zi;


  x1 := Lerp(Grad3(perm[AA  ], xf  , yf  , zf  ),
             Grad3(perm[BA  ], xf-1, yf  , zf  ), u);
  x2 := Lerp(Grad3(perm[AB  ], xf  , yf-1, zf  ),
             Grad3(perm[BB  ], xf-1, yf-1, zf  ), u);
  y1 := Lerp(x1, x2, v);

  x1 := Lerp(Grad3(perm[AA+1], xf  , yf  , zf-1),
             Grad3(perm[BA+1], xf-1, yf  , zf-1), u);
  x2 := Lerp(Grad3(perm[AB+1], xf  , yf-1, zf-1),
             Grad3(perm[BB+1], xf-1, yf-1, zf-1), u);
  y2 := Lerp(x1, x2, v);

  Result := Lerp(y1, y2, w);
end;

function TPerlin.FBM2D(x, y: Double; octaves: Integer; lacunarity, persistence: Double): Double;
var
  i: Integer;
  amp, sum, maxAmp: Double;
begin
  if octaves < 1 then octaves := 1;
  amp := 1.0; sum := 0.0; maxAmp := 0.0;
  for i := 0 to octaves-1 do
  begin
    sum += Noise2D(x, y) * amp;
    maxAmp += amp;
    x *= lacunarity; y *= lacunarity;
    amp *= persistence;
  end;
  if maxAmp <> 0 then
    Result := sum / maxAmp
  else
    Result := 0.0;
end;

function Normalize01(v: Double): Double; inline;
begin
  Result := 0.5 * (v + 1.0);
end;

function PerlinNoise2D(seed: LongInt; x, y, scale: Double): Double;
var perlin: TPerlin;
begin
  perlin := TPerlin.Create(seed);
  Result := perlin.Noise2D(x*scale, y*scale);
end;

function PerlinFBM2D(seed: LongInt; x, y, scale: Double; octaves: Integer; lacunarity, persistence: Double): Double;
var perlin: TPerlin;
begin
  perlin := TPerlin.Create(seed);
  Result := perlin.FBM2D(x*scale, y*scale, octaves, lacunarity, persistence);
end;
end.
