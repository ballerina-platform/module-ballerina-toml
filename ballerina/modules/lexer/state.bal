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

public class LexerState {
    # Properties to represent current position 
    public int index = 0;
    public int lineNumber = 0;

    # Line to be lexically analyzed
    public string line = "";

    # Value of the generated token
    string lexeme = "";

    # Current context of the Lexer
    public Context context = EXPRESSION_KEY;

    # Output TOML token
    TOMLToken token = DUMMY;

    public isolated function row() returns int => self.lineNumber + 1;

    public isolated function column() returns int => self.index + 1;

    isolated function appendToLexeme(string appendLine) {
        self.lexeme += appendLine;
    }

    isolated function currentChar() returns string:Char => self.line[self.index];

    public isolated function setLine(string line, int lineNumber) {
        self.index = 0;
        self.line = line;
        self.lineNumber = lineNumber;
    }

    # Increment the index of the column by k indexes
    #
    # + k - Number of indexes to forward. Default = 1
    isolated function forward(int k = 1) {
        if self.index + k <= self.line.length() {
            self.index += k;
        }
    }

    # Peeks the character succeeding after k indexes. 
    # Returns the character after k spots.
    #
    # + k - Number of characters to peek. Default = 0
    # + return - Character at the peek if not null  
    isolated function peek(int k = 0) returns string?
        => self.index + k < self.line.length() ? self.line[self.index + k] : ();

    # Add the output TOML token to the current state
    #
    # + token - TOML token
    # + return - Generated lexical token  
    isolated function tokenize(TOMLToken token) returns LexerState {
        self.forward();
        self.token = token;
        return self;
    }

    # Obtain the lexer token
    #
    # + return - Lexer token
    public isolated function getToken() returns Token {
        TOMLToken tokenBuffer = self.token;
        self.token = DUMMY;
        string lexemeBuffer = self.lexeme;
        self.lexeme = "";
        return {
            token: tokenBuffer,
            value: lexemeBuffer
        };
    }

    # Check if the current character is a new line. 
    # This should be replaced by the os module once it supports an API: #4931.
    # 
    # + char - character to be checked
    # + return - True if the current character is a new line
    public isolated function isNewLine(string? char) returns boolean => char == "\n" || char == "\r\n";
}
