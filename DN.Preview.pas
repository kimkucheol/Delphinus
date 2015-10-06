{
#########################################################
# Copyright by Alexander Benikowski                     #
# This unit is part of the Delphinus project hosted on  #
# https://github.com/Memnarch/Delphinus                 #
#########################################################
}
unit DN.Preview;

interface

uses
  Classes,
  Types,
  Windows,
  Messages,
  Delphinus.UITypes,
  Controls,
  Graphics,
  Math,
  DN.Package.Intf,
  DN.Controls,
  DN.Controls.Button,
  ImgList;

type
  TNotifyEvent = reference to procedure(Sender: TObject);

  TPreview = class(TCustomControl)
  private
    FTarget: TBitmap;
    FPackage: IDNPackage;
    FSelected: Boolean;
    FBGSelectedStart: TColor;
    FBGSelectedEnd: TColor;
    FBGStart: TColor;
    FBGEnd: TColor;
    FInstallColor: TColor;
    FUninstallColor: TColor;
    FUpdateColor: TColor;
    FInfoColor: TColor;
    FGUI: TDNControlsController;
    FButton: TDNButton;
    FUpdateButton: TDNButton;
    FInstalledVersion: string;
    FUpdateVersion: string;
    FOnUpdate: TNotifyEvent;
    FOnInstall: TNotifyEvent;
    FOnUninstall: TNotifyEvent;
    FOSImages: TImageList;
    procedure SetSelected(const Value: Boolean);
    procedure SetPackage(const Value: IDNPackage);
    procedure SetInstalledVersion(const Value: string);
    procedure SetUpdateVersion(const Value: string);
    procedure DoInstall();
    procedure DoUninstall();
    procedure DoUpdate();
    procedure HandleButtonClick(Sender: TObject);
    procedure DownSample;
    procedure UpdateControls;
    procedure PaintOsImages;
  protected
    procedure Paint; override;
    procedure SetupControls;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent; AOsImages: TImageList); reintroduce;
    destructor Destroy(); override;
    property Package: IDNPackage read FPackage write SetPackage;
    property Selected: Boolean read FSelected write SetSelected;
    property InstalledVersion: string read FInstalledVersion write SetInstalledVersion;
    property UpdateVersion: string read FUpdateVersion write SetUpdateVersion;
    property OnClick;
    property OnInstall: TNotifyEvent read FOnInstall write FOnInstall;
    property OnUninstall: TNotifyEvent read FOnUninstall write FOnUninstall;
    property OnUpdate: TNotifyEvent read FOnUpdate write FOnUpdate;
  end;

const
  CPreviewWidth = 256;
  CPreviewImageSize = 80;
  CPreviewHeight = CPreviewImageSize;
  CButtonHeight = 21;
  CButtonWidth = 100;
  CMargin = 3;
  CLeftMargin = CMargin*2 + CPreviewImageSize;

implementation

uses
  DN.Graphics,
  DN.Compiler.Intf;

{ TPreview }

constructor TPreview.Create(AOwner: TComponent; AOsImages: TImageList);
begin
  inherited Create(AOwner);
  FOSImages := AOsImages;
  FTarget := TBitmap.Create();
  FTarget.PixelFormat := pf32bit;
  Width := CPreviewWidth;
  Height := CPreviewHeight;

  FBGSelectedStart := RGB(250, 134, 30);
  FBGSelectedEnd := AlterColor(FBGSelectedStart, -5);
  FBGStart := AlterColor(clWhite, -30);
  FBGEnd := AlterColor(FBGStart, -5);
  FInstallColor := RGB(151, 224, 25);
  FUninstallColor := RGB(224, 25, 51);
  FUpdateColor := RGB(153, 242, 222);
  FInfoColor := RGB(242, 211, 153);
  FGUI := TDNControlsController.Create();
  FGUI.Parent := Self;
  SetupControls();
end;

destructor TPreview.Destroy;
begin
  FGUI.Free;
  FTarget.Free();
  inherited;
end;

procedure TPreview.DoInstall;
begin
  if Assigned(FOnInstall) then
    FOnInstall(Self);
end;

procedure TPreview.DoUninstall;
begin
  if Assigned(FOnUninstall) then
    FOnUninstall(Self);
end;

procedure TPreview.DoUpdate;
begin
  if Assigned(FOnUpdate) then
    FOnUpdate(Self);
end;

procedure TPreview.DownSample;
var
  LTemp: TBitmap;
  LOldMode: Integer;
begin
  LTemp := TBitmap.Create();
  try
    LTemp.PixelFormat := pf32bit;
    if Assigned(FPackage.Picture) then
    begin
      LTemp.SetSize(FPackage.Picture.Width, FPackage.Picture.Height);
      LTemp.Canvas.Brush.Color := clWhite;
      LTemp.Canvas.FillRect(LTemp.Canvas.ClipRect);
      LTemp.Canvas.Draw(0, 0, FPackage.Picture.Graphic);
    end;
    FTarget.SetSize(CPreviewImageSize, CPreviewImageSize);
    FTarget.Canvas.FillRect(FTarget.Canvas.ClipRect);

    LOldMode := GetStretchBltMode(FTarget.Handle);
    SetStretchBltMode(FTarget.Canvas.Handle, HALFTONE);
    StretchBlt(FTarget.Canvas.Handle, 0, 0, FTarget.Width, FTarget.Height,
    LTemp.Canvas.Handle, 0, 0, LTemp.Width, LTemp.Height, SRCCOPY);
    SetStretchBltMode(FTarget.Canvas.Handle, LOldMode);
  finally
    LTemp.Free;
  end;
