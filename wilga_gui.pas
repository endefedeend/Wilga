unit wilga_gui;
{$mode objfpc}{$H+}

interface

uses
  JS, Web, SysUtils, Math, wilga;

type
  TWidget = class;
  TButton = class;
  TLabel = class;
  TSlider = class;
  TCheckbox = class;
  TPanel = class;
  TWindow = class;
  TTextBox = class;
  TProgressBar = class;
  TListBox = class;

  TWidgetState = (wsNormal, wsHover, wsActive, wsDisabled, wsDragging, wsFocused);
  TWidgetCallback = procedure(widget: TWidget) of object;
  TListBoxItemEvent = procedure(widget: TWidget; index: Integer; item: String) of object;

  { ---------- Base Widget ---------- }
  TWidget = class
  public
    Bounds: TRectangle;
    State: TWidgetState;
    Visible: Boolean;
    Enabled: Boolean;
    Tag: Integer;
    OnClick: TWidgetCallback;
    OnHover: TWidgetCallback;
    OnLeave: TWidgetCallback;
    Tooltip: String;

    constructor Create(ax, ay, aw, ah: Double); virtual;
    procedure Update; virtual;
    procedure Draw; virtual; abstract;
    function ContainsPoint(p: TInputVector): Boolean;
    procedure SetPosition(x, y: Double);
    procedure SetSize(w, h: Double);
  end;

  { ---------- Button (click on PRESS with debounce) ---------- }
  TButton = class(TWidget)
  private
    InPress: Boolean;
  public
    Text: String;
    ColorNormal: TColor;
    ColorHover: TColor;
    ColorActive: TColor;
    ColorDisabled: TColor;
    TextColor: TColor;
    FontSize: Integer;
    Icon: TTexture;

    constructor Create(ax, ay, aw, ah: Double); override;
    procedure Update; override;
    procedure Draw; override;
  end;

  TLabel = class(TWidget)
  public
    Text: String;
    Color: TColor;
    FontSize: Integer;
    Align: String; // 'left', 'center', 'right'
    WordWrap: Boolean;

    procedure Draw; override;
  end;

  TSlider = class(TWidget)
  public
    Value: Double;
    MinValue: Double;
    MaxValue: Double;
    BackgroundColor: TColor;
    SliderColor: TColor;
    OnChange: TWidgetCallback;
    ShowValue: Boolean;

    procedure Draw; override;
    procedure Update; override;
  end;

  { ---------- Checkbox (toggle on PRESS with debounce) ---------- }
  TCheckbox = class(TWidget)
  private
    InPress: Boolean;
  public
    Checked: Boolean;
    Text: String;
    Color: TColor;
    CheckColor: TColor;
    FontSize: Integer;

    constructor Create(ax, ay, aw, ah: Double); override;
    procedure Draw; override;
    procedure Update; override;
  end;

  { ---------- TextBox (focus/blur only, no typing) ---------- }
  TTextBox = class(TWidget)
  public
    Text: String;
    Placeholder: String;
    Color: TColor;
    TextColor: TColor;
    FontSize: Integer;
    MaxLength: Integer;
    OnTextChange: TWidgetCallback;
    OnEnterPressed: TWidgetCallback;

    procedure Draw; override;
    procedure Update; override;
    procedure Focus;
    procedure Blur;
  end;

  TProgressBar = class(TWidget)
  public
    Value: Double;
    MinValue: Double;
    MaxValue: Double;
    BackgroundColor: TColor;
    FillColor: TColor;
    ShowPercentage: Boolean;

    procedure Draw; override;
  end;

  TListBox = class(TWidget)
  public
    Items: array of String;
    SelectedIndex: Integer;
    ItemHeight: Integer;
    Color: TColor;
    SelectionColor: TColor;
    TextColor: TColor;
    FontSize: Integer;
    OnSelect: TListBoxItemEvent;
    ScrollOffset: Integer;

    constructor Create(ax, ay, aw, ah: Double); override;
    procedure Draw; override;
    procedure Update; override;
    procedure AddItem(const item: String);
    procedure Clear;
    function GetSelectedItem: String;
  end;

  TPanel = class(TWidget)
  public
    Color: TColor;
    BorderColor: TColor;
    BorderWidth: Integer;
    Children: array of TWidget;

    procedure Draw; override;
    procedure Update; override;
    procedure AddChild(widget: TWidget);
    procedure RemoveChild(widget: TWidget);
    procedure ClearChildren;
    procedure OffsetChildren(dx, dy: Double);
  end;

  { ---------- Window ---------- }
  TWindow = class(TWidget)
  private
    DragOffset: TInputVector;
    PrevHeight: Double;
    PrevWinX, PrevWinY: Double;
    procedure CloseClicked(widget: TWidget);
    procedure MinimizeClicked(widget: TWidget);
  public
    IsDragging: Boolean;
    Title: String;
    TitleBarHeight: Integer;
    TitleColor: TColor;
    CloseButton: TButton;
    MinimizeButton: TButton;
    ContentPanel: TPanel;
    Minimized: Boolean;

    constructor Create(ax, ay, aw, ah: Double); override;
    procedure Update; override;
    procedure Draw; override;

    procedure AddChild(widget: TWidget);
    procedure Close;
    procedure Minimize;
    procedure Restore;
    procedure BringToFront;
  end;

  { ---------- GUI Manager ---------- }
  TGUIManager = class
  private
    Widgets: array of TWidget;
    FocusedWidget: TWidget;
    IsAnyWindowDragging: Boolean;
    TooltipTimer: Double;
    TooltipWidget: TWidget;
    TooltipPosition: TInputVector;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(widget: TWidget);
    procedure Remove(widget: TWidget);
    procedure BringToFront(widget: TWidget);
    procedure Update;
    procedure Draw;
    function GetWidgetAt(x, y: Double): TWidget;
    procedure ShowTooltip(widget: TWidget; x, y: Double);
    procedure HideTooltip;
  end;

