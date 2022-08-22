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
import ballerina/test;

@test:Config {
    groups: ["api"]
}
function testReadTOMLString() returns error? {
    map<json> output = check readString(string
        `bool = true
        int = 1
        float = 1.1
        arr = [1,2]
        obj = {str = "text"}

        [[date]]
        ld = 2022-06-02

        [[date]]
        ld = 2022-06-03

        [date.time]
        lt = 07:30:12`);

    test:assertEquals(output, {
        "bool": true,
        "int": 1,
        "float": <decimal>1.1,
        "arr": [1, 2],
        "obj": {
            "str": "text"
        },
        "date": [
            {"ld": "2022-06-02"},
            {
                "ld": "2022-06-03",
                "time": {
                    "lt": "07:30:12"
                }
            }
        ]
    });
}

@test:Config {
    groups: ["api"]
}
function testReadTOMLFile() returns error? {
    check io:fileWriteString("input.toml", "bool = true\n int = 1");
    map<json> output = check readFile("input.toml");
    test:assertEquals(output, {"bool": true, "int": 1});
    check file:remove("input.toml");
}

@test:Config {
    groups: ["api"]
}
function testWriteTOMLString() returns error? {
    string[] output = check writeString({"key": "value"});
    test:assertEquals(output[0], "key = \"value\"");
}

@test:Config {
    groups: ["api"]
}
function testWriteTOMLFile() returns error? {
    check writeFile("output.toml", {"outer": {"inner": "value"}}, allowDottedKeys = false, indentationPolicy = 4);
    string[] output = check io:fileReadLines("output.toml");
    test:assertEquals(output, ["[outer]", "inner = \"value\""]);
    check file:remove("output.toml");
}

@test:Config {}
function testInvalidAttemptWriteToDirectory() returns error? {
    check file:createDir("output");
    FileError? err = openFile("output");
    test:assertTrue(err is FileError);
    check file:remove("output");
}