end;

procedure TPreview.HandleButtonClick(Sender: TObject);
begin
  if Sender = FButton then
  begin
    if InstalledVersion <> '' then
    begin
      DoUninstall();
    end
    else
    begin
      DoInstall();
    end;
  end
  else
  begin
    if Sender = FUpdateButton then
      DoUpdate()
  end;
end;

procedure TPreview.Paint;
var
  LVersionString, LDescription, LLicenseType: string;
  LRect: TRect;
begin
  inherited;
  if Assigned(FPackage) then
  begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := clWindow;
    Canvas.FillRect(Canvas.ClipRect);
    Canvas.Brush.Style := bsClear;

    Canvas.Draw(0, 0, FTarget);
    Canvas.Font.Style := [TFontStyle.fsBold];
    Canvas.TextOut(CLeftMargin, CMargin, FPackage.Name);
    Canvas.Font.Style := [];
    Canvas.TextOut(CLeftMargin, (CMargin + Abs(Canvas.Font.Height)), FPackage.Author);

    if FPackage.LicenseType <> '' then
      LLicenseType := FPackage.LicenseType
    else
      LLicenseType := 'No license';

    Canvas.TextOut(CLeftMargin, (CMargin + Abs(Canvas.Font.Height))*2, LLicenseType);
    Canvas.Font.Style := [];

    if InstalledVersion <> '' then
    begin
      LVersionString := InstalledVersion;
      if UpdateVersion <> '' then
      begin
        LVersionString := LVersionString + ' -> ' + UpdateVersion;
      end;
      Canvas.TextOut(CLeftMargin, (CMargin + Abs(Canvas.Font.Height))*3, LVersionString);
    end;

    LDescription := FPackage.Description;
    LRect.Left := CLeftMargin;
    LRect.Top := (CMargin + Abs(Canvas.Font.Height))*4;
    LRect.Right := Width - CMargin;
    LRect.Bottom := Height - 25 - CMargin;
    Canvas.TextRect(LRect, LDescription, [tfWordBreak, tfEndEllipsis]);

    Canvas.Pen.Color := clBtnShadow;
    Canvas.Rectangle(0, 0, Width, Height);
    FGui.PaintTo(Canvas);
    PaintOsImages();
  end;
end;

procedure TPreview.PaintOsImages;
var
  LOffset: Integer;
  LTopOffset: Integer;
begin
  LOffset :=  FButton.Left - FOSImages.Width - CMargin;
  LTopOffset := Height - FOSImages.Height - CMargin;
  if ([cpWin32, cpWin64] * FPackage.Platforms) <> [] then
  begin
    FOSImages.Draw(Canvas, LOffset, LTopOffset, 0);
    Dec(LOffset, FOSImages.Width);
  end;

  if cpOSX32 in FPackage.Platforms then
  begin
    FOSImages.Draw(Canvas, LOffset, LTopOffset, 1);
  end;
end;

procedure TPreview.Resize;
begin
  inherited;
  UpdateControls();
end;

procedure TPreview.SetUpdateVersion(const Value: string);
begin
  FUpdateVersion := Value;
  FUpdateButton.Visible := FUpdateVersion <> '';
  UpdateControls();
  InvalidateRect(Handle, Rect(Left, Top, Width, Height), False);
end;

procedure TPreview.UpdateControls;
begin
  FButton.Left := Width - FButton.Width - CMargin;
  FUpdateButton.Left := Width - FUpdateButton.Width - CMargin;
end;

procedure TPreview.SetInstalledVersion(const Value: string);
begin
  FInstalledVersion := Value;
  if FInstalledVersion <> '' then
  begin
    FButton.Caption := 'Uninstall';
    FButton.HoverColor := FUninstallColor; //clRed;
  end
  else
  begin
    FButton.Caption := 'Install';
    FButton.HoverColor := FInstallColor //clGreen;
  end;
  InvalidateRect(Handle, Rect(Left, Top, Width, Height), False);
end;

procedure TPreview.SetPackage(const Value: IDNPackage);
begin
  FPackage := Value;
  if Assigned(FPackage) then
    DownSample();
end;

procedure TPreview.SetSelected(const Value: Boolean);
begin
  if FSelected <> Value then
  begin
    FSelected := Value;
    Invalidate;
  end;
end;

procedure TPreview.SetupControls;
begin
  FButton := TDNButton.Create();
  FButton.Top := Height - CButtonHeight - CMargin;
  FButton.Width := CButtonWidth;
  FButton.Height := CButtonHeight;
  FButton.Color := clSilver;
  FButton.OnClick := HandleButtonClick;
  FGUI.Controls.Add(FButton);

  FUpdateButton := TDNButton.Create();
  FUpdateButton.Width := CButtonWidth;
  FUpdateButton.Height := CButtonHeight;
  FUpdateButton.Top := Height - CButtonHeight*2 - CMargin*2;
  FUpdateButton.Color := clSilver;
  FUpdateButton.HoverColor := FUpdateColor;
  FUpdateButton.Visible := False;
  FUpdateButton.Caption := 'Update';
  FUpdateButton.OnClick := HandleButtonClick;
  FGUI.Controls.Add(FUpdateButton);
end;

end.
