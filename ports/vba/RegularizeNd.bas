Attribute VB_Name = "RegularizeNd"
Option Explicit

' VGA/VBA equivalent of:
' - regularizeNd.m
' - regularizeNdMatrices.m
' - monotonicConstraint.m
'
' Notes:
' 1) VBA has no native sparse matrix type, so this implementation uses dense Variant(Double) matrices.
' 2) For large grids, this is intended as a reference implementation, not a high-performance solver.

Public Function RegularizeNdMatrices( _
    ByVal x As Variant, _
    ByVal xGrid As Variant, _
    Optional ByVal smoothness As Variant, _
    Optional ByVal interpMethod As String = "linear" _
) As Variant

    Dim nScattered As Long, nDimensions As Long
    Dim nGrid() As Long, nTotalGridPoints As Long
    Dim smooth() As Double
    Dim Afidelity As Variant
    Dim Lreg As Collection

    nScattered = UBound(x, 1)
    nDimensions = UBound(x, 2)

    If UBound(xGrid) <> nDimensions Then
        Err.Raise vbObjectError + 1001, "RegularizeNdMatrices", "Dimension mismatch between x and xGrid"
    End If

    ReDim nGrid(1 To nDimensions)
    Dim d As Long
    nTotalGridPoints = 1
    For d = 1 To nDimensions
        nGrid(d) = UBound(xGrid(d)) - LBound(xGrid(d)) + 1
        nTotalGridPoints = nTotalGridPoints * nGrid(d)
    Next d

    smooth = NormalizeSmoothness(smoothness, nDimensions)

    ValidateInputs x, xGrid, interpMethod, nGrid

    Afidelity = BuildFidelityMatrix(x, xGrid, nGrid, nScattered, nDimensions, nTotalGridPoints, interpMethod)
    Set Lreg = BuildRegularizationMatrices(x, xGrid, nGrid, smooth, nScattered, nDimensions, nTotalGridPoints)

    RegularizeNdMatrices = Array(Afidelity, Lreg)
End Function

Public Function RegularizeNd( _
    ByVal x As Variant, _
    ByVal y As Variant, _
    ByVal xGrid As Variant, _
    Optional ByVal smoothness As Variant, _
    Optional ByVal interpMethod As String = "linear", _
    Optional ByVal solver As String = "normal" _
) As Variant

    Dim mats As Variant
    Dim Afidelity As Variant
    Dim Lreg As Collection
    Dim A As Variant
    Dim rhs As Variant
    Dim nSmooth As Long
    Dim yGrid As Variant

    mats = RegularizeNdMatrices(x, xGrid, smoothness, interpMethod)
    Afidelity = mats(0)
    Set Lreg = mats(1)

    nSmooth = CountRowsInCollection(Lreg)
    A = VCatDense(Afidelity, Lreg)
    rhs = BuildRhs(y, nSmooth)

    Select Case solver
        Case "\\"
            yGrid = SolveLinearSystem(A, rhs)
        Case "normal"
            Dim At As Variant, AtA As Variant, Aty As Variant
            At = TransposeDense(A)
            AtA = MatMul(At, A)
            Aty = MatVecMul(At, rhs)
            yGrid = SolveLinearSystem(AtA, Aty)
        Case Else
            Err.Raise vbObjectError + 1002, "RegularizeNd", "Only '\\' and 'normal' are implemented in VBA port"
    End Select

    RegularizeNd = ReshapeNdGrid(yGrid, xGrid)
End Function

