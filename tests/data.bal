import ballerina/file;
import ballerina/io;
import ballerina/regex;

function validTomlDataGen() returns map<[string, json]>|error {
    file:MetaData[] data = check file:readDir("tests/resources/valid/in");
    map<[string, json]> testMetaData = {};

    foreach file:MetaData item in data {
        file:MetaData[] testFiles = check file:readDir(item.absPath);
        foreach file:MetaData testFile in testFiles {
            string relativePath = check getRelativePath(testFile.absPath);
            string replacedDir = regex:replaceFirst(relativePath, "in", "out");
            string replacedExtension = replacedDir.substring(0, replacedDir.length() - 4) + "json";

            json expectedOutput = check io:fileReadJson(replacedExtension);
            string testCaseName = relativePath.substring(<int>relativePath.indexOf("in") + 3, relativePath.length() - 5);
            testMetaData[testCaseName] = [relativePath, expectedOutput];
        }
    }
    return testMetaData;
}

function invalidTomlDataGen() returns map<[string]>|error {
    file:MetaData[] data = check file:readDir("tests/resources/invalid");
    map<[string]> testMetaData = {};

    foreach file:MetaData item in data {
        file:MetaData[] testFiles = check file:readDir(item.absPath);
        foreach file:MetaData testFile in testFiles {
            string relativePath = check getRelativePath(testFile.absPath);
            string testCaseName = relativePath.substring(<int>relativePath.indexOf("in") + 3, relativePath.length() - 5);
            testMetaData[testCaseName] = [relativePath];
        }
    }
    return testMetaData;
}

function getRelativePath(string absPath) returns string|error {
    int? startInt = absPath.indexOf("tests\\");
    if startInt == () {
        startInt = absPath.indexOf("tests/");
        if startInt == () {
            return error("Invalid file path for integration tests");
        }
    }
    return absPath.substring(<int>startInt);
}
