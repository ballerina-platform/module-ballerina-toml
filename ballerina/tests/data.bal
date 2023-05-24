// Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ballerina/file;
import ballerina/io;

function validTomlDataGen() returns map<[string, json]>|error {
    file:MetaData[] data = check file:readDir("tests/resources/valid/in");
    map<[string, json]> testMetaData = {};

    foreach file:MetaData item in data {
        file:MetaData[] testFiles = check file:readDir(item.absPath);
        foreach file:MetaData testFile in testFiles {
            string relativePath = check getRelativePath(testFile.absPath);
            string replacedDir = re`in`.replace(relativePath, "out");
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
            string testCaseName = relativePath.substring(<int>relativePath.indexOf("invalid") + 8, relativePath.length() - 5);
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
