clc; clear; close all;

import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageResult

runner = testrunner("textoutput");
format = CoverageResult;
COVERAGE_FILES = ["regularizeNd.m", "regularizeNdMatrices.m"];
coverageFiles = string(arrayfun(@which, COVERAGE_FILES,"UniformOutput",false));
plugin = CodeCoveragePlugin.forFile(coverageFiles, Producing=format);
addPlugin(runner,plugin)

TEST_FILES = ["regularizeNdTest.m"];
suite = testsuite(TEST_FILES);

run(runner, suite);

REPORT_FOLDER = "coverage";
generateHTMLReport(format.Result, REPORT_FOLDER);