// Global
var
  GUI: TGUIManager;

implementation

{ ===== Helpers: geometry ===== }

function RectContainsPoint(const R: TRectangle; const P: TInputVector): Boolean; inline;
begin
  Result := (P.x >= R.x) and (P.x <= R.x + R.width) and
            (P.y >= R.y) and (P.y <= R.y + R.height);
end;

function RectCenter(const R: TRectangle): TInputVector; inline;
begin
  Result := NewVector(R.x + R.width * 0.5, R.y + R.height * 0.5);
end;

function RectInflate(const R: TRectangle; dx, dy: Double): TRectangle; inline;
begin
  Result := RectangleCreate(R.x + dx, R.y + dy, R.width - 2*dx, R.height - 2*dy);
end;

{ ===== Recursive hit-test ===== }

function HitTestWidget(w: TWidget; const p: TInputVector): TWidget; forward;

function HitTestPanel(panel: TPanel; const p: TInputVector): TWidget;
var
  i: Integer;
  child: TWidget;
begin
  Result := nil;
  if not (panel.Visible and panel.ContainsPoint(p)) then Exit;

  // najpierw dzieci (od góry stosu)
  for i := High(panel.Children) downto 0 do
  begin
    child := panel.Children[i];
    if Assigned(child) then
    begin
      Result := HitTestWidget(child, p);
      if Result <> nil then Exit;
    end;
  end;

  // trafiony sam panel
  Result := panel;
end;

function HitTestWindow(win: TWindow; const p: TInputVector): TWidget;
var
  r: TWidget;
begin
  Result := nil;
  if not (win.Visible and win.ContainsPoint(p)) then Exit;

  // przyciski okna nad wszystkim
  r := HitTestWidget(win.CloseButton, p);     if r <> nil then Exit(r);
  r := HitTestWidget(win.MinimizeButton, p);  if r <> nil then Exit(r);

  // panel treści + jego dzieci
  r := HitTestPanel(win.ContentPanel, p);     if r <> nil then Exit(r);

  // rama/pasek tytułu
  Result := win;
end;

function HitTestWidget(w: TWidget; const p: TInputVector): TWidget;
begin
  Result := nil;
  if not (w.Visible and w.ContainsPoint(p)) then Exit;

  if w is TWindow then
    Exit(HitTestWindow(TWindow(w), p))
  else if w is TPanel then
    Exit(HitTestPanel(TPanel(w), p))
  else
    Exit(w); // zwykły widget
end;

{ ===== TWidget ===== }

constructor TWidget.Create(ax, ay, aw, ah: Double);
begin
  Bounds := RectangleCreate(ax, ay, aw, ah);
  State := wsNormal;
  Visible := True;
  Enabled := True;
  Tooltip := '';
end;

function TWidget.ContainsPoint(p: TInputVector): Boolean;
begin
  Result := RectContainsPoint(Bounds, p);
end;

procedure TWidget.SetPosition(x, y: Double);
begin
  Bounds.x := x;
  Bounds.y := y;
end;

