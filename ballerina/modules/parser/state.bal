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

import toml.lexer;

# Represents the current state of the parser
class ParserState {
    # Properties for the TOML lines
    string[] lines;
    readonly & int numLines;
    int lineIndex = -1;

    # Current token
    lexer:Token currentToken = {token: lexer:DUMMY};

    # Output TOML object
    map<json> tomlObject = {};

    # Current map structure the parser is working on
    map<json> currentStructure = {};

    # Key stack to the current structure
    string[] keyStack = [];

    # Already defined table keys
    string[] definedTableKeys = [];

    # Already defined array table keys
    string[] definedArrayTableKeys = [];

    # Already defined inline table keys
    string[] definedInlineTables = [];

    # Keys defined specific for the current array table.
    string[] tempTableKeys = [];

    # If the token for a next grammar rule has been buffered to the current token.
    boolean tokenConsumed = false;

    # Buffers the key in the full format
    string bufferedKey = "";

    # If set, the parser is currently working on an array table
    boolean isArrayTable = false;

    # The current table key name. If empty, then current table is the root.
    string currentTableKey = "";

    readonly & boolean parseOffsetDateTime;

    lexer:LexerState lexerState = new ();

    isolated function init(string[] inputLines, boolean parseOffsetDateTime) {
        self.lines = inputLines;
        self.numLines = inputLines.length();
        self.parseOffsetDateTime = parseOffsetDateTime;
    }

    isolated function updateLexerContext(lexer:Context context) {
        self.lexerState.context = context;
    }

    # Initialize the lexer with the attributes of a new line.
    #
    # + err - Error to be returned on failure
    # + return - An error if it fails to initialize  
    isolated function initLexer(GrammarError err) returns ParsingError? {
        self.lineIndex += 1;
        if self.lineIndex >= self.numLines {
            return err;
        }
        string line = self.lines[self.lineIndex];
        self.lexerState.setLine(line, self.lineIndex);
    }

    # Add a table key to the respective array if possible.
    #
    # + tableKey - Table key to be added.
    isolated function addTableKey(string tableKey) {
        // Array table keys are maintained separately
        if self.isArrayTable {
            if self.definedArrayTableKeys.indexOf(tableKey) == () {
                self.definedArrayTableKeys.push(tableKey);
            }
            return;
        }

        // Check if the standard table key is an extension of array table.
        // If it is, then added to a temp array that is only valid for that array table.
        foreach string arrayTableKey in self.definedArrayTableKeys {
            if arrayTableKey == tableKey
                || tableKey.startsWith(arrayTableKey) && tableKey[arrayTableKey.length()] == "." {
                self.tempTableKeys.push(tableKey);
                return;
            }
        }

        // A regular standard key is persistent throughout the document.
        if tableKey.length() != 0 {
            self.definedTableKeys.push(tableKey);
        }
    }

    # The current key is added to the table keys, so it cannot be redefined.
    isolated function reserveKey() {
        if !self.isArrayTable {
            self.addTableKey(self.currentTableKey.length() == 0 ? self.bufferedKey : self.currentTableKey + "." + self.bufferedKey);
            self.bufferedKey = "";
        }
    }
}
