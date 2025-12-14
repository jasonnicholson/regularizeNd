@ECHO OFF

setlocal

pushd %~dp0

REM Command file for Sphinx documentation (Windows).
REM Mirrors the behavior of docs/Makefile.

if "%SPHINXBUILD%" == "" (
	set SPHINXBUILD=sphinx-build
)
if "%SPHINXAUTOBUILD%" == "" (
	set SPHINXAUTOBUILD=sphinx-autobuild
)
if "%PYTHON%" == "" (
	set PYTHON=python
)

set SOURCEDIR=.
set BUILDDIR=_build
set STATICDIR=%SOURCEDIR%\_static
set EXAMPLESDIR=%STATICDIR%\examples

%SPHINXBUILD% >NUL 2>NUL
if errorlevel 9009 (
	echo.
	echo.The 'sphinx-build' command was not found. Make sure you have Sphinx
	echo.installed, then set the SPHINXBUILD environment variable to point
	echo.to the full path of the 'sphinx-build' executable. Alternatively you
	echo.may add the Sphinx directory to PATH.
	echo.
	echo.If you don't have Sphinx installed, grab it from
	echo.https://www.sphinx-doc.org/
	exit /b 1
)

if "%1" == "" goto help

if "%1" == "help" goto help
if "%1" == "examples" goto examples
if "%1" == "maybe-examples" goto maybe_examples
if "%1" == "html" goto html
if "%1" == "livehtml" goto livehtml

REM Default: forward to sphinx-build "make mode".
%SPHINXBUILD% -M %1 %SOURCEDIR% %BUILDDIR% %SPHINXOPTS% %O%
goto end

:maybe_examples
	REM If no generated example HTML exists yet, generate it.
	set FOUND_HTML=
	if exist "%EXAMPLESDIR%" (
		for /f %%F in ('dir /b /s "%EXAMPLESDIR%\*.html" 2^>nul') do (
			set FOUND_HTML=1
			goto maybe_examples_done
		)
	)
	:maybe_examples_done
	if "%FOUND_HTML%" == "" (
		echo [make] examples HTML missing; running 'examples'
		call "%~f0" examples
		if errorlevel 1 exit /b %errorlevel%
	)
	exit /b 0

:examples
	%PYTHON% ..\scripts\publish_examples.py
	if errorlevel 1 exit /b %errorlevel%
	goto end

:html
	call "%~f0" maybe-examples
	if errorlevel 1 exit /b %errorlevel%
	%SPHINXBUILD% -M html %SOURCEDIR% %BUILDDIR% %SPHINXOPTS% %O%
	goto end

:livehtml
	call "%~f0" maybe-examples
	if errorlevel 1 exit /b %errorlevel%
	%SPHINXAUTOBUILD% "%SOURCEDIR%" "%BUILDDIR%\html" %SPHINXOPTS% --port 8002 --open-browser --watch ..\source %O%
	goto end

:help
%SPHINXBUILD% -M help %SOURCEDIR% %BUILDDIR% %SPHINXOPTS% %O%
echo.
echo.Custom targets:
echo.  examples        Export MATLAB Examples/ to %EXAMPLESDIR%
echo.  maybe-examples  Run examples if HTML not present
echo.  livehtml        Like Makefile livehtml (auto-build + serve)

:end
popd
endlocal