procedure TWidget.SetSize(w, h: Double);
begin
  Bounds.width := w;
  Bounds.height := h;
end;

procedure TWidget.Update;
var
  mp: TInputVector;
  isHover: Boolean;
begin
  if not Visible or not Enabled then Exit;

  mp := GetMousePosition;
  isHover := ContainsPoint(mp);

  // nie nadpisuj wizualnego fokusowania
  if State = wsFocused then Exit;

  // Tooltip
  if isHover and (Tooltip <> '') then
    GUI.ShowTooltip(Self, mp.x, mp.y)
  else if GUI.TooltipWidget = Self then
    GUI.HideTooltip;

  // Hover/Active wizualnie (bez klików)
  if isHover then
  begin
    if IsMouseButtonDown(0) then
      State := wsActive
    else if State <> wsHover then
    begin
      State := wsHover;
      if Assigned(OnHover) then OnHover(Self);
    end;
  end
  else
  begin
    if State in [wsHover, wsActive] then
    begin
      State := wsNormal;
      if Assigned(OnLeave) then OnLeave(Self);
    end;
  end;
end;

{ ===== TButton ===== }

constructor TButton.Create(ax, ay, aw, ah: Double);
begin
  inherited Create(ax, ay, aw, ah);
  ColorNormal := COLOR_GRAY;
  ColorHover := COLOR_LIGHTGRAY;
  ColorActive := COLOR_DARKGRAY;
  ColorDisabled := COLOR_DARKGRAY;
  TextColor := COLOR_WHITE;
  FontSize := 16;
  InPress := False;
end;

procedure TButton.Update;
var
  mp: TInputVector;
  isHover: Boolean;
begin
  if not Visible or not Enabled then Exit;

  mp := GetMousePosition;
  isHover := ContainsPoint(mp);

  if not InPress then
  begin
    if isHover and IsMouseButtonPressed(0) then
    begin
      InPress := True;
      State := wsActive;
      if Assigned(OnClick) then OnClick(Self); // klik na press
      Exit;
    end;

    if isHover then State := wsHover else State := wsNormal;
  end
  else
  begin
    if not IsMouseButtonDown(0) then
    begin
      InPress := False;
      if isHover then State := wsHover else State := wsNormal;
    end;
  end;
end;

procedure TButton.Draw;
var
  col: TColor;
  center: TInputVector;
begin
  if not Visible then Exit;

  if not Enabled then col := ColorDisabled else
    case State of
      wsNormal:  col := ColorNormal;
      wsHover:   col := ColorHover;
      wsActive:  col := ColorActive;
    else         col := ColorNormal;
    end;

  DrawRectangleRoundedRec(Bounds, 5, col, True);

  if TextureIsReady(Icon) then
  begin
    DrawTexture(Icon, Round(Bounds.x + 5), Round(Bounds.y + (Bounds.height - Icon.height) / 2), TextColor);
    center := RectCenter(Bounds);
    DrawTextCentered(Text, Round(center.x + Icon.width/2), Round(center.y), FontSize, TextColor);
  end
  else
  begin
    center := RectCenter(Bounds);
    DrawTextCentered(Text, Round(center.x), Round(center.y), FontSize, TextColor);
  end;
end;

{ ===== TLabel ===== }

procedure TLabel.Draw;
var
  pos: TInputVector;
  x, y: Integer;
begin
  if not Visible then Exit;

  pos := RectCenter(Bounds);

  if Align = 'left' then
    pos.x := Bounds.x
  else if Align = 'right' then
    pos.x := Bounds.x + Bounds.width;

  x := Round(pos.x);
  y := Round(pos.y);

  if WordWrap then
    DrawTextBoxed(Text, NewVector(Bounds.x, Bounds.y), Round(Bounds.width), FontSize, Color, 5)
  else
  begin
    if Align = 'left' then
      DrawText(Text, x, y, FontSize, Color)
    else if Align = 'right' then
    begin
      x := x - Round(MeasureTextWidth(Text, FontSize));
      DrawText(Text, x, y, FontSize, Color);
    end
    else
      DrawTextCentered(Text, x, y, FontSize, Color);
  end;
end;

{ ===== TSlider ===== }

procedure TSlider.Draw;
var
  fillWidth, handlePos: Double;
  handleRect: TRectangle;
  valueText: String;
