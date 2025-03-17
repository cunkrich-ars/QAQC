object EventForm: TEventForm
  Left = 330
  Top = 186
  Width = 870
  Height = 640
  Caption = 'Event start datetime here'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnMouseMove = FormMouseMove
  OnPaint = FormPaint
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object TimeScrollBar: TScrollBar
    Left = 0
    Top = 597
    Width = 862
    Height = 16
    Align = alBottom
    Max = 1
    Min = 1
    PageSize = 1
    Position = 1
    TabOrder = 0
    TabStop = False
    OnChange = TimeScrollBarChange
    OnScroll = TimeScrollBarScroll
  end
  object ScalePopup: TPopupMenu
    Left = 308
    Top = 239
    object ScaleMenu: TMenuItem
      Caption = 'Tick Spacing'
      object Sixty: TMenuItem
        Caption = '60'
        OnClick = SetScale
      end
      object Thirty: TMenuItem
        Caption = '30'
        OnClick = SetScale
      end
      object Fifteen: TMenuItem
        Caption = '15'
        OnClick = SetScale
      end
      object Five: TMenuItem
        Caption = '5'
        OnClick = SetScale
      end
      object One: TMenuItem
        Caption = '1'
        OnClick = SetScale
      end
    end
  end
  object EditPopup: TPopupMenu
    Left = 620
    Top = 210
    object DischargeMenu: TMenuItem
      Caption = 'Show Discharge'
      OnClick = DischargeMenuClick
    end
    object DeleteMenu: TMenuItem
      Caption = 'Delete Point'
      Enabled = False
      OnClick = DeleteMenuClick
    end
    object EndEventMenu: TMenuItem
      Caption = 'End Event'
      Enabled = False
      OnClick = EndEventMenuClick
    end
    object RecessionMenu: TMenuItem
      Caption = 'Est. Recession'
      Enabled = False
      OnClick = RecessionMenuClick
    end
    object ShiftMenu: TMenuItem
      Caption = 'Shift Up/Down'
      Enabled = False
      OnClick = ShiftMenuClick
    end
  end
end
