object IntervalDialog: TIntervalDialog
  Left = 490
  Top = 450
  BorderStyle = bsDialog
  Caption = 'Data Interval'
  ClientHeight = 278
  ClientWidth = 442
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object OKBtn: TButton
    Left = 141
    Top = 241
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 0
    OnClick = OKBtnClick
  end
  object CancelBtn: TButton
    Left = 225
    Top = 241
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 1
  end
  object Panel1: TPanel
    Left = 6
    Top = 7
    Width = 430
    Height = 220
    BevelInner = bvRaised
    BevelOuter = bvLowered
    TabOrder = 2
    object Label1: TLabel
      Left = 94
      Top = 8
      Width = 28
      Height = 13
      Caption = 'Start'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold, fsUnderline]
      ParentFont = False
    end
    object Label2: TLabel
      Left = 311
      Top = 8
      Width = 23
      Height = 13
      Caption = 'End'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold, fsUnderline]
      ParentFont = False
    end
    object Label3: TLabel
      Left = 63
      Top = 192
      Width = 31
      Height = 13
      Caption = 'DOY:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object Label4: TLabel
      Left = 278
      Top = 192
      Width = 31
      Height = 13
      Caption = 'DOY:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object StartCalendar: TMonthCalendar
      Left = 16
      Top = 24
      Width = 191
      Height = 154
      Date = 37972.701373877320000000
      TabOrder = 0
      OnClick = StartCalendarClick
      OnGetMonthInfo = StartCalendarGetMonthInfo
    end
    object EndCalendar: TMonthCalendar
      Left = 223
      Top = 24
      Width = 191
      Height = 154
      Date = 37945.701373877320000000
      TabOrder = 1
      OnClick = EndCalendarClick
      OnGetMonthInfo = EndCalendarGetMonthInfo
    end
    object StartDayEdit: TEdit
      Left = 103
      Top = 188
      Width = 50
      Height = 21
      TabOrder = 2
      OnChange = StartDayEditChange
    end
    object EndDayEdit: TEdit
      Left = 318
      Top = 188
      Width = 50
      Height = 21
      TabOrder = 3
      OnChange = EndDayEditChange
    end
  end
end