begin
  if not Visible then Exit;

  DrawRectangleRoundedRec(Bounds, 3, BackgroundColor, True);

  fillWidth := Map(Value, MinValue, MaxValue, 0, Bounds.width);
  fillWidth := Clamp(fillWidth, 0, Bounds.width);
  DrawRectangleRoundedRec(RectangleCreate(Bounds.x, Bounds.y, fillWidth, Bounds.height), 3, SliderColor, True);

  handlePos := Map(Value, MinValue, MaxValue, Bounds.x, Bounds.x + Bounds.width);
  handleRect := RectangleCreate(handlePos - 5, Bounds.y - 2, 10, Bounds.height + 4);
  DrawRectangleRoundedRec(handleRect, 5, COLOR_WHITE, True);

  if ShowValue then
  begin
    valueText := FormatFloat('0.##', Value);
    DrawText(valueText, Round(handlePos - MeasureTextWidth(valueText, 12)/2), Round(Bounds.y - 15), 12, COLOR_WHITE);
  end;
end;

procedure TSlider.Update;
var
  mp: TInputVector;
  newValue: Double;
begin
  inherited Update;

  if State = wsActive then
  begin
    mp := GetMousePosition;
    newValue := Map(mp.x, Bounds.x, Bounds.x + Bounds.width, MinValue, MaxValue);
    newValue := Clamp(newValue, MinValue, MaxValue);

    if newValue <> Value then
    begin
      Value := newValue;
      if Assigned(OnChange) then OnChange(Self);
    end;
  end;
end;

{ ===== TCheckbox ===== }

constructor TCheckbox.Create(ax, ay, aw, ah: Double);
begin
  inherited Create(ax, ay, aw, ah);
  InPress := False;
  Checked := False;
  Color := COLOR_DARKGRAY;
  CheckColor := COLOR_GREEN;
  FontSize := 14;
end;

procedure TCheckbox.Draw;
var
  boxRect: TRectangle;
  textPos: TInputVector;
begin
  if not Visible then Exit;

  boxRect := RectangleCreate(Bounds.x, Bounds.y, Bounds.height, Bounds.height);
  DrawRectangleRoundedRec(boxRect, 3, Color, True);

  if Checked then
    DrawRectangleRoundedRec(RectInflate(boxRect, -4, -4), 2, CheckColor, True);

  textPos := NewVector(Bounds.x + Bounds.height + 5, Bounds.y);
  DrawText(Text, Round(textPos.x), Round(textPos.y), FontSize, Color);
end;

procedure TCheckbox.Update;
var
  mp: TInputVector; isHover: Boolean;
begin
  if not Visible or not Enabled then Exit;

  mp := GetMousePosition;
  isHover := ContainsPoint(mp);

  if not InPress then
  begin
    if isHover and IsMouseButtonPressed(0) then
    begin
      InPress := True;
      Checked := not Checked;
      if Assigned(OnClick) then OnClick(Self);
    end;
    if isHover then State := wsHover else State := wsNormal;
  end
  else
  begin
    if not IsMouseButtonDown(0) then
    begin
      InPress := False;
      if isHover then State := wsHover else State := wsNormal;
    end;
  end;
end;

{ ===== TTextBox ===== }

procedure TTextBox.Draw;
var
  textToDraw: String;
  textX, textY: Integer;
begin
  if not Visible then Exit;

  // tło
  DrawRectangleRoundedRec(Bounds, 3, Color, True);

  // ramka w fokusie
  if State = wsFocused then
    DrawRectangleLines(Round(Bounds.x), Round(Bounds.y),
                       Round(Bounds.width), Round(Bounds.height),
                       COLOR_YELLOW, 2);

  // tylko wizual: tekst/placeholder
  if (Text = '') and (Placeholder <> '') then
    textToDraw := Placeholder
  else
    textToDraw := Text;

  textX := Round(Bounds.x + 6);
  textY := Round(Bounds.y + Bounds.height/2 - (FontSize div 2));
  DrawText(textToDraw, textX, textY, FontSize, TextColor);
end;

procedure TTextBox.Update;
var
  mp: TInputVector;
begin
  inherited Update;
  mp := GetMousePosition;

  // fokus na press; blur robi globalnie GUIManager
  if IsMouseButtonPressed(0) and ContainsPoint(mp) then
    Focus;
end;

procedure TTextBox.Focus;
begin
  State := wsFocused;
  GUI.FocusedWidget := Self;
end;

procedure TTextBox.Blur;
begin
  if State = wsFocused then
    State := wsNormal;
  if GUI.FocusedWidget = Self then
    GUI.FocusedWidget := nil;
end;

{ ===== TProgressBar ===== }

procedure TProgressBar.Draw;
var
  fillWidth: Double;
  percentText: String;