Public Function MonotonicConstraint( _
    ByVal xGrid As Variant, _
    Optional ByVal dimension As Long = 1, _
    Optional ByVal dxMin As Double = 0# _
) As Variant

    Dim subGrid1 As Variant, subGrid2 As Variant
    Dim A1 As Variant, A2 As Variant, A As Variant
    Dim b() As Double
    Dim i As Long, nRows As Long

    subGrid1 = CopyGrid(xGrid)
    subGrid2 = CopyGrid(xGrid)

    subGrid1(dimension) = SliceVector(xGrid(dimension), 1, UBound(xGrid(dimension)) - 1)
    subGrid2(dimension) = SliceVector(xGrid(dimension), 2, UBound(xGrid(dimension)))

    A1 = MonotonicHelper(subGrid1, xGrid)
    A2 = MonotonicHelper(subGrid2, xGrid)
    A = MatSub(A1, A2)

    nRows = UBound(A, 1)
    ReDim b(1 To nRows)
    For i = 1 To nRows
        b(i) = -dxMin
    Next i

    MonotonicConstraint = Array(A, b)
End Function

Private Function MonotonicHelper(ByVal subGrid As Variant, ByVal fullGrid As Variant) As Variant
    Dim pts As Variant
    pts = CartesianProductPoints(subGrid)

    Dim mats As Variant
    mats = RegularizeNdMatrices(pts, fullGrid, 0#, "linear")
    MonotonicHelper = mats(0)
End Function

Private Function BuildFidelityMatrix( _
    ByVal x As Variant, _
    ByVal xGrid As Variant, _
    ByVal nGrid() As Long, _
    ByVal nScattered As Long, _
    ByVal nDimensions As Long, _
    ByVal nTotalGridPoints As Long, _
    ByVal interpMethod As String _
) As Variant

    Dim A() As Double
    ReDim A(1 To nScattered, 1 To nTotalGridPoints)

    Dim r As Long, d As Long, idx As Long
    Dim baseIdx() As Long
    Dim frac() As Double

    ReDim baseIdx(1 To nDimensions)
    ReDim frac(1 To nDimensions)

    Select Case LCase$(interpMethod)
        Case "nearest"
            For r = 1 To nScattered
                For d = 1 To nDimensions
                    idx = FindCellIndex(x(r, d), xGrid(d))
                    frac(d) = (x(r, d) - xGrid(d)(idx)) / (xGrid(d)(idx + 1) - xGrid(d)(idx))
                    If frac(d) < 0# Then frac(d) = 0#
                    If frac(d) > 1# Then frac(d) = 1#
                    baseIdx(d) = idx + CLng(Round(frac(d), 0))
                Next d

                A(r, SubscriptToIndex(baseIdx, nGrid)) = 1#
            Next r

        Case "linear"
            BuildLinearFidelity x, xGrid, nGrid, A, nScattered, nDimensions

        Case "cubic"
            BuildCubicFidelity x, xGrid, nGrid, A, nScattered, nDimensions

        Case Else
            Err.Raise vbObjectError + 1003, "BuildFidelityMatrix", "Unsupported interpMethod"
    End Select

    BuildFidelityMatrix = A
End Function

Private Sub BuildLinearFidelity( _
    ByVal x As Variant, _
    ByVal xGrid As Variant, _
    ByVal nGrid() As Long, _
    ByRef A As Variant, _
    ByVal nScattered As Long, _
    ByVal nDimensions As Long _
)
    Dim nodes As Variant
    nodes = BinaryNodeTable(nDimensions)

    Dim r As Long, d As Long, n As Long
    Dim idx0() As Long
    Dim frac() As Double
    Dim subs() As Long
    Dim w As Double

    ReDim idx0(1 To nDimensions)
    ReDim frac(1 To nDimensions)
    ReDim subs(1 To nDimensions)

    For r = 1 To nScattered
        For d = 1 To nDimensions
            idx0(d) = FindCellIndex(x(r, d), xGrid(d))
            frac(d) = (x(r, d) - xGrid(d)(idx0(d))) / (xGrid(d)(idx0(d) + 1) - xGrid(d)(idx0(d)))
            If frac(d) < 0# Then frac(d) = 0#
            If frac(d) > 1# Then frac(d) = 1#
        Next d

        For n = 1 To UBound(nodes, 1)
            w = 1#
            For d = 1 To nDimensions
                subs(d) = idx0(d) + nodes(n, d)
                If nodes(n, d) = 0 Then
                    w = w * (1# - frac(d))
                Else
                    w = w * frac(d)
                End If
            Next d
            A(r, SubscriptToIndex(subs, nGrid)) = A(r, SubscriptToIndex(subs, nGrid)) + w
        Next n
    Next r
End Sub

Private Sub BuildCubicFidelity( _
    ByVal x As Variant, _
    ByVal xGrid As Variant, _
    ByVal nGrid() As Long, _
    ByRef A As Variant, _
    ByVal nScattered As Long, _
    ByVal nDimensions As Long _
)
    Dim nodes As Variant
    nodes = QuarticNodeTable(nDimensions)

    Dim r As Long, d As Long, n As Long
    Dim idx0() As Long
    Dim wd() As Variant
    Dim subs() As Long
    Dim w As Double

    ReDim idx0(1 To nDimensions)
    ReDim wd(1 To nDimensions)
    ReDim subs(1 To nDimensions)

    For r = 1 To nScattered
        For d = 1 To nDimensions
            idx0(d) = FindCellIndex(x(r, d), xGrid(d)) - 1
            If idx0(d) < 1 Then idx0(d) = 1
            If idx0(d) > UBound(xGrid(d)) - 3 Then idx0(d) = UBound(xGrid(d)) - 3

            wd(d) = CubicLagrangeWeights(x(r, d), xGrid(d), idx0(d))
        Next d

        For n = 1 To UBound(nodes, 1)
            w = 1#
            For d = 1 To nDimensions
                subs(d) = idx0(d) + nodes(n, d)
                w = w * wd(d)(nodes(n, d) + 1)
            Next d
            A(r, SubscriptToIndex(subs, nGrid)) = A(r, SubscriptToIndex(subs, nGrid)) + w
        Next n
    Next r
End Sub

Private Function BuildRegularizationMatrices( _
    ByVal x As Variant, _
    ByVal xGrid As Variant, _
    ByVal nGrid() As Long, _
    ByVal smooth() As Double, _
    ByVal nScattered As Long, _
    ByVal nDimensions As Long, _
    ByVal nTotalGridPoints As Long _
) As Collection

    Dim out As New Collection
    Dim d As Long

    For d = 1 To nDimensions
        If smooth(d) = 0# Then
            out.Add Empty
        Else
            out.Add BuildLregDimension(xGrid, nGrid, d, smooth(d), nScattered, nDimensions, nTotalGridPoints)
        End If
    Next d

    Set BuildRegularizationMatrices = out
End Function

Private Function BuildLregDimension( _
    ByVal xGrid As Variant, _
    ByVal nGrid() As Long, _
    ByVal dimIdx As Long, _
    ByVal smooth As Double, _
    ByVal nScattered As Long, _
    ByVal nDimensions As Long, _
    ByVal nTotalGridPoints As Long _
) As Variant

    Dim nEqDims() As Long
    ReDim nEqDims(1 To nDimensions)

    Dim d As Long
    For d = 1 To nDimensions
        nEqDims(d) = nGrid(d)
    Next d
    nEqDims(dimIdx) = nEqDims(dimIdx) - 2

    Dim nEq As Long
    nEq = ProductLong(nEqDims)

    Dim L() As Double
    ReDim L(1 To nEq, 1 To nTotalGridPoints)

    Dim combos As Variant
    combos = IndexCombinations(nEqDims)

    Dim xMin As Double, xMax As Double
    xMin = xGrid(dimIdx)(1)
    xMax = xGrid(dimIdx)(UBound(xGrid(dimIdx)))

    Dim axisScale As Double
    axisScale = (xMax - xMin) ^ 2

    Dim smoothScale As Double
    smoothScale = Sqr(nScattered / nEq)

    Dim row As Long
    Dim s1() As Long, s2() As Long, s3() As Long
    Dim w As Variant

    For row = 1 To nEq
        s1 = RowToVector(combos, row)
        s2 = CopyLongVector(s1)
        s3 = CopyLongVector(s1)
        s2(dimIdx) = s2(dimIdx) + 1
        s3(dimIdx) = s3(dimIdx) + 2

        w = SecondDerivativeWeights1D(xGrid(dimIdx), s1(dimIdx))

        L(row, SubscriptToIndex(s1, nGrid)) = smooth * smoothScale * axisScale * w(1)
        L(row, SubscriptToIndex(s2, nGrid)) = smooth * smoothScale * axisScale * w(2)
        L(row, SubscriptToIndex(s3, nGrid)) = smooth * smoothScale * axisScale * w(3)
    Next row

    BuildLregDimension = L
End Function

Private Function NormalizeSmoothness(ByVal smoothness As Variant, ByVal nDimensions As Long) As Double()
    Dim s() As Double
    ReDim s(1 To nDimensions)

    Dim i As Long
    If IsMissing(smoothness) Or IsEmpty(smoothness) Then
        For i = 1 To nDimensions
            s(i) = 0.01
        Next i
    ElseIf IsArray(smoothness) Then
        If (UBound(smoothness) - LBound(smoothness) + 1) <> nDimensions Then
            Err.Raise vbObjectError + 1004, "NormalizeSmoothness", "smoothness array length mismatch"
        End If
        For i = 1 To nDimensions
            s(i) = CDbl(smoothness(i))
        Next i
    Else
        For i = 1 To nDimensions
            s(i) = CDbl(smoothness)
        Next i
    End If

    For i = 1 To nDimensions
        If s(i) < 0# Then Err.Raise vbObjectError + 1005, "NormalizeSmoothness", "smoothness must be nonnegative"
    Next i

    NormalizeSmoothness = s
End Function

Private Sub ValidateInputs(ByVal x As Variant, ByVal xGrid As Variant, ByVal interpMethod As String, ByVal nGrid() As Long)
    Dim d As Long, r As Long
    Dim minLen As Long

    Select Case LCase$(interpMethod)
        Case "cubic": minLen = 4
        Case "nearest", "linear": minLen = 3
        Case Else
            Err.Raise vbObjectError + 1006, "ValidateInputs", "unsupported interpMethod"
    End Select

    For d = 1 To UBound(nGrid)
        If nGrid(d) < minLen Then
            Err.Raise vbObjectError + 1007, "ValidateInputs", "not enough points in xGrid dimension"
        End If

        For r = 2 To UBound(xGrid(d))
            If xGrid(d)(r) <= xGrid(d)(r - 1) Then
                Err.Raise vbObjectError + 1008, "ValidateInputs", "xGrid vectors must be strictly increasing"
            End If
        Next r

        For r = 1 To UBound(x, 1)
            If x(r, d) < xGrid(d)(1) Or x(r, d) > xGrid(d)(UBound(xGrid(d))) Then
                Err.Raise vbObjectError + 1009, "ValidateInputs", "x points must lie within xGrid bounds"
            End If
        Next r
    Next d
End Sub

Private Function BuildRhs(ByVal y As Variant, ByVal nSmooth As Long) As Variant
    Dim n As Long, i As Long
    n = UBound(y) + nSmooth

    Dim out() As Double
    ReDim out(1 To n)

    For i = 1 To UBound(y)
        out(i) = y(i)
    Next i

    BuildRhs = out
End Function

Private Function VCatDense(ByVal A1 As Variant, ByVal mats As Collection) As Variant
    Dim totalRows As Long, nCols As Long
    Dim i As Long, r As Long, c As Long

    totalRows = UBound(A1, 1)
    nCols = UBound(A1, 2)

    For i = 1 To mats.Count
        If Not IsEmpty(mats(i)) Then totalRows = totalRows + UBound(mats(i), 1)
    Next i

    Dim out() As Double
    ReDim out(1 To totalRows, 1 To nCols)

    Dim rowCursor As Long
    rowCursor = 1

    For r = 1 To UBound(A1, 1)
        For c = 1 To nCols
            out(rowCursor, c) = A1(r, c)
        Next c
        rowCursor = rowCursor + 1
    Next r

    For i = 1 To mats.Count
        If Not IsEmpty(mats(i)) Then
            For r = 1 To UBound(mats(i), 1)
                For c = 1 To nCols
                    out(rowCursor, c) = mats(i)(r, c)
                Next c
                rowCursor = rowCursor + 1
            Next r
        End If
    Next i

    VCatDense = out
End Function

Private Function CountRowsInCollection(ByVal mats As Collection) As Long
    Dim i As Long, n As Long
    n = 0
    For i = 1 To mats.Count
        If Not IsEmpty(mats(i)) Then n = n + UBound(mats(i), 1)
    Next i
    CountRowsInCollection = n
End Function

Private Function SolveLinearSystem(ByVal A As Variant, ByVal b As Variant) As Variant
    ' Gaussian elimination with partial pivoting.
    Dim n As Long, i As Long, j As Long, k As Long
    n = UBound(A, 1)
    If UBound(A, 2) <> n Then
        Err.Raise vbObjectError + 1010, "SolveLinearSystem", "A must be square"
    End If

    Dim M() As Double, rhs() As Double
    ReDim M(1 To n, 1 To n)
    ReDim rhs(1 To n)

    For i = 1 To n
        rhs(i) = b(i)
        For j = 1 To n
            M(i, j) = A(i, j)
        Next j
    Next i

    Dim pivot As Long, maxVal As Double, tmp As Double
    For k = 1 To n - 1
        pivot = k
        maxVal = Abs(M(k, k))
        For i = k + 1 To n
            If Abs(M(i, k)) > maxVal Then
                maxVal = Abs(M(i, k))
                pivot = i
            End If
        Next i

        If maxVal = 0# Then Err.Raise vbObjectError + 1011, "SolveLinearSystem", "Singular matrix"

        If pivot <> k Then
            For j = k To n
                tmp = M(k, j): M(k, j) = M(pivot, j): M(pivot, j) = tmp
            Next j
            tmp = rhs(k): rhs(k) = rhs(pivot): rhs(pivot) = tmp
        End If

        For i = k + 1 To n
            tmp = M(i, k) / M(k, k)
            M(i, k) = 0#
            For j = k + 1 To n
                M(i, j) = M(i, j) - tmp * M(k, j)
            Next j
            rhs(i) = rhs(i) - tmp * rhs(k)
        Next i
    Next k

    Dim x() As Double
    ReDim x(1 To n)

    For i = n To 1 Step -1
        tmp = rhs(i)
        For j = i + 1 To n
            tmp = tmp - M(i, j) * x(j)
        Next j
        x(i) = tmp / M(i, i)
    Next i

    SolveLinearSystem = x
End Function

Private Function ReshapeNdGrid(ByVal y As Variant, ByVal xGrid As Variant) As Variant
    ' Returns the vector in this VBA port. In MATLAB this would reshape to ndgrid dimensions.
    ReshapeNdGrid = y
End Function

Private Function FindCellIndex(ByVal value As Double, ByVal grid As Variant) As Long
    Dim i As Long
    If value <= grid(1) Then
        FindCellIndex = 1
        Exit Function
    End If
    For i = 1 To UBound(grid) - 1
        If value >= grid(i) And value <= grid(i + 1) Then
            FindCellIndex = i
            Exit Function
        End If
    Next i
    FindCellIndex = UBound(grid) - 1
End Function

Private Function CubicLagrangeWeights(ByVal x As Double, ByVal grid As Variant, ByVal idx As Long) As Variant
    Dim x1 As Double, x2 As Double, x3 As Double, x4 As Double
    Dim a1 As Double, a2 As Double, a3 As Double, a4 As Double
    Dim b12 As Double, b13 As Double, b14 As Double, b23 As Double, b24 As Double, b34 As Double
    Dim w(1 To 4) As Double

    x1 = grid(idx): x2 = grid(idx + 1): x3 = grid(idx + 2): x4 = grid(idx + 3)
    a1 = x - x1: a2 = x - x2: a3 = x - x3: a4 = x - x4
    b12 = x1 - x2: b13 = x1 - x3: b14 = x1 - x4
    b23 = x2 - x3: b24 = x2 - x4: b34 = x3 - x4

    w(1) = a2 / b12 * a3 / b13 * a4 / b14
    w(2) = -a1 / b12 * a3 / b23 * a4 / b24
    w(3) = a1 / b13 * a2 / b23 * a4 / b34
    w(4) = -a1 / b14 * a2 / b24 * a3 / b34

    CubicLagrangeWeights = w
End Function

Private Function SecondDerivativeWeights1D(ByVal grid As Variant, ByVal i As Long) As Variant
    Dim x1 As Double, x2 As Double, x3 As Double
    Dim w(1 To 3) As Double

    x1 = grid(i)
    x2 = grid(i + 1)
    x3 = grid(i + 2)

    w(1) = 2# / ((x1 - x3) * (x1 - x2))
    w(2) = 2# / ((x2 - x1) * (x2 - x3))
    w(3) = 2# / ((x3 - x1) * (x3 - x2))

    SecondDerivativeWeights1D = w
End Function

Private Function SubscriptToIndex(ByVal subs() As Long, ByVal siz() As Long) As Long
    Dim i As Long, k As Long
    k = subs(1)
    Dim mult As Long
    mult = 1
    For i = 2 To UBound(subs)
        mult = mult * siz(i - 1)
        k = k + (subs(i) - 1) * mult
    Next i
    SubscriptToIndex = k
End Function

Private Function ProductLong(ByVal v() As Long) As Long
    Dim i As Long, p As Long
    p = 1
    For i = 1 To UBound(v)
        p = p * v(i)
    Next i
    ProductLong = p
End Function

Private Function BinaryNodeTable(ByVal nDimensions As Long) As Variant
    Dim nRows As Long, r As Long, d As Long
    nRows = 2 ^ nDimensions

    Dim out() As Long
    ReDim out(1 To nRows, 1 To nDimensions)

    For r = 0 To nRows - 1
        For d = 1 To nDimensions
            out(r + 1, d) = (r \ (2 ^ (nDimensions - d))) Mod 2
        Next d
    Next r

    BinaryNodeTable = out
End Function

Private Function QuarticNodeTable(ByVal nDimensions As Long) As Variant
    Dim nRows As Long, r As Long, d As Long, t As Long
    nRows = 4 ^ nDimensions

    Dim out() As Long
    ReDim out(1 To nRows, 1 To nDimensions)

    For r = 0 To nRows - 1
        t = r
        For d = nDimensions To 1 Step -1
            out(r + 1, d) = t Mod 4
            t = t \ 4
        Next d
    Next r

    QuarticNodeTable = out
End Function

Private Function IndexCombinations(ByVal lengths() As Long) As Variant
    Dim nDims As Long, nRows As Long, d As Long, r As Long
    nDims = UBound(lengths)
    nRows = ProductLong(lengths)

    Dim out() As Long
    ReDim out(1 To nRows, 1 To nDims)

    For r = 0 To nRows - 1
        Dim t As Long
        t = r
        For d = 1 To nDims
            out(r + 1, d) = (t Mod lengths(d)) + 1
            t = t \ lengths(d)
        Next d
    Next r

    IndexCombinations = out
End Function

Private Function RowToVector(ByVal m As Variant, ByVal row As Long) As Long()
    Dim n As Long, i As Long
    n = UBound(m, 2)
    Dim v() As Long
    ReDim v(1 To n)
    For i = 1 To n
        v(i) = m(row, i)
    Next i
    RowToVector = v
End Function

Private Function CopyLongVector(ByVal v() As Long) As Long()
    Dim i As Long
    Dim out() As Long
    ReDim out(1 To UBound(v))
    For i = 1 To UBound(v)
        out(i) = v(i)
    Next i
    CopyLongVector = out
End Function

Private Function CopyGrid(ByVal xGrid As Variant) As Variant
    Dim d As Long
    Dim out() As Variant
    ReDim out(1 To UBound(xGrid))
    For d = 1 To UBound(xGrid)
        out(d) = SliceVector(xGrid(d), 1, UBound(xGrid(d)))
    Next d
    CopyGrid = out
End Function

Private Function SliceVector(ByVal v As Variant, ByVal i1 As Long, ByVal i2 As Long) As Variant
    Dim out() As Double
    Dim i As Long, k As Long
    ReDim out(1 To i2 - i1 + 1)
    k = 1
    For i = i1 To i2
        out(k) = CDbl(v(i))
        k = k + 1
    Next i
    SliceVector = out
End Function

Private Function CartesianProductPoints(ByVal grids As Variant) As Variant
    Dim nDims As Long, lengths() As Long
    nDims = UBound(grids)

    ReDim lengths(1 To nDims)
    Dim d As Long
    For d = 1 To nDims
        lengths(d) = UBound(grids(d))
    Next d

    Dim combos As Variant
    combos = IndexCombinations(lengths)

    Dim nRows As Long
    nRows = UBound(combos, 1)

    Dim X() As Double
    ReDim X(1 To nRows, 1 To nDims)

    Dim r As Long
    For r = 1 To nRows
        For d = 1 To nDims
            X(r, d) = grids(d)(combos(r, d))
        Next d
    Next r

    CartesianProductPoints = X
End Function

Private Function MatMul(ByVal A As Variant, ByVal B As Variant) As Variant
    Dim rA As Long, cA As Long, rB As Long, cB As Long
    rA = UBound(A, 1): cA = UBound(A, 2)
    rB = UBound(B, 1): cB = UBound(B, 2)
    If cA <> rB Then Err.Raise vbObjectError + 1012, "MatMul", "dimension mismatch"

    Dim C() As Double
    ReDim C(1 To rA, 1 To cB)

    Dim i As Long, j As Long, k As Long
    For i = 1 To rA
        For j = 1 To cB
            For k = 1 To cA
                C(i, j) = C(i, j) + A(i, k) * B(k, j)
            Next k
        Next j
    Next i

    MatMul = C
End Function

Private Function MatVecMul(ByVal A As Variant, ByVal x As Variant) As Variant
    Dim rA As Long, cA As Long
    rA = UBound(A, 1): cA = UBound(A, 2)

    Dim b() As Double
    ReDim b(1 To rA)

    Dim i As Long, k As Long
    For i = 1 To rA
        For k = 1 To cA
            b(i) = b(i) + A(i, k) * x(k)
        Next k
    Next i

    MatVecMul = b
End Function

Private Function TransposeDense(ByVal A As Variant) As Variant
    Dim r As Long, c As Long
    Dim out() As Double
    ReDim out(1 To UBound(A, 2), 1 To UBound(A, 1))

    For r = 1 To UBound(A, 1)
        For c = 1 To UBound(A, 2)
            out(c, r) = A(r, c)
        Next c
    Next r

    TransposeDense = out
End Function

Private Function MatSub(ByVal A As Variant, ByVal B As Variant) As Variant
    Dim r As Long, c As Long
    Dim out() As Double
    ReDim out(1 To UBound(A, 1), 1 To UBound(A, 2))

    For r = 1 To UBound(A, 1)
        For c = 1 To UBound(A, 2)
            out(r, c) = A(r, c) - B(r, c)
        Next c
    Next r

    MatSub = out
End Function
