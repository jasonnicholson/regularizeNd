# VBA Port — Testing Guide

## How to run the tests

VBA has no command-line test runner, so tests must be executed interactively inside Excel's VBA IDE.

### Steps

1. Open Excel.
2. Press **Alt + F11** to open the Visual Basic Editor.
3. In the Project Explorer, import both modules into your workbook's VBA project:
   - `RegularizeNd.bas`
   - `TestRegularizeNd.bas`
4. Open the **Immediate Window** with **Ctrl + G**.
5. Type and press Enter:
   ```
   Call RunAllTestsDirect
   ```
6. Results are printed to the Immediate Window:
   ```
   ============================================================
   Running RegularizeNd VBA Tests
   ============================================================
     PASS  Test_1D_OutputSize
     PASS  Test_1D_FiniteOutput
     ...
   ------------------------------------------------------------
   Passed: 5   Failed: 0
   ============================================================
   ```

Each failing test prints the failing assertion message so you can diagnose the
issue immediately.

---

## Automated / CI testing options

Because VBA is embedded in Microsoft Office, there is no native CLI runner.
However, the following approaches enable automated testing:

| Approach | Platform | Notes |
|---|---|---|
| **[RubberduckVBA](https://rubberduckvba.com/)** | Windows | Free, open-source VBIDE add-in. Provides a test explorer, assertion library, and mock framework. The gold standard for VBA testing. |
| **Python + [xlwings](https://www.xlwings.org/)** | Windows | Drive Excel macros from Python (`xw.Book(...).macro('RunAllTestsDirect')(...)`). Works in CI when a licensed Excel is installed. |
| **Python + [pywin32](https://github.com/mhammond/pywin32) / `win32com`** | Windows | Similar to xlwings but lower-level COM automation. No extra dependencies beyond `pywin32`. |
| **[OpenPyXL](https://openpyxl.readthedocs.io/)** | Any | Reads/writes `.xlsx` files without Excel. Cannot execute VBA macros, so not suitable for running these tests. |

### Recommended approach

For a project of this size, **RubberduckVBA** is the recommended path if you
want a proper test framework inside the VBA IDE.  For CI integration on Windows
you can pair it with `xlwings` or `win32com` to drive macro execution
headlessly.

Since this is a Linux environment, the easiest choice is to keep the VBA port
as a **reference implementation** tested manually, and rely on the Python and
Julia ports for automated regression coverage.