begin
  if not Visible then Exit;

  DrawRectangleRoundedRec(Bounds, 3, BackgroundColor, True);

  fillWidth := Map(Value, MinValue, MaxValue, 0, Bounds.width);
  fillWidth := Clamp(fillWidth, 0, Bounds.width);
  DrawRectangleRoundedRec(RectangleCreate(Bounds.x, Bounds.y, fillWidth, Bounds.height), 3, FillColor, True);

  if ShowPercentage and (MaxValue <> 0) then
  begin
    percentText := FormatFloat('0%', (Value/MaxValue) * 100);
    DrawTextCentered(percentText, Round(Bounds.x + Bounds.width/2),
                     Round(Bounds.y + Bounds.height/2 - 8), 12, COLOR_WHITE);
  end;
end;

{ ===== TListBox ===== }

constructor TListBox.Create(ax, ay, aw, ah: Double);
begin
  inherited Create(ax, ay, aw, ah);
  ItemHeight := 20;
  Color := COLOR_DARKGRAY;
  SelectionColor := COLOR_BLUE;
  TextColor := COLOR_WHITE;
  FontSize := 12;
  SelectedIndex := -1;
  ScrollOffset := 0;
end;

procedure TListBox.Draw;
var
  i, yPos: Integer;
  itemRect: TRectangle;
  visibleItems, maxVisible: Integer;
begin
  if not Visible then Exit;

  DrawRectangleRoundedRec(Bounds, 3, Color, True);

  maxVisible := Trunc(Bounds.height / ItemHeight);
  if maxVisible < 0 then maxVisible := 0;

  if maxVisible > Length(Items) then
    visibleItems := Length(Items)
  else
    visibleItems := maxVisible;

  for i := 0 to visibleItems - 1 do
  begin
    if i + ScrollOffset >= Length(Items) then Break;

    yPos := Round(Bounds.y) + i * ItemHeight;
    itemRect := RectangleCreate(Bounds.x, yPos, Bounds.width, ItemHeight);

    if (i + ScrollOffset) = SelectedIndex then
      DrawRectangleRoundedRec(itemRect, 0, SelectionColor, True);

    DrawText(Items[i + ScrollOffset], Round(Bounds.x + 5), yPos + 2, FontSize, TextColor);
  end;
end;

procedure TListBox.Update;
var
  mp: TInputVector;
  itemIndex: Integer;
begin
  inherited Update;

  if State = wsActive then
  begin
    mp := GetMousePosition;
    itemIndex := ScrollOffset + Integer(Trunc((mp.y - Bounds.y) / ItemHeight));

    if (itemIndex >= 0) and (itemIndex < Length(Items)) then
    begin
      SelectedIndex := itemIndex;
      if Assigned(OnSelect) then OnSelect(Self, SelectedIndex, Items[SelectedIndex]);
    end;
  end;
end;

procedure TListBox.AddItem(const item: String);
begin
  SetLength(Items, Length(Items) + 1);
  Items[High(Items)] := item;
end;

procedure TListBox.Clear;
begin
  SetLength(Items, 0);
  SelectedIndex := -1;
end;

function TListBox.GetSelectedItem: String;
begin
  if (SelectedIndex >= 0) and (SelectedIndex < Length(Items)) then
    Result := Items[SelectedIndex]
  else
    Result := '';
end;

{ ===== TPanel ===== }

procedure TPanel.Draw;
var
  i: Integer;
begin
  if not Visible then Exit;

  DrawRectangleRoundedRec(Bounds, 5, Color, True);

  if BorderWidth > 0 then
    DrawRectangleLines(Round(Bounds.x), Round(Bounds.y),
                       Round(Bounds.width), Round(Bounds.height),
                       BorderColor, BorderWidth);

  for i := 0 to High(Children) do
    if Assigned(Children[i]) then
      Children[i].Draw;
end;

procedure TPanel.Update;
var
  i: Integer;
begin
  inherited Update;

  for i := 0 to High(Children) do
    if Assigned(Children[i]) then
      Children[i].Update;
end;

procedure TPanel.AddChild(widget: TWidget);
begin
  SetLength(Children, Length(Children) + 1);
  Children[High(Children)] := widget;
end;

procedure TPanel.RemoveChild(widget: TWidget);
var
  i, j: Integer;
begin
  for i := 0 to High(Children) do
    if Children[i] = widget then
    begin
      for j := i to High(Children) - 1 do
        Children[j] := Children[j + 1];
      SetLength(Children, Length(Children) - 1);
      Break;
    end;
