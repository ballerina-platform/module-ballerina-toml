import ballerina/regex;

# Encapsulate a function to run solely on the remaining characters.
# Function lookahead to capture the lexemes for a targeted token.
#
# + process - Function to be executed on each iteration  
# + successToken - Token to be returned on successful traverse of the characters  
# + message - Message to display if the end delimiter is not shown  
# + return - Lexical Error if available
function iterate(function () returns boolean|LexicalError process,
                            TOMLToken successToken,
                            string message = "") returns Token|LexicalError {

    // Iterate the given line to check the DFA
    while index < line.length() {
        if (check process()) {
            return generateToken(successToken);
        }
        forward();
    }
    index = line.length() - 1;

    // If the lexer does not expect an end delimiter at EOL, returns the token. Else it an error.
    return message.length() == 0 ? generateToken(successToken) : generateError(message);
}

# Increments the index of the column by k indexes
#
# + k - Number of indexes to forward. Default = 1
function forward(int k = 1) {
    if (index + k <= line.length()) {
        index += k;
    }
}

# Peeks the character succeeding after k indexes. 
# Returns the character after k spots.
#
# + k - Number of characters to peek. Default = 0
# + return - Character at the peek if not null  
function peek(int k = 0) returns string? {
    return index + k < line.length() ? line[index + k] : ();
}

# Check if the tokens adhere to the given string.
#
# + chars - Expected string  
# + successToken - Output token if succeed
# + return - If success, returns the token. Else, returns the parsing error.  
function tokensInSequence(string chars, TOMLToken successToken) returns Token|LexicalError {
    foreach string char in chars {
        if (!checkCharacter(char)) {
            return generateError(formatErrorMessage(successToken));
        }
        forward();
    }
    lexeme += chars;
    index -= 1;
    return generateToken(successToken);
}

# Assert the character of the current index
#
# + expectedCharacters - Expected characters at the current index  
# + currentIndex - Index of the character. If null, takes the lexer's 
# + return - True if the assertion is true. Else, an lexical error
function checkCharacter(string|string[] expectedCharacters, int? currentIndex = ()) returns boolean {
    if (expectedCharacters is string) {
        return expectedCharacters == line[currentIndex == () ? index : currentIndex];
    } else if (expectedCharacters.indexOf(line[currentIndex == () ? index : currentIndex]) == ()) {
        return false;
    }
    return true;
}

# Matches the character pointed by the index with the regex pattern.
#
# + pattern - Regex pattern to be validate against
# + currentIndex - Index of the character to be validate.
# + return - True if the character follows the pattern.
function matchRegexPattern(string pattern, int? currentIndex = ()) returns boolean {
    return regex:matches(line[currentIndex == () ? index : currentIndex], pattern);
}

# Generate a lexical token.
#
# + token - TOML token
# + return - Generated lexical token  
function generateToken(TOMLToken token) returns Token {
    forward();
    string lexemeBuffer = lexeme;
    lexeme = "";
    return {
        token: token,
        value: lexemeBuffer
    };
}