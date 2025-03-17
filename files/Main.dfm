object MainForm: TMainForm
  Left = 285
  Top = 232
  HorzScrollBar.Visible = False
  VertScrollBar.Visible = False
  AutoScroll = False
  Caption = 'Digital QA/QC'
  ClientHeight = 594
  ClientWidth = 862
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  KeyPreview = True
  Menu = MainMenu1
  OldCreateOrder = False
  Position = poScreenCenter
  Visible = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Bevel1: TBevel
    Left = 0
    Top = 0
    Width = 862
    Height = 559
    Align = alClient
  end
  object MainBox: TPaintBox
    Left = 0
    Top = 0
    Width = 862
    Height = 559
    Color = clWhite
    ParentColor = False
    OnClick = MainBoxClick
    OnContextPopup = MainBoxContextPopup
    OnDblClick = MainBoxDblClick
    OnMouseMove = MainBoxMouseMove
    OnPaint = MainBoxPaint
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 575
    Width = 862
    Height = 19
    Panels = <
      item
        Alignment = taRightJustify
        Bevel = pbNone
        Text = 'Year'
        Width = 40
      end
      item
        Bevel = pbNone
        Width = 50
      end
      item
        Alignment = taRightJustify
        Bevel = pbNone
        Text = 'Gage'
        Width = 40
      end
      item
        Bevel = pbNone
        Width = 50
      end
      item
        Width = 400
      end
      item
        Text = 'Approve = F8, Clear = F9'
        Width = 50
      end>
  end
  object TimeScrollBar: TScrollBar
    Left = 0
    Top = 559
    Width = 862
    Height = 16
    Align = alBottom
    Max = 364
    Min = 1
    PageSize = 1
    Position = 1
    TabOrder = 1
    TabStop = False
    OnChange = TimeScrollBarChange
  end
  object MainMenu1: TMainMenu
    Left = 87
    Top = 70
    object SetInterval: TMenuItem
      Caption = '&Interval'
      OnClick = SetIntervalClick
    end
    object MarchSelect: TMenuItem
      Caption = '&March'
      Enabled = False
      object StartStop: TMenuItem
        Caption = 'Start'
        OnClick = StartStopClick
      end
    end
    object DataTypeMenu: TMenuItem
      Caption = '&Data'
      object ShowPrecip: TMenuItem
        Caption = '&Precip'
        OnClick = SetDataType
      end
      object ShowFlumes: TMenuItem
        Caption = '&Flumes'
        OnClick = SetDataType
      end
    end
    object ListUnchecked: TMenuItem
      Caption = '&Unchecked...'
      OnClick = ListUncheckedClick
    end
  end
  object theDB: TDatabase
    AliasName = 'dap'
    DatabaseName = 'dapster'
    LoginPrompt = False
    SessionName = 'Default'
    Left = 227
    Top = 212
  end
  object SensorData: TQuery
    DatabaseName = 'dapster'
    Left = 220
    Top = 172
  end
  object ScalePopup: TPopupMenu
    OnPopup = ScalePopupPopup
    Left = 415
    Top = 227
    object ScaleMaxMenu: TMenuItem
      Caption = 'Scale Maximum'
      object Ten: TMenuItem
        Caption = '10'
        OnClick = SetScaleMax
      end
      object Nine: TMenuItem
        Caption = ' 9'
        OnClick = SetScaleMax
      end
      object Eight: TMenuItem
        Caption = ' 8'
        OnClick = SetScaleMax
      end
      object Seven: TMenuItem
        Caption = ' 7'
        OnClick = SetScaleMax
      end
      object Six: TMenuItem
        Caption = ' 6'
        OnClick = SetScaleMax
      end
      object Five: TMenuItem
        Caption = ' 5'
        OnClick = SetScaleMax
      end
      object Four: TMenuItem
        Caption = ' 4'
        OnClick = SetScaleMax
      end
      object Three: TMenuItem
        Caption = ' 3'
        OnClick = SetScaleMax
      end
      object Two: TMenuItem
        Caption = ' 2'
        OnClick = SetScaleMax
      end
      object One: TMenuItem
        Caption = ' 1'
        OnClick = SetScaleMax
      end
    end
    object ScaleUnitMenu: TMenuItem
      Caption = 'Scale Unit'
      object Unity: TMenuItem
        Caption = '1.0'
        OnClick = SetScaleUnit
      end
      object Tenth: TMenuItem
        Caption = '0.1'
        OnClick = SetScaleUnit
      end
      object Hundredth: TMenuItem
        Caption = '.01'
        OnClick = SetScaleUnit
      end
    end
  end
  object EventPopup: TPopupMenu
    Left = 370
    Top = 413
    object Approve: TMenuItem
      Caption = 'Approve/Reject Event'
      OnClick = ApproveClick
    end
    object EventWindow: TMenuItem
      Caption = 'Event Window'
      OnClick = EventWindowClick
    end
    object Space2: TMenuItem
    end
    object Space1: TMenuItem
    end
    object RevertEvent: TMenuItem
      Caption = 'Revert Event'
      OnClick = RevertEventClick
    end
  end
  object MapPopup: TPopupMenu
    Left = 400
    Top = 100
  end
  object GageQuery: TQuery
    DatabaseName = 'dapster'
    Left = 96
    Top = 257
  end
  object EventQuery: TQuery
    DatabaseName = 'dapster'
    Left = 160
    Top = 145
  end
  object FileDialog: TSaveDialog
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 171
    Top = 329
  end
end
