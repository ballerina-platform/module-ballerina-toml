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
import ballerina/file;

import toml.lexer;
import toml.parser;
import toml.writer;

# Represents the generic error type for the TOML package.
public type Error ParsingError|WritingError|FileError;

// Level 1
# Represents an error caused when failed to access the file.
public type FileError distinct (io:Error|file:Error);

# Represents an error caused during the parsing.
public type ParsingError parser:ParsingError;

# Represents an error caused when writing a TOML file.
public type WritingError writer:WritingError;

// Level 2
# Represents an error caused by the lexical analyzer.
public type LexicalError lexer:LexicalError;

# Represents an error caused for an invalid grammar production.
public type GrammarError parser:GrammarError;

# Represents an error caused by the Ballerina lang when converting a data type.
public type ConversionError parser:ConversionError;
