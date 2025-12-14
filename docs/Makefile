# Minimal makefile for Sphinx documentation
#

# You can set these variables from the command line, and also
# from the environment for the first two.
SPHINXOPTS    ?=
SPHINXBUILD   ?= sphinx-build
SPHINXAUTOBUILD ?= sphinx-autobuild
PYTHON        ?= python3
SOURCEDIR     = .
BUILDDIR      = _build
STATICDIR     = $(SOURCEDIR)/_static
EXAMPLESDIR   = $(STATICDIR)/examples

# Put it first so that "make" without argument is like "make help".
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

.PHONY: help Makefile

maybe-examples:
	@# If no generated example HTML exists yet, generate it.
	@# This keeps fresh clones working without requiring a manual `make examples`.
	@if [ ! -d "$(EXAMPLESDIR)" ] || ! find "$(EXAMPLESDIR)" -name '*.html' -print -quit 2>/dev/null | grep -q .; then \
		echo "[make] examples HTML missing; running 'make examples'"; \
		$(MAKE) examples; \
	fi

html: maybe-examples
	@$(SPHINXBUILD) -M html "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

livehtml: maybe-examples
	# Run sphinx-autobuild to watch SOURCEDIR and serve the generated HTML.
	# - SPHINXAUTOBUILD: path to the sphinx-autobuild executable
	# - SOURCEDIR: directory containing Sphinx source files
	# - BUILDDIR: base build directory; the served output is BUILDDIR/html
	# - SPHINXOPTS: extra options forwarded to sphinx-build
	# - O: additional command-line arguments
	# Effect: automatically rebuilds documentation on changes and serves a live-updating site.
	@$(SPHINXAUTOBUILD) "$(SOURCEDIR)" "$(BUILDDIR)/html" $(SPHINXOPTS) --port 8002 --open-browser --watch ../source $(O)

examples:
	@$(PYTHON) ../scripts/publish_examples.py

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
