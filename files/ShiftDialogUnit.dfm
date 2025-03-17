object ShiftDialog: TShiftDialog
  Left = 245
  Top = 108
  BorderStyle = bsDialog
  Caption = 'Shift'
  ClientHeight = 124
  ClientWidth = 174
  Color = clBtnFace
  ParentFont = True
  OldCreateOrder = True
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object Bevel1: TBevel
    Left = 8
    Top = 8
    Width = 159
    Height = 70
    Shape = bsFrame
  end
  object Label1: TLabel
    Left = 32
    Top = 34
    Width = 38
    Height = 13
    Caption = 'Feet +/-'
  end
  object OKBtn: TButton
    Left = 9
    Top = 90
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 0
    OnClick = OKBtnClick
  end
  object CancelBtn: TButton
    Left = 89
    Top = 90
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 1
  end
  object Edit1: TEdit
    Left = 81
    Top = 31
    Width = 50
    Height = 21
    TabOrder = 2
    Text = '0'
  end
end
