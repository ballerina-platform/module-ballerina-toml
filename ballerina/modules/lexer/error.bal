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

# Represents an error caused by the lexical analyzer.
public type LexicalError distinct error<ReadErrorDetails>;

# Represents the error details when reading a TOML document.
#
# + line - Line at which the error occurred  
# + column - Column at which the error occurred  
# + actual - The actual violated yaml string  
# + expected - Expected yaml strings for the violated string  
# + context - Context in which the error occurred
public type ReadErrorDetails record {|
    int line;
    int column;
    json actual;
    json? expected = ();
    string? context = ();
|};

# Generate an error message based on the template,
# "Invalid character '${char}' for a '${token}'"
#
# + state - Current lexer state  
# + context - Context of the lexeme being scanned
# + return - Generated error message
isolated function generateInvalidCharacterError(LexerState state, string context) returns LexicalError {
    string? currentChar = state.peek();
    string message = string `Invalid character '${currentChar ?: "<end-of-line>"}' for a '${context}'`;
    return error(
        message,
        line = state.row(),
        column = state.column(),
        actual = currentChar,
        context = context
    );
}

isolated function generateLexicalError(LexerState state, string message) returns LexicalError =>
    error(
        message + ".",
        line = state.row(),
        column = state.column(),
        actual = state.peek()
    );
