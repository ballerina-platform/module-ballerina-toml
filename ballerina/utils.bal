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

# Checks if the file exists. If not, creates a new file.
#
# + fileName - Path to the file
# + return - An error on failure
isolated function openFile(string fileName) returns FileError? {
    // Check if the given fileName is not directory
    if check file:test(fileName, file:IS_DIR) {
        return error("Cannot write to a directory");
    }

    // Create the file if the file does not exists
    if !check file:test(fileName, file:EXISTS) {
        check file:create(fileName);
    }
}