end;

procedure TPanel.ClearChildren;
begin
  SetLength(Children, 0);
end;

procedure TPanel.OffsetChildren(dx, dy: Double);
var
  i: Integer;
begin
  for i := 0 to High(Children) do
    if Assigned(Children[i]) then
    begin
      Children[i].Bounds.x := Children[i].Bounds.x + dx;
      Children[i].Bounds.y := Children[i].Bounds.y + dy;
    end;
end;

{ ===== TWindow ===== }

constructor TWindow.Create(ax, ay, aw, ah: Double);
begin
  inherited Create(ax, ay, aw, ah);
  Title := 'Window';
  TitleBarHeight := 30;
  TitleColor := COLOR_DARKGRAY;
  IsDragging := False;
  Minimized := False;
  PrevHeight := ah;
  PrevWinX := ax;
  PrevWinY := ay;

  // Close
  CloseButton := TButton.Create(Bounds.x + Bounds.width - 25, Bounds.y + 5, 20, 20);
  CloseButton.Text := 'X';
  CloseButton.ColorNormal := COLOR_RED;
  CloseButton.ColorHover := COLOR_MAROON;
  CloseButton.FontSize := 12;
  CloseButton.OnClick := @CloseClicked;

  // Minimize
  MinimizeButton := TButton.Create(Bounds.x + Bounds.width - 50, Bounds.y + 5, 20, 20);
  MinimizeButton.Text := '_';
  MinimizeButton.ColorNormal := COLOR_GRAY;
  MinimizeButton.ColorHover := COLOR_LIGHTGRAY;
  MinimizeButton.FontSize := 12;
  MinimizeButton.OnClick := @MinimizeClicked;

  // Content panel
  ContentPanel := TPanel.Create(Bounds.x, Bounds.y + TitleBarHeight, Bounds.width, Bounds.height - TitleBarHeight);
  ContentPanel.Color := COLOR_LIGHTGRAY;
end;

procedure TWindow.Update;
var
  mp: TInputVector;
  titleBarRect: TRectangle;
  overTitleBar, overCloseBtn, overMinBtn: Boolean;
  dx, dy: Double;
begin
  if not Visible then Exit;

  mp := GetMousePosition;
  titleBarRect := RectangleCreate(Bounds.x, Bounds.y, Bounds.width, TitleBarHeight);

  // zakończ drag, gdy LPM nie jest wciśnięty
  if IsDragging and (not IsMouseButtonDown(0)) then
  begin
    IsDragging := False;
    GUI.IsAnyWindowDragging := False;
    State := wsNormal;
  end;

  // --- Zminimalizowane: drag + przyciski ---
  if Minimized then
  begin
    overTitleBar := RectContainsPoint(titleBarRect, mp);
    overCloseBtn := RectContainsPoint(CloseButton.Bounds, mp);
    overMinBtn   := RectContainsPoint(MinimizeButton.Bounds, mp);

    if (not IsDragging) and IsMouseButtonPressed(0) and overTitleBar and (not overCloseBtn) and (not overMinBtn) and (not GUI.IsAnyWindowDragging) then
    begin
      IsDragging := True;
      GUI.IsAnyWindowDragging := True;
      DragOffset := NewVector(mp.x - Bounds.x, mp.y - Bounds.y);
      State := wsDragging;
      BringToFront;
    end;

    if IsDragging and IsMouseButtonDown(0) then
    begin
      Bounds.x := mp.x - DragOffset.x;
      Bounds.y := mp.y - DragOffset.y;

      dx := Bounds.x - PrevWinX;
      dy := Bounds.y - PrevWinY;

      CloseButton.Bounds.x    := CloseButton.Bounds.x + dx;
      CloseButton.Bounds.y    := CloseButton.Bounds.y + dy;
      MinimizeButton.Bounds.x := MinimizeButton.Bounds.x + dx;
      MinimizeButton.Bounds.y := MinimizeButton.Bounds.y + dy;

      ContentPanel.Bounds.x   := ContentPanel.Bounds.x + dx;
      ContentPanel.Bounds.y   := ContentPanel.Bounds.y + dy;

      PrevWinX := Bounds.x;
      PrevWinY := Bounds.y;
    end;

    CloseButton.Update;
    MinimizeButton.Update;
    Exit;
  end;

  // --- Normalne: drag + dzieci panelu ---
  overTitleBar := RectContainsPoint(titleBarRect, mp);
  overCloseBtn := RectContainsPoint(CloseButton.Bounds, mp);
  overMinBtn   := RectContainsPoint(MinimizeButton.Bounds, mp);

  if (not IsDragging) and IsMouseButtonPressed(0) and overTitleBar and (not overCloseBtn) and (not overMinBtn) and (not GUI.IsAnyWindowDragging) then
  begin
    IsDragging := True;
    GUI.IsAnyWindowDragging := True;
    DragOffset := NewVector(mp.x - Bounds.x, mp.y - Bounds.y);
    State := wsDragging;
    BringToFront;
  end;

  if IsDragging and IsMouseButtonDown(0) then
  begin
    Bounds.x := mp.x - DragOffset.x;
    Bounds.y := mp.y - DragOffset.y;

    dx := Bounds.x - PrevWinX;
    dy := Bounds.y - PrevWinY;

    CloseButton.Bounds.x    := CloseButton.Bounds.x + dx;
    CloseButton.Bounds.y    := CloseButton.Bounds.y + dy;
    MinimizeButton.Bounds.x := MinimizeButton.Bounds.x + dx;
    MinimizeButton.Bounds.y := MinimizeButton.Bounds.y + dy;

    ContentPanel.Bounds.x := ContentPanel.Bounds.x + dx;
    ContentPanel.Bounds.y := ContentPanel.Bounds.y + dy;
    ContentPanel.OffsetChildren(dx, dy);

    PrevWinX := Bounds.x;
    PrevWinY := Bounds.y;
  end;

  CloseButton.Update;
  MinimizeButton.Update;
  ContentPanel.Update;
