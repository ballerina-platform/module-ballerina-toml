import ballerina/regex;

enum RegexPatterns {
    UNQUOTED_STRING_PATTERN = "[a-zA-Z0-9\\-\\_]{1}",
    BASIC_STRING_PATTERN = "[\\x20\\x09\\x21\\x23-\\x5b\\x5d-\\x7e\\x80-\\xd7ff\\xe000-\\xffff]{1}",
    LITERAL_STRING_PATTERN = "[\\x20\\x09-\\x26\\x28-\\x7e\\x80-\\xd7ff\\xe000-\\xffff]{1}",
    ESCAPE_STRING_PATTERN = "[\\x22\\x5c\\x62\\x66\\x6e\\x72\\x74\\x75\\x55]{1}",
    DECIMAL_DIGIT_PATTERN = "[0-9]{1}",
    HEXADECIMAL_DIGIT_PATTERN = "[0-9a-fA-F]{1}",
    OCTAL_DIGIT_PATTERN = "[0-7]{1}",
    BINARY_DIGIT_PATTERN = "[0-1]{1}"
}

type LexicalError distinct error;

class Lexer {
    int index;
    int lineNumber;
    string line;
    string lexeme;
    State state;

    function init() {
        self.index = 0;
        self.lineNumber = 0;
        self.line = "";
        self.lexeme = "";
        self.state = EXPRESSION_KEY;
    }

