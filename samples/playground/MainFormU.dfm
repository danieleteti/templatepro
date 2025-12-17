object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'TemplatePro Sample - Copyright 2017-2025 Daniele Teti'
  ClientHeight = 515
  ClientWidth = 967
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -19
  Font.Name = 'Tahoma'
  Font.Style = []
  OnCreate = FormCreate
  TextHeight = 23
  object Splitter2: TSplitter
    Left = 303
    Top = 57
    Height = 458
    ExplicitLeft = 336
    ExplicitTop = 192
    ExplicitHeight = 100
  end
  object FileListBox1: TFileListBox
    AlignWithMargins = True
    Left = 3
    Top = 60
    Width = 297
    Height = 452
    Align = alLeft
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -21
    Font.Name = 'Tahoma'
    Font.Style = []
    ItemHeight = 25
    Mask = '*.tpro'
    ParentFont = False
    TabOrder = 0
    OnDblClick = FileListBox1DblClick
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 967
    Height = 57
    Align = alTop
    BevelOuter = bvNone
    Ctl3D = True
    ParentCtl3D = False
    TabOrder = 1
    object btnExecute: TButton
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 199
      Height = 51
      Align = alLeft
      Caption = 'Execute Template'
      TabOrder = 0
      OnClick = btnExecuteClick
    end
    object chkOpenGeneratedFile: TCheckBox
      AlignWithMargins = True
      Left = 235
      Top = 3
      Width = 376
      Height = 51
      Margins.Left = 30
      Align = alLeft
      Caption = 'Open output file in browser'
      TabOrder = 1
    end
  end
  object PageControl1: TPageControl
    Left = 306
    Top = 57
    Width = 661
    Height = 458
    ActivePage = TabSheet2
    Align = alClient
    TabHeight = 40
    TabOrder = 2
    TabWidth = 170
    object TabSheet2: TTabSheet
      Caption = 'TemplatePro Code'
      ImageIndex = 1
      object MemoTemplate: TMemo
        Left = 0
        Top = 0
        Width = 653
        Height = 344
        Align = alClient
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = 22
        Font.Name = 'Courier New'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
        ExplicitHeight = 408
      end
      object Panel2: TPanel
        Left = 0
        Top = 344
        Width = 653
        Height = 64
        Align = alBottom
        Caption = 'Panel2'
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        TabOrder = 1
        object mmErrors: TMemo
          Left = 1
          Top = 1
          Width = 651
          Height = 62
          Align = alClient
          TabOrder = 0
          ExplicitTop = 0
          ExplicitHeight = 40
        end
      end
    end
    object TabSheet1: TTabSheet
      Caption = 'Output'
      object MemoOutput: TMemo
        Left = 0
        Top = 0
        Width = 653
        Height = 408
        Align = alClient
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -16
        Font.Name = 'Courier New'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssBoth
        TabOrder = 0
        WordWrap = False
      end
    end
    object TabSheet3: TTabSheet
      Caption = 'Data'
      ImageIndex = 2
      object Splitter1: TSplitter
        Left = 0
        Top = 153
        Width = 653
        Height = 3
        Cursor = crVSplit
        Align = alTop
        ExplicitTop = 120
        ExplicitWidth = 246
      end
      object DBGrid1: TDBGrid
        Left = 0
        Top = 0
        Width = 653
        Height = 153
        Align = alTop
        DataSource = DataSource1
        TabOrder = 0
        TitleFont.Charset = DEFAULT_CHARSET
        TitleFont.Color = clWindowText
        TitleFont.Height = -19
        TitleFont.Name = 'Tahoma'
        TitleFont.Style = []
      end
      object DBGrid2: TDBGrid
        Left = 0
        Top = 156
        Width = 653
        Height = 252
        Align = alClient
        DataSource = DataSource2
        TabOrder = 1
        TitleFont.Charset = DEFAULT_CHARSET
        TitleFont.Color = clWindowText
        TitleFont.Height = -19
        TitleFont.Name = 'Tahoma'
        TitleFont.Style = []
      end
    end
  end
  object ds1: TFDMemTable
    FetchOptions.AssignedValues = [evMode]
    FetchOptions.Mode = fmAll
    ResourceOptions.AssignedValues = [rvSilentMode]
    ResourceOptions.SilentMode = True
    UpdateOptions.AssignedValues = [uvCheckRequired, uvAutoCommitUpdates]
    UpdateOptions.CheckRequired = False
    UpdateOptions.AutoCommitUpdates = True
    Left = 248
    Top = 120
    object ds1id: TIntegerField
      FieldName = 'id'
    end
    object ds1name: TStringField
      FieldName = 'name'
      Size = 50
    end
    object ds1country: TStringField
      FieldName = 'country'
      Size = 50
    end
  end
  object ds2: TFDMemTable
    IndexFieldNames = 'id_person'
    MasterSource = DataSource1
    MasterFields = 'id'
    DetailFields = 'id_person'
    FetchOptions.AssignedValues = [evMode]
    FetchOptions.Mode = fmAll
    ResourceOptions.AssignedValues = [rvSilentMode]
    ResourceOptions.SilentMode = True
    UpdateOptions.AssignedValues = [uvCheckRequired, uvAutoCommitUpdates]
    UpdateOptions.CheckRequired = False
    UpdateOptions.AutoCommitUpdates = True
    Left = 392
    Top = 120
    object ds2id: TIntegerField
      FieldName = 'id'
    end
    object ds2id_person: TIntegerField
      FieldName = 'id_person'
    end
    object ds2contact: TStringField
      FieldName = 'contact'
      Size = 50
    end
    object ds2contact_type: TStringField
      FieldName = 'contact_type'
      Size = 50
    end
  end
  object DataSource1: TDataSource
    DataSet = ds1
    Left = 312
    Top = 120
  end
  object DataSource2: TDataSource
    DataSet = ds2
    Left = 456
    Top = 120
  end
end
