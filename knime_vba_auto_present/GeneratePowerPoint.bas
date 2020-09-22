Attribute VB_Name = "GeneratePowerPoint"

'Loop Through Folder Gather Information & Enter to Master Excel File for Output



Sub GeneratePowerPoint()
    'File system object for looping through files
    Dim oFSO As Object
    Dim oFolder As Object
    Dim oFile As Object
    Set oFSO = CreateObject("Scripting.FileSystemObject")
    'Main Workbook and Sheet Handlers
    Dim controlWB As Workbook
    Dim datawb As Workbook
    Set controlWB = Workbooks("CreatePowerPoint.xlsm")
    Dim homews As Worksheet
    Set homews = controlWB.Sheets("Home")
    Dim dataws As Worksheet
    
    'Directory to Search Files in
    Dim dir As String
    dir = "ExcelFiles\"
    'Get Folder Contents
    Set oFolder = oFSO.GetFolder(dir)
    'PowerPoint Handlers
    Dim PP As PowerPoint.Application
    Dim PPPres As PowerPoint.Presentation
    Dim PPSlide As PowerPoint.Slide
    Dim SlideTitle As String
    Dim ppSlideCount As Integer
    
    'Step 2:  Open PowerPoint and create new presentation
    Set PP = New PowerPoint.Application
    Set PPPres = PP.Presentations.Add
    PP.Visible = True
    For Each oFile In oFolder.Files 'Hoenstly the best way I could solve this quickly...
      If Left(oFile.Name, 1) <> "~" Then 'dont open backup files
        Dim file_path As String
        file_path = oFile.Path
        Dim last_row_1, last_row_2 As Integer
        ppSlideCount = PPPres.Slides.Count
        Set PPSlide = PPPres.Slides.Add(SlideCount + 1, ppLayoutBlank)
        PPSlide.Select
        PPSlide.Shapes.AddTextbox(msoTextOrientationHorizontal, _
            Left:=100, Top:=25, Width:=200, Height:=50).TextFrame _
            .TextRange.Text = oFile.Name
        Debug.Print file_path
        'Open the Excel File for Chart Creation
        Set datawb = Workbooks.Open(file_path)
        Set dataws = datawb.Sheets("MainData")
        last_row_1 = LastRow(dataws, 2)
        last_row_2 = LastRow(dataws, 3)
        With dataws
            .Shapes.AddChart2(227, xlLine).Select
        End With
        Debug.Print "MainData!A1:B" & LTrim(Str(last_row_1))
        With ActiveChart
            .SetSourceData Source:=Range("MainData!A1:B" & LTrim(Str(last_row_1)))
            .ChartTitle.Text = "Weekly New Customers"
            .HasLegend = False
            .Axes(xlValue).HasTitle = True
            .Axes(xlValue).AxisTitle.Text = "Unique New Purchasers"
            .Axes(xlCategory, xlPrimary).HasTitle = True
            .Axes(xlCategory, xlPrimary).AxisTitle.Characters.Text = "Week Num"
            .Parent.Height = 226 '= 17.24 (7.8*13.99)
            .Parent.Width = 406
            .CopyPicture
        End With
        PPSlide.Shapes.Paste.Select
        PP.ActiveWindow.Selection.ShapeRange.Align msoAlignLefts, True
        PP.ActiveWindow.Selection.ShapeRange.Align msoAlignMiddles, True
        dataws.Shapes.AddChart2(227, xlPie).Select
        With ActiveChart
            .SetSourceData Source:=Range("MainData!C1:D" & LTrim(Str(last_row_2)))
            .ChartTitle.Text = "Purchasers By Country"
            .HasLegend = True
            .CopyPicture
        End With
        PPSlide.Shapes.Paste.Select
        PP.ActiveWindow.Selection.ShapeRange.Align msoAlignRights, True
        PP.ActiveWindow.Selection.ShapeRange.Align msoAlignMiddles, True
        
        datawb.Close False
        
        Set datawb = Nothing
        Set dataws = Nothing
      End If
    Next
    PP.Activate
    If PP.Version >= 9 Then
        PP.Visible = msoCTrue
    End If
    Set PPSlide = Nothing
    Set PPPres = Nothing
    Set PP = Nothing

End Sub



Function LastRow(ws As Worksheet, col As Integer) As Double
    Dim chk As Double
    For i = 2 To 500
        If ws.Cells(i, col) = "" Then
            chk = i
            i = 501
        End If
    Next
    LastRow = chk - 1
End Function
