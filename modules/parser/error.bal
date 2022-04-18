import toml.lexer;

# Represents an error caused by parser
type ParsingError distinct error;

# Generates a Parsing Error Error.
#
# + state - Current parser state 
# + message - Error message
# + return - Constructed Parsing Error message
function generateError(ParserState state, string message) returns ParsingError {
    string text = "Parsing Error at line "
                        + state.lexerState.lineNumber.toString()
                        + " index "
                        + state.lexerState.index.toString()
                        + ": "
                        + message
                        + ".";
    return error ParsingError(text);
}

# Generate a standard error message of "Expected ${expectedTokens} after ${beforeToken}, but found ${actualToken}"
#
# + currentToken - Current token 
# + expectedTokens - Expected tokens for the grammar production
# + beforeToken - Token before the current one
# + return - Formatted error message
function formatExpectErrorMessage(lexer:TOMLToken currentToken, lexer:TOMLToken|lexer:TOMLToken[] expectedTokens, lexer:TOMLToken beforeToken) returns string {
    string expectedTokensMessage;
    if (expectedTokens is lexer:TOMLToken[]) { // If multiple tokens
        string tempMessage = expectedTokens.reduce(function(string message, lexer:TOMLToken token) returns string {
            return message + " '" + token + "' or";
        }, "");
        expectedTokensMessage = tempMessage.substring(0, tempMessage.length() - 3);
    } else { // If a single token
        expectedTokensMessage = " '" + expectedTokens + "'";
    }
    return string `Expected '${expectedTokensMessage}'  after '${beforeToken}', but found '${currentToken}'`;
}

# Generate a standard error message of "Duplicate key exists for ${value}"
#
# + value - Any value name. Commonly used to indicate keys.
# + return - Formatted error message
function formateDuplicateErrorMessage(string value) returns string
    => string `Duplicate key exists for '${value}'`;
