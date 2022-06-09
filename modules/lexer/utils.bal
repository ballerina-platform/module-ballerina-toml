# Executes the provided function on upcoming characters until the terminating character is found.
#
# + state - Current lexer state  
# + process - Function to be executed on each character iteration  
# + successToken - Token to be returned on successful traverse of the characters
# + message - Message to display if the end delimiter is not shown
# + return - Tokenized TOML token on success, Else, an lexical error.
function iterate(LexerState state, function (LexerState state) returns boolean|LexicalError process,
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
function tokensInSequence(LexerState state, string chars, TOMLToken successToken) returns LexerState|LexicalError {
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
function checkCharacter(LexerState state, string|string[] expectedCharacters) returns boolean {
    if expectedCharacters is string {
        return expectedCharacters == state.peek();
    } else if expectedCharacters.indexOf(state.peek() ?: "") == () {
        return false;
    }
    return true;
}