end;

procedure TWindow.Draw;
var
  titleBarRect: TRectangle;
begin
  if not Visible then Exit;

  if not Minimized then
  begin
    DrawRectangleRoundedRec(Bounds, 5, COLOR_GRAY, True);
    titleBarRect := RectangleCreate(Bounds.x, Bounds.y, Bounds.width, TitleBarHeight);
    DrawRectangleRoundedRec(titleBarRect, 5, TitleColor, True);
    DrawText(Title, Round(Bounds.x + 10), Round(Bounds.y + TitleBarHeight/2 - 8), 14, COLOR_WHITE);
    CloseButton.Draw;
    MinimizeButton.Draw;
    ContentPanel.Draw;
  end
  else
  begin
    titleBarRect := RectangleCreate(Bounds.x, Bounds.y, Bounds.width, TitleBarHeight);
    DrawRectangleRoundedRec(titleBarRect, 5, TitleColor, True);
    DrawText(Title, Round(Bounds.x + 10), Round(Bounds.y + TitleBarHeight/2 - 8), 14, COLOR_WHITE);
    CloseButton.Draw;
    MinimizeButton.Draw;
  end;
end;

procedure TWindow.AddChild(widget: TWidget);
begin
  ContentPanel.AddChild(widget);
end;

procedure TWindow.Close;
begin
  Visible := False;
  IsDragging := False;
  GUI.IsAnyWindowDragging := False;
end;

procedure TWindow.Minimize;
begin
  if Minimized then Exit;
  Minimized := True;

  PrevHeight := Bounds.height;
  Bounds.height := TitleBarHeight;

  ContentPanel.Visible := False;
  ContentPanel.Bounds := RectangleCreate(Bounds.x, Bounds.y + TitleBarHeight, Bounds.width, 0);

  CloseButton.Bounds.x    := Bounds.x + Bounds.width - 25;
  CloseButton.Bounds.y    := Bounds.y + 5;
  MinimizeButton.Bounds.x := Bounds.x + Bounds.width - 50;
  MinimizeButton.Bounds.y := Bounds.y + 5;

  GUI.IsAnyWindowDragging := False;
  IsDragging := False;
end;

procedure TWindow.Restore;
begin
  if not Minimized then Exit;
  Minimized := False;

  if PrevHeight < TitleBarHeight + 1 then
    PrevHeight := TitleBarHeight + 1;

  Bounds.height := PrevHeight;

  ContentPanel.Visible := True;
  ContentPanel.Bounds := RectangleCreate(Bounds.x, Bounds.y + TitleBarHeight, Bounds.width, Bounds.height - TitleBarHeight);

  CloseButton.Bounds.x    := Bounds.x + Bounds.width - 25;
  CloseButton.Bounds.y    := Bounds.y + 5;
  MinimizeButton.Bounds.x := Bounds.x + Bounds.width - 50;
  MinimizeButton.Bounds.y := Bounds.y + 5;

  GUI.IsAnyWindowDragging := False;
  IsDragging := False;
end;

