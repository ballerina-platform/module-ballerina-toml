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

# Executes the provided function on upcoming characters until the terminating character is found.
#
# + state - Current lexer state  
# + process - Function to be executed on each character iteration  
# + successToken - Token to be returned on successful traverse of the characters
# + message - Message to display if the end delimiter is not shown
# + return - Tokenized TOML token on success, Else, an lexical error.
isolated function iterate(LexerState state, isolated function (LexerState) returns boolean|LexicalError process,
                    TOMLToken successToken,
                    string message = "") returns LexerState|LexicalError {

    // Iterate the given line to check the DFA
    while state.index < state.line.length() {
        if check process(state) {
            return state.tokenize(successToken);
        }
        state.forward();
    }
    state.index = state.line.length() - 1;

    // If the lexer does not expect an end delimiter at EOL, returns the token. Else it an error.
    return message.length() == 0 ? state.tokenize(successToken) : generateLexicalError(state, message);
}

# Check if the tokens adhere to the given keyword.
#
# + state - Current lexer state  
# + chars - Expected keyword
# + successToken - Output token if succeed
# + return - Tokenized TOML token on success. Else, returns a lexical error.
isolated function tokensInSequence(LexerState state, string chars, TOMLToken successToken) returns LexerState|LexicalError {
    // Check if the characters for a keyword in order
    foreach string char in chars {
        if !checkCharacter(state, char) {
            return generateInvalidCharacterError(state, successToken);
        }
        state.forward();
    }
    state.appendToLexeme(chars);
    state.forward(-1);
    return state.tokenize(successToken);
}

# Assert the character of the current index
#
# + state - Current lexer state  
# + expectedCharacters - Expected characters at the current index
# + return - True if the assertion is true. Else, an lexical error
isolated function checkCharacter(LexerState state, string|string[] expectedCharacters) returns boolean {
    if expectedCharacters is string {
        return expectedCharacters == state.peek();
    } else if expectedCharacters.indexOf(state.peek() ?: "") == () {
        return false;
    }
    return true;
}
