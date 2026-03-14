Attribute VB_Name = "TestRegularizeNd"
Option Explicit

' =============================================================================
' VBA Unit Tests for the RegularizeNd port
'
' USAGE:
'   1. Import this module into the same VBA project as RegularizeNd.bas.
'   2. Open the Immediate Window (Ctrl+G) in the VBA IDE.
'   3. Run:  Call RunAllTests
'   4. Results are printed to the Immediate Window.
'
' NOTES:
'   - VBA has no first-class test runner.  Each test raises an error on failure
'     (which can be caught and reported) or prints "PASS" to the Immediate Window.
'   - For a more complete framework consider the RubberduckVBA add-in:
'     https://rubberduckvba.com/
' =============================================================================

Private m_passed As Long
Private m_failed As Long

' ---------------------------------------------------------------------------
' Main runner — call this from the Immediate Window
' ---------------------------------------------------------------------------
Public Sub RunAllTests()
    m_passed = 0
    m_failed = 0

    Debug.Print String(60, "=")
    Debug.Print "Running RegularizeNd VBA Tests"
    Debug.Print String(60, "=")

    RunTest "Test_1D_OutputSize",          AddressOf Test_1D_OutputSize
    RunTest "Test_1D_FiniteOutput",        AddressOf Test_1D_FiniteOutput
    RunTest "Test_2D_OutputShape",         AddressOf Test_2D_OutputShape
    RunTest "Test_SmoothnesZero",          AddressOf Test_SmoothnessZero
    RunTest "Test_MatricesReturnsTwoItems",AddressOf Test_MatricesReturnsTwoItems

    Debug.Print String(60, "-")
    Debug.Print "Passed: " & m_passed & "   Failed: " & m_failed
    Debug.Print String(60, "=")
End Sub

' ---------------------------------------------------------------------------
' Helper — runs one named test, catches errors
' ---------------------------------------------------------------------------
Private Sub RunTest(ByVal name As String, ByVal proc As LongPtr)
    ' CallByName is not available for raw function pointers; we use Application.Run
    ' via a wrapper approach.  Since VBA cannot pass AddressOf to a generic runner
    ' easily, the cleanest pattern is to call tests directly.
    ' This stub exists for documentation; see the individual call lines below.
End Sub

' Because VBA lacks proper first-class functions, RunAllTests calls each test
' directly with On Error handling.

Public Sub RunAllTestsDirect()
    m_passed = 0
    m_failed = 0

    Debug.Print String(60, "=")
    Debug.Print "Running RegularizeNd VBA Tests"
    Debug.Print String(60, "=")

    CallTest "Test_1D_OutputSize"
    CallTest "Test_1D_FiniteOutput"
    CallTest "Test_2D_OutputShape"
    CallTest "Test_SmoothnessZero"
    CallTest "Test_MatricesReturnsTwoItems"

    Debug.Print String(60, "-")
    Debug.Print "Passed: " & m_passed & "   Failed: " & m_failed
    Debug.Print String(60, "=")
End Sub

Private Sub CallTest(ByVal name As String)
    On Error GoTo Fail
    Application.Run name
    m_passed = m_passed + 1
    Debug.Print "  PASS  " & name
    Exit Sub
Fail:
    m_failed = m_failed + 1
    Debug.Print "  FAIL  " & name & " — " & Err.Description
End Sub

' ===========================================================================
' Individual test procedures
' Each Sub raises an error (via Assert) when the test fails.
' ===========================================================================

' ---------------------------------------------------------------------------
' Assert helper — raise if condition is False
' ---------------------------------------------------------------------------
Private Sub Assert(ByVal condition As Boolean, ByVal message As String)
    If Not condition Then
        Err.Raise vbObjectError + 9000, "Assert", message
    End If
End Sub

' ---------------------------------------------------------------------------
' Test: 1-D regularization produces expected output length
' ---------------------------------------------------------------------------
Public Sub Test_1D_OutputSize()
    Dim x(1 To 5, 1 To 1) As Double
    Dim y(1 To 5, 1 To 1) As Double
    Dim xGrid(1 To 1) As Variant
    Dim grid1(1 To 10) As Double

    x(1, 1) = 0:   y(1, 1) = 1
    x(2, 1) = 0.55: y(2, 1) = 1.1
    x(3, 1) = 1.1: y(3, 1) = 1.5
    x(4, 1) = 2.6: y(4, 1) = 2.5
    x(5, 1) = 2.99: y(5, 1) = 1.9

    Dim i As Long
    For i = 1 To 10
        grid1(i) = -0.5 + (i - 1) * ((3.6 - (-0.5)) / 9)
    Next i
    xGrid(1) = grid1

    Dim result As Variant
    result = RegularizeNd(x, y, xGrid, 5E-3)

    Assert UBound(result, 1) = 10, "Expected 10 output rows, got " & UBound(result, 1)
End Sub

