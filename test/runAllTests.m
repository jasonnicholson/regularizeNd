clc; clear; close all;

import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageResult

here = fileparts(mfilename("fullpath"));
sourceFolder = fullfile(here, "..", "source");
reportFolder = fullfile(here, "coverage");
addpath(sourceFolder, "-begin");

runner = testrunner("textoutput");
coverageCollector = CoverageResult;
coveragePlugin = CodeCoveragePlugin.forFolder(sourceFolder, Producing=coverageCollector, IncludingSubfolders=false);
addPlugin(runner, coveragePlugin);

suite = testsuite(here, IncludeSubfolders=false);
results = run(runner, suite);

disp(results);

generateHTMLReport(coverageCollector.Result, reportFolder);
disp("Coverage report generated at: " + reportFolder);

% Copyright (c) 2016-2026 Jason Nicholson
% Licensed under the MIT License
% See LICENSE file in project root