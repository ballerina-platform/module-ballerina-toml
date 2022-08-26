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

# Configurations for writing a TOML document.
#
# + indentationPolicy - Number of spaces for an indentation
# + allowDottedKeys - If set, dotted keys are used instead of standard tables where applicable.
public type WriteConfig record {|
    int indentationPolicy = 2;
    boolean allowDottedKeys = true;
|};

# Configurations for reading a TOML document.
#
# + parseOffsetDateTime - If set, then offset date time is converted to Ballerina time:Utc
public type ReadConfig record {|
    boolean parseOffsetDateTime = true;
|};