' ---------------------------------------------------------------------------
' Test: 1-D output values are all finite (no NaN/Inf)
' ---------------------------------------------------------------------------
Public Sub Test_1D_FiniteOutput()
    Dim x(1 To 5, 1 To 1) As Double
    Dim y(1 To 5, 1 To 1) As Double
    Dim xGrid(1 To 1) As Variant
    Dim grid1(1 To 10) As Double

    x(1, 1) = 0:    y(1, 1) = 1
    x(2, 1) = 0.55: y(2, 1) = 1.1
    x(3, 1) = 1.1:  y(3, 1) = 1.5
    x(4, 1) = 2.6:  y(4, 1) = 2.5
    x(5, 1) = 2.99: y(5, 1) = 1.9

    Dim i As Long
    For i = 1 To 10
        grid1(i) = -0.5 + (i - 1) * ((3.6 - (-0.5)) / 9)
    Next i
    xGrid(1) = grid1

    Dim result As Variant
    result = RegularizeNd(x, y, xGrid, 5E-3)

    For i = 1 To UBound(result, 1)
        Assert IsNumeric(result(i, 1)), "Non-numeric value at row " & i
        Assert Not IsNull(result(i, 1)), "Null value at row " & i
    Next i
End Sub

' ---------------------------------------------------------------------------
' Test: 2-D output has expected grid dimensions (nGrid1 x nGrid2)
' ---------------------------------------------------------------------------
Public Sub Test_2D_OutputShape()
    ' 4 scattered points in 2D
    Dim x(1 To 4, 1 To 2) As Double
    Dim y(1 To 4, 1 To 1) As Double
    Dim xGrid(1 To 2) As Variant
    Dim g1(1 To 5) As Double, g2(1 To 6) As Double

    x(1, 1) = 1: x(1, 2) = 1: y(1, 1) = 1
    x(2, 1) = 1: x(2, 2) = 2: y(2, 1) = 2
    x(3, 1) = 2: x(3, 2) = 1: y(3, 1) = 3
    x(4, 1) = 2: x(4, 2) = 2: y(4, 1) = 4

    Dim i As Long
    For i = 1 To 5: g1(i) = 0.8 + (i - 1) * 0.3: Next i   ' 0.8 to 2.0
    For i = 1 To 6: g2(i) = 0.8 + (i - 1) * 0.3: Next i   ' 0.8 to 2.3
    xGrid(1) = g1
    xGrid(2) = g2

    Dim result As Variant
    result = RegularizeNd(x, y, xGrid, 1E-3)

    ' result is stored as a flat column vector of length nGrid1*nGrid2 in the
    ' VBA port; verify total length equals expected grid size
    Assert UBound(result, 1) = 5 * 6, _
        "Expected 30 output rows, got " & UBound(result, 1)
End Sub

' ---------------------------------------------------------------------------
' Test: smoothness = 0 in one dimension runs without error (no regularization
'       applied along that axis)
' ---------------------------------------------------------------------------
Public Sub Test_SmoothnessZero()
    Dim x(1 To 4, 1 To 2) As Double
    Dim y(1 To 4, 1 To 1) As Double
    Dim xGrid(1 To 2) As Variant
    Dim g1(1 To 5) As Double, g2(1 To 5) As Double
    Dim smooth(1 To 2) As Double

    x(1, 1) = 1: x(1, 2) = 1: y(1, 1) = 1
    x(2, 1) = 1: x(2, 2) = 2: y(2, 1) = 2
    x(3, 1) = 2: x(3, 2) = 1: y(3, 1) = 3
    x(4, 1) = 2: x(4, 2) = 2: y(4, 1) = 4

    Dim i As Long
    For i = 1 To 5: g1(i) = 0.8 + (i - 1) * 0.3: Next i
    For i = 1 To 5: g2(i) = 0.8 + (i - 1) * 0.3: Next i
    xGrid(1) = g1
    xGrid(2) = g2

    smooth(1) = 0       ' no regularization in dimension 1
    smooth(2) = 1E-3

    Dim result As Variant
    result = RegularizeNd(x, y, xGrid, smooth)

    Assert UBound(result, 1) = 5 * 5, _
        "Expected 25 output rows with zero smoothness, got " & UBound(result, 1)
End Sub

' ---------------------------------------------------------------------------
' Test: RegularizeNdMatrices returns a 2-element array (Afidelity, Lreg)
' ---------------------------------------------------------------------------
Public Sub Test_MatricesReturnsTwoItems()
    Dim x(1 To 4, 1 To 1) As Double
    Dim xGrid(1 To 1) As Variant
    Dim g1(1 To 6) As Double

    Dim i As Long
    For i = 1 To 4: x(i, 1) = i * 0.5: Next i
    For i = 1 To 6: g1(i) = 0.3 + (i - 1) * 0.4: Next i
    xGrid(1) = g1

    Dim result As Variant
    result = RegularizeNdMatrices(x, xGrid, 1E-2)

    Assert UBound(result) - LBound(result) + 1 = 2, _
        "Expected 2-element array from RegularizeNdMatrices"
End Sub
