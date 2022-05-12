import toml.lexer;

# Represents an error caused by parser
public type ParsingError distinct GrammarError|ConversionError|lexer:LexicalError;

# Represents an error caused for an invalid grammar production.
public type GrammarError distinct error<lexer:ReadErrorDetails>;

# Represents an error caused by the Ballerina lang when converting a data type.
public type ConversionError distinct error<lexer:ReadErrorDetails>;

# Generate an error message based on the template,
# "Expected ${expectedTokens} after ${beforeToken}, but found ${actualToken}"
#
# + state - Current parser state
# + expectedTokens - Expected tokens for the grammar production  
# + beforeToken - Token before the current one
# + return - Formatted error message
function generateExpectError(ParserState state,
    lexer:TOMLToken|lexer:TOMLToken[]|string expectedTokens, lexer:TOMLToken beforeToken) returns GrammarError {

    string expectedTokensMessage;
    if (expectedTokens is lexer:TOMLToken[]) { // If multiple tokens
        string tempMessage = expectedTokens.reduce(function(string message, lexer:TOMLToken token) returns string {
            return message + " '" + token + "' or";
        }, "");
        expectedTokensMessage = tempMessage.substring(0, tempMessage.length() - 3);
    } else { // If a single token
        expectedTokensMessage = " '" + <string>expectedTokens + "'";
    }
    string message =
        string `Expected '${expectedTokensMessage}' after '${beforeToken}', but found '${state.currentToken.token}'`;

    return generateGrammarError(state, message, expectedTokens);
}

# Generate an error message based on the template,
# "Duplicate key exists for ${value}"
#
# + state - Current parser state
# + value - Any value name. Commonly used to indicate keys.  
# + valueType - Possible types - key, table, value
# + return - Formatted error message
function generateDuplicateError(ParserState state, string value, string valueType = "key") returns GrammarError
    => generateGrammarError(state, string `Duplicate ${valueType} exists for '${value}'`);

function generateGrammarError(ParserState state, string message,
    json? expected = (), json? context = ()) returns GrammarError
        => error(
            message + ".",
            line = state.lexerState.lineNumber + 1,
            column = state.lexerState.index,
            actual = state.currentToken.token,
            expected = expected
        );
