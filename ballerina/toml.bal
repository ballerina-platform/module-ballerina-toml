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

import ballerina/io;
import toml.writer;
import toml.parser;

# Parses a Ballerina string of TOML content into a Ballerina map object.
#
# + tomlString - TOML content
# + config - Configuration for reading a TOML file
# + return - TOML map object on success. Else, returns an error
public isolated function readString(string tomlString, *ReadConfig config) returns map<json>|Error {
    io:ReadableByteChannel byteChannel = check io:createReadableChannel(tomlString.toBytes());
    io:ReadableCharacterChannel charChannel = new (byteChannel, io:DEFAULT_ENCODING);
    string[] lines = check charChannel.readAllLines();
    return check parser:parse(lines, config.parseOffsetDateTime);
}

# Parses a TOML file into a Ballerina map object.
#
# + filePath - Path to the toml file
# + config - Configuration for reading a TOML file
# + return - TOML map object on success. Else, returns an error
public isolated function readFile(string filePath, *ReadConfig config) returns map<json>|Error {
    string[] lines = check io:fileReadLines(filePath);
    return check parser:parse(lines, config.parseOffsetDateTime);
}

# Converts the TOML structure to an array of strings.
#
# + tomlStructure - Structure to be written to the file
# + config - Configurations for writing a TOML file
# + return - TOML content on success. Else, an error on failure
public isolated function writeString(map<json> tomlStructure, *WriteConfig config) returns string[]|Error
    => writer:write(tomlStructure, config.indentationPolicy, config.allowDottedKeys);

# Writes the TOML structure to a file.
#
# + filePath - Path to the file  
# + tomlStructure - Structure to be written to the file
# + config - Configurations for writing a TOML file
# + return - An error on failure
public isolated function writeFile(string filePath, map<json> tomlStructure, *WriteConfig config) returns Error? {
    check openFile(filePath);
    string[] output = check writeString(tomlStructure, config);
    check io:fileWriteLines(filePath, output);
}
