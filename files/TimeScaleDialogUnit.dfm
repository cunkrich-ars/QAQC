object TimeScaleDialog: TTimeScaleDialog
  Left = 457
  Top = 290
  BorderIcons = [biSystemMenu]
  BorderStyle = bsToolWindow
  Caption = 'Time Scale'
  ClientHeight = 40
  ClientWidth = 160
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Slider: TTrackBar
    Left = 5
    Top = 11
    Width = 150
    Height = 20
    Max = 5
    Min = 1
    PageSize = 1
    Position = 1
    TabOrder = 0
    ThumbLength = 15
    TickMarks = tmBoth
    TickStyle = tsNone
  end
end