    # Generates a Token for the next immediate lexeme.
    #
    # + return - If success, returns a token, else returns a Lexical Error 
    function getToken() returns Token|error {

        // Generate EOL token 
        if (self.index >= self.line.length()) {
            return {token: EOL};
        }

        // Check for bare keys at the start of a line.
        if (self.state == EXPRESSION_KEY && regex:matches(self.line[self.index], UNQUOTED_STRING_PATTERN)) {
            return check self.iterate(self.unquotedKey, UNQUOTED_KEY);
        }

        if (self.state == MULTILINE_BSTRING || self.state == MULTILINE_ESCAPE) {
            // Process the escape symbol
            if (self.line[self.index] == "\\") {
                return self.generateToken(MULTI_BSTRING_ESCAPE);
            }

            // Process multiline string regular characters
            if (regex:matches(self.line[self.index], BASIC_STRING_PATTERN)) {
                return check self.iterate(self.multilineBasicString, MULTI_BSTRING_CHARS);
            }

        }

        if (self.state == MULITLINE_LSTRING && regex:matches(self.line[self.index], LITERAL_STRING_PATTERN)) {
            return self.iterate(self.multilineLiteralString, MULTI_LSTRING_CHARS);
        }

        if (self.state == NUMBER) {
            match self.line[self.index] {
                ":" => {
                    return self.generateToken(COLON);
                }
                "-" => {
                    return self.generateToken(MINUS);
                }
                "t"|"T"|" " => {
                    return self.generateToken(TIME_DELIMITER);
                }
                "+" => {
                    return self.generateToken(PLUS);
                }
                "Z" => {
                    return self.generateToken(ZULU);
                }
            }

            if (regex:matches(self.line[self.index], DECIMAL_DIGIT_PATTERN)) {
                return check self.iterate(self.digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
            }
        }

        match self.line[self.index] {
            " "|"\t" => { // Whitespace
                self.index += 1;
                return check self.getToken();
            }
            "#" => { // Comments
                return self.generateToken(EOL);
            }
            "=" => { // Key value seperator
                self.state = EXPRESSION_VALUE;
                return self.generateToken(KEY_VALUE_SEPERATOR);
            }
            "[" => {
                if (self.peek(1) == "[" && self.state == EXPRESSION_KEY) {
                    self.index += 1;
                    return self.generateToken(ARRAY_TABLE_OPEN);
                }
                return self.generateToken(OPEN_BRACKET);
            }
            "]" => {
                if (self.peek(1) == "]" && self.state == EXPRESSION_KEY) {
                    self.index += 1;
                    return self.generateToken(ARRAY_TABLE_CLOSE);
                }
                return self.generateToken(CLOSE_BRACKET);
            }
            "," => {
                return self.generateToken(ARRAY_SEPARATOR);
            }
            "\"" => { // Basic strings

                // Multi-line basic strings
                if (self.peek(1) == "\"" && self.peek(2) == "\"") {
                    self.index += 2;
                    return self.generateToken(MULTI_BSTRING_DELIMITER);
                }

                self.index += 1;
                return check self.iterate(self.basicString, BASIC_STRING, "Expected '\"' at the end of the basic string");
            }
            "'" => { // Literal strings

                // Multi-line literal string
                if (self.peek(1) == "'" && self.peek(2) == "'") {
                    self.index += 2;
                    return self.generateToken(MULTI_LSTRING_DELIMITER);
                }

                self.index += 1;
                return check self.iterate(self.literalString, LITERAL_STRING, "Expected ''' at the end of the literal string");
            }
            "." => { // Dotted keys
                return self.generateToken(DOT);
            }
            "0" => {
                string? peekValue = self.peek(1);
                if (peekValue == ()) {
                    self.lexeme = "0";
                    return self.generateToken(DECIMAL);
                }

                if (regex:matches(peekValue, DECIMAL_DIGIT_PATTERN)) {
                    self.state = NUMBER;
                    return check self.iterate(self.digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
                }

                match peekValue {
                    "x" => { // Hexadecimal numbers
                        self.index += 2;
                        return check self.iterate(self.digit(HEXADECIMAL_DIGIT_PATTERN), HEXADECIMAL);
                    }
                    "o" => { // Octal numbers
                        self.index += 2;
                        return check self.iterate(self.digit(OCTAL_DIGIT_PATTERN), OCTAL);
                    }
                    "b" => { // Binary numbers
                        self.index += 2;
                        return check self.iterate(self.digit(BINARY_DIGIT_PATTERN), BINARY);
                    }
                    " "|"#"|"."|","|"]" => { // Decimal numbers
                        self.lexeme = "0";
                        return self.generateToken(DECIMAL);
                    }
                    _ => {
                        return self.generateError("Invalid character '" + self.line[self.index + 1] + "' after '0'", self.index + 1);
                    }
                }
            }
            "+"|"-" => { // Decimal numbers
                match self.peek(1) {
                    "0" => { // There cannot be leading zero.
                        self.lexeme = self.line[self.index] + "0";
                        self.index += 1;
                        return self.generateToken(DECIMAL);
                    }
                    () => { // Only '+' and '-' are invalid.
                        return self.generateError("There must me digits after '+'", self.index + 1);
                    }
                    "n" => { // NAN token
                        self.lexeme = self.line[self.index];
                        self.index += 1;
                        return check self.tokensInSequence("nan", NAN);
                    }
                    "i" => {
                        self.lexeme = self.line[self.index];
                        self.index += 1;
                        return check self.tokensInSequence("inf", INFINITY);
                    }
                    _ => { // Remaining digits of the decimal numbers
                        self.lexeme = self.line[self.index];
                        self.index += 1;
                        return check self.iterate(self.digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
                    }
                }
            }
            "t" => { // Boolean true token
                return check self.tokensInSequence("true", BOOLEAN);
            }
            "f" => { // Boolean false token
                return check self.tokensInSequence("false", BOOLEAN);
            }
            "n" => { // NAN token
                return check self.tokensInSequence("nan", NAN);
            }
            "i" => {
                self.lexeme = "+";
                return check self.tokensInSequence("inf", INFINITY);
            }
            "e"|"E" => {
                return self.generateToken(EXPONENTIAL);
            }
            "{" => {
                return self.generateToken(INLINE_TABLE_OPEN);
            }
            "}" => {
                return self.generateToken(INLINE_TABLE_CLOSE);
            }
        }

        // Check for values starting with an DECIMAL.
        if ((self.state == EXPRESSION_VALUE || self.state == NUMBER) && regex:matches(self.line[self.index], DECIMAL_DIGIT_PATTERN)) {
            return check self.iterate(self.digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
        }

        return self.generateError("Invalid character '" + self.line[self.index] + "'", self.index);
    }

    # Check for the lexemes to create an basic string.
    #
    # + i - Current index
    # + return - True if the end of the string, An error message for an invalid character.  
    private function basicString(int i) returns boolean|LexicalError {
        if (!regex:matches(self.line[i], BASIC_STRING_PATTERN)) {
            if (self.line[i] == "\"") {
                self.index = i;
                return true;
            }
            return self.generateError("Invalid character \"" + self.line[i] + "\" for a basic string", i);
        }

        self.lexeme += self.line[i];
        return false;
    }

    # Check for the lexemes to create a basic string for a line in multiline strings.
    #
    # + i - Current index
    # + return - True if the end of the string, An error message for an invalid character.  
    private function multilineBasicString(int i) returns boolean|LexicalError {
        if (!regex:matches(self.line[i], BASIC_STRING_PATTERN)) {
            if (self.line[i] == "\"") {
                self.index = i;
                if (self.peek(1) == "\"" && self.peek(2) == "\"") {

                    // Check if the double quotes are at the end of the line
                    if (self.peek(3) == "\"" && self.peek(4) == "\"") {
                        self.lexeme += "\"\"";
                        self.index = i + 1;
                        return true;
                    }

                    self.index = i - 1;
                    return true;
                }
            } else {
                return self.generateError("Invalid character \"" + self.line[i] + "\" for a multi-line basic string", i);
            }
        }

        // Process the escape symbol
        if (self.line[i] == "\\") {
            self.index = i - 1;
            return true;
        }

        // Ignore whitespaces if the multiline escape symbol is detected
        if (self.state == MULTILINE_ESCAPE && self.line[i] == " ") {
            return false;
        }

        self.lexeme += self.line[i];
        self.state = MULTILINE_BSTRING;
        return false;
    }

    # Check for the lexemes to create an literal string.
    #
    # + i - Current index
    # + return - True if the end of the string, An error message for an invalid character.  
    private function literalString(int i) returns boolean|LexicalError {
        if (!regex:matches(self.line[i], LITERAL_STRING_PATTERN)) {
            if (self.line[i] == "'") {
                self.index = i;
                return true;
            }
            return self.generateError("Invalid character \"" + self.line[i] + "\" for a literal string", i);
        }
        self.lexeme += self.line[i];
        return false;
    }

    # Check for the lexemes to create a basic string for a line in multiline strings.
    #
    # + i - Current index
    # + return - True if the end of the string, An error message for an invalid character.  
    private function multilineLiteralString(int i) returns boolean|LexicalError {
        if (!regex:matches(self.line[i], LITERAL_STRING_PATTERN)) {
            if (self.line[i] == "'") {
                self.index = i;
                if (self.peek(1) == "'" && self.peek(2) == "'") {

                    // Check if the double quotes are at the end of the line
                    if (self.peek(3) == "'" && self.peek(4) == "'") {
                        self.lexeme += "''";
                        self.index = i + 1;
                        return true;
                    }

                    self.index = i - 1;
                    return true;
                }
            } else {
                return self.generateError("Invalid character \"" + self.line[i] + "\" for a multi-line literal string", i);
            }
        }

        self.lexeme += self.line[i];
        return false;
    }

    # Check for the lexemes to create an unquoted key token.
    #
    # + i - Current index
    # + return - True if the end of the key, An error message for an invalid character.  
    private function unquotedKey(int i) returns boolean|LexicalError {
        if (!regex:matches(self.line[i], UNQUOTED_STRING_PATTERN)) {
            if (self.checkCharacter([" ", ".", "]", "="], i)) {
                self.index = i - 1;
                return true;
            }
            return self.generateError("Invalid character \"" + self.line[i] + "\" for an unquoted key", i);
        }
        self.lexeme += self.line[i];
        return false;
    }

    # Check for the lexems to crete an DECIMAL token.
    #
    # + digitPattern - Regex pattern of the number system
    # + return - Generates a function which checks the lexems for the given number system.  
    private function digit(string digitPattern) returns function (int i) returns boolean|LexicalError {
        return function(int i) returns boolean|LexicalError {
            if (!regex:matches(self.line[i], digitPattern)) {
                if (self.line[i] == " " || self.line[i] == "#") {
                    self.index = i - 1;
                    return true;
                }

                // Both preceding and succeeding chars of the '_' should be digits
                if (self.line[i] == "_") {
                    // '_' should be after a digit
                    if (self.lexeme.length() > 0) {
                        string? nextChr = self.peek(1);
                        // '_' should be before a digit
                        if (nextChr == ()) {
                            return self.generateError("A digit must appear after the '_'", self.index + 1);
                        }
                        // check if the next character is a digit
                        if (regex:matches(<string>nextChr, digitPattern)) {
                            return false;
                        }
                        return self.generateError("Invalid character \"" + self.line[i] + "\" after '_'", i);
                    }
                    return self.generateError("Invalid character \"" + self.line[i] + "\" after '='", i);
                }

                // Float number allows only a decimal number a prefix.
                // Check for decimal points and exponentials in decimal numbers.
                // Check for separators and end symbols.
                if (digitPattern == DECIMAL_DIGIT_PATTERN) {
                    if (self.checkCharacter([".", "e", "E", ",", "]", "}"], i)) {
                        self.index = i - 1;
                    }
                    if (self.checkCharacter(["-", ":"], i)) {
                        self.index = i - 1;
                        self.state = NUMBER;
                    }
                    if (self.state == NUMBER && self.checkCharacter(["-", ":", "t", "T", "+", "-", "Z"], i)) {
                        self.index = i - 1;
                    }
                    return true;
                }

                return self.generateError("Invalid character \"" + self.line[i] + "\" for an DECIMAL", i);
            }
            self.lexeme += self.line[i];
            return false;
        };
    }

    # Encapsulate a function to run isolatedly on the remaining characters.
    # Function lookaheads to capture the lexems for a targetted token.
    #
    # + process - Function to be executed on each iteration  
    # + successToken - Token to be returned on successful traverse of the characters
    # + message - Message to display if the end delimeter is not shown
    # + return - Lexical Error if available
    private function iterate(function (int) returns boolean|LexicalError process,
                            TOMLToken successToken,
                            string message = "") returns Token|LexicalError {

        // Iterate the given line to check the DFA
        foreach int i in self.index ... self.line.length() - 1 {
            if (check process(i)) {
                return self.generateToken(successToken);
            }
        }
        self.index = self.line.length() - 1;

        // If the lexer does not expect an end delimiter at EOL, returns the token. Else it an error.
        return message.length() == 0 ? self.generateToken(successToken) : self.generateError(message, self.index);
    }

    # Peeks the character succeeding after k indexes. 
    # Returns the character after k DECIMALs
    #
    # + k - Number of characters to peek
    # + return - Character at the peek if not null  
    private function peek(int k) returns string? {
        return self.index + k < self.line.length() ? self.line[self.index + k] : ();
    }

    # Check if the tokens adhere to the given string.
    #
    # + chars - Expected string  
    # + successToken - Output token if succeed
    # + return - If success, returns the token. Else, returns the parsing error.  
    private function tokensInSequence(string chars, TOMLToken successToken) returns Token|LexicalError {
        foreach string char in chars {
            if (self.line[self.index] != char) {
                return self.generateError("Invalid character '" + char + "' for a value", self.index);
            }
            self.index += 1;
        }
        self.lexeme += chars;
        self.index -= 1;
        return self.generateToken(successToken);
    }

    # Assert the character of the current index
    #
    # + expectedCharacters - Expected characters at the current index
    # + return - True if the assertion is true
    private function checkCharacter(string|string[] expectedCharacters, int? index) returns boolean {
        if (expectedCharacters is string) {
            return expectedCharacters == self.line[index == () ? self.index : index];
        } else if (expectedCharacters.indexOf(self.line[index == () ? self.index : index]) == ()) {
            return false;
        }
        return true;
    }
    # Generates a Lexical Error.
    #
    # + message - Error message  
    # + index - Index where the Lexical error occurred
    # + return - Constructed Lexcial Error message
    private function generateError(string message, int index) returns LexicalError {
        string text = "Lexical Error at line "
                        + (self.lineNumber + 1).toString()
                        + " index "
                        + index.toString()
                        + ": "
                        + message
                        + ".";
        return error LexicalError(text);
    }

    # Generate a lexical token.
    #
    # + token - TOML token
    # + return - Generated lexical token  
    private function generateToken(TOMLToken token) returns Token {
        self.index += 1;
        string lexemeBuffer = self.lexeme;
        self.lexeme = "";
        return {
            token: token,
            value: lexemeBuffer
        };
    }
}