procedure TWindow.BringToFront;
begin
  GUI.BringToFront(Self);
end;

procedure TWindow.CloseClicked(widget: TWidget);
begin
  Close;
end;

procedure TWindow.MinimizeClicked(widget: TWidget);
begin
  if Minimized then Restore else Minimize;
end;

{ ===== TGUIManager ===== }

constructor TGUIManager.Create;
begin
  inherited Create;
  SetLength(Widgets, 0);
  FocusedWidget := nil;
  IsAnyWindowDragging := False;
  TooltipTimer := 0.0;
  TooltipWidget := nil;
  TooltipPosition := NewVector(0, 0);
end;

destructor TGUIManager.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(Widgets) do
    if Assigned(Widgets[i]) then
      Widgets[i].Free;
  SetLength(Widgets, 0);
  inherited Destroy;
end;

procedure TGUIManager.Add(widget: TWidget);
begin
  SetLength(Widgets, Length(Widgets) + 1);
  Widgets[High(Widgets)] := widget;
end;

procedure TGUIManager.Remove(widget: TWidget);
var
  i, j: Integer;
begin
  for i := 0 to High(Widgets) do
    if Widgets[i] = widget then
    begin
      for j := i to High(Widgets) - 1 do
        Widgets[j] := Widgets[j + 1];
      SetLength(Widgets, Length(Widgets) - 1);
      Exit;
    end;
end;

procedure TGUIManager.BringToFront(widget: TWidget);
var
  i, idx: Integer;
begin
  idx := -1;
  for i := 0 to High(Widgets) do
    if Widgets[i] = widget then
    begin
      idx := i; Break;
    end;

  if idx >= 0 then
  begin
    for i := idx to High(Widgets) - 1 do
      Widgets[i] := Widgets[i + 1];
    Widgets[High(Widgets)] := widget;
  end;
end;

procedure TGUIManager.Update;
var
  i: Integer;
  mp: TInputVector;
  w: TWidget;
begin
  // stabilny reset "dragging"
  if not IsMouseButtonDown(0) then
    IsAnyWindowDragging := False;

  // globalny focus/blur TTextBox na press
  if IsMouseButtonPressed(0) then
  begin
    mp := GetMousePosition;
    w := GetWidgetAt(mp.x, mp.y);

    if (w is TTextBox) then
      TTextBox(w).Focus
    else if (FocusedWidget is TTextBox) then
      TTextBox(FocusedWidget).Blur;
  end;

  // tooltip timer
  if TooltipWidget <> nil then
    TooltipTimer := TooltipTimer + GetDeltaTime
  else
    TooltipTimer := 0.0;

  // okna najpierw
  for i := 0 to High(Widgets) do
    if Widgets[i] is TWindow then
      if (not IsAnyWindowDragging) or TWindow(Widgets[i]).IsDragging then
        Widgets[i].Update;

  // reszta
  for i := 0 to High(Widgets) do
    if not (Widgets[i] is TWindow) then
      Widgets[i].Update;
end;

procedure TGUIManager.Draw;
var
  i: Integer;
  tipW: Integer;
begin
  for i := 0 to High(Widgets) do
    Widgets[i].Draw;

  if (TooltipWidget <> nil) and (TooltipTimer > 1.0) then
  begin
    tipW := Round(MeasureTextWidth(TooltipWidget.Tooltip, 12) + 10);
    DrawRectangle(Round(TooltipPosition.x), Round(TooltipPosition.y), tipW, 20, COLOR_BLACK);
    DrawText(TooltipWidget.Tooltip, Round(TooltipPosition.x + 5), Round(TooltipPosition.y + 2), 12, COLOR_WHITE);
  end;
end;

function TGUIManager.GetWidgetAt(x, y: Double): TWidget;
var
  i: Integer;
  p: TInputVector;
  r: TWidget;
begin
  p := NewVector(x, y);
  for i := High(Widgets) downto 0 do
  begin
    r := HitTestWidget(Widgets[i], p);
    if r <> nil then Exit(r);
  end;
  Result := nil;
end;

procedure TGUIManager.ShowTooltip(widget: TWidget; x, y: Double);
begin
  if TooltipWidget <> widget then
  begin
    TooltipWidget := widget;
    TooltipTimer := 0.0;
    TooltipPosition := NewVector(x + 15, y + 15);
  end;
end;

procedure TGUIManager.HideTooltip;
begin
  TooltipWidget := nil;
  TooltipTimer := 0.0;
end;

initialization
  GUI := TGUIManager.Create;

end.
