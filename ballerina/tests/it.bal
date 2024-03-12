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

import ballerina/test;
import ballerina/io;

@test:Config {
    dataProvider: validTomlDataGen
}
function testValidTomlForReadFile(string inputPath, json expectedOutput) returns error? {
    map<json> output = check readFile(inputPath, {parseOffsetDateTime: false});
    test:assertEquals(output, expectedOutput);
}

@test:Config {
    dataProvider: validTomlDataGen
}
function testValidTomlForReadString(string inputPath, json expectedOutput) returns error? {
    map<json> output = check readString(check readStringFromFile(inputPath), {parseOffsetDateTime: false});
    test:assertEquals(output, expectedOutput);
}

@test:Config {
    dataProvider: invalidTomlDataGen
}
function testInvalidTomlForReadFile(string inputPath) {
    map<json>|error output = readFile(inputPath);
    test:assertTrue(output is error);
}

@test:Config {
    dataProvider: invalidTomlDataGen
}
function testInvalidTomlForReadString(string inputPath) returns error? {
    string|error tomlContent = readStringFromFile(inputPath);
    if tomlContent is string {
        map<json>|error output = readString(tomlContent);
        test:assertTrue(output is error);
    }
}

function readStringFromFile(string filePath) returns string|error {
    io:ReadableByteChannel byteChannel = check io:openReadableFile(filePath);
    (byte[] & readonly) readBytes = check byteChannel.readAll();
    return string:fromBytes(readBytes);
}
