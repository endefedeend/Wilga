program SimpleImageLoad;
uses wilga;

var
  MyTexture: TTexture;

procedure Setup;
begin
  InitWindow(800, 600, 'Simple Image Load');
  
  // Ładujemy obrazek asynchronicznie
  LoadImageFromURL('https://picsum.photos/200/300', 
    procedure (const tex: TTexture)
    begin
      MyTexture := tex;
      Writeln('Obrazek załadowany!');
    end
  );
end;

procedure Update(const dt: Double);
begin
 
end;

procedure Draw(const dt: Double);
begin
  ClearBackground(COLOR_DARKGRAY);
  
  // Rysujemy obrazek jeśli jest gotowy
  if TextureIsReady(MyTexture) then
    DrawTexture(MyTexture, 100, 100, COLOR_WHITE);
  
  // Informacja dla użytkownika
  if not TextureIsReady(MyTexture) then
    DrawText('Ładowanie obrazka...', 100, 50, 20, COLOR_WHITE)
  else
    DrawText('Obrazek załadowany!', 100, 50, 20, COLOR_GREEN);
end;

begin
  Setup;
  Run(@Update, @Draw);
end.
