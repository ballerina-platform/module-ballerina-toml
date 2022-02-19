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

enum State {
    EXPRESSION_KEY,
    EXPRESSION_VALUE,
    DATE_TIME,
    MULTILINE_BSTRING,
    MULITLINE_LSTRING,
    MULTILINE_ESCAPE
}

# Represent an error caused by the lexical analyzer
type LexicalError distinct error;

# Generates tokens based on the TOML lexemes  
class Lexer {
    # Properties to represent current position 
    int index = 0;
    int lineNumber = 0;

    # Line to be lexically analyzed
    string line = "";

    # Value of the generated token
    string lexeme = "";

    # Current state of the Lexer
    State state = EXPRESSION_KEY;

    private map<string> escapedCharMap = {
        "b": "\u{08}",
        "t": "\t",
        "n": "\n",
        "f": "\u{0c}",
        "r": "\r",
        "\"": "\"",
        "\\": "\\"
    };

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

        // Generate tokens related to multi line basic strings
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

        // Generate tokens related to multi-line literal string
        if (self.state == MULITLINE_LSTRING && regex:matches(self.line[self.index], LITERAL_STRING_PATTERN)) {
            return self.iterate(self.multilineLiteralString, MULTI_LSTRING_CHARS);
        }

        // Process tokens related to date time
        if (self.state == DATE_TIME) {
            match self.peek() {
                ":" => { // Time separator
                    return self.generateToken(COLON);
                }
                "-" => { // Date separator or negative offset
                    return self.generateToken(MINUS);
                }
                "t"|"T"|" " => { // Time delimiter
                    return self.generateToken(TIME_DELIMITER);
                }
                "+" => { // Positive offset
                    return self.generateToken(PLUS);
                }
                "Z" => { // Zulu offset
                    return self.generateToken(ZULU);
                }
            }

            // Digits for date time
            if (regex:matches(self.line[self.index], DECIMAL_DIGIT_PATTERN)) {
                return check self.iterate(self.digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
            }
        }

        match self.peek() {
            " "|"\t" => { // Whitespace
                self.index += 1;
                return check self.getToken();
            }
            "#" => { // Comments
                return self.generateToken(EOL);
            }
            "=" => { // Key value separator
                return self.generateToken(KEY_VALUE_SEPARATOR);
            }
            "[" => { // Array values and standard tables
                if (self.peek(1) == "[" && self.state == EXPRESSION_KEY) { // Array tables
                    self.index += 1;
                    return self.generateToken(ARRAY_TABLE_OPEN);
                }
                return self.generateToken(OPEN_BRACKET);
            }
            "]" => { // Array values and standard tables
                if (self.peek(1) == "]" && self.state == EXPRESSION_KEY) { // Array tables
                    self.index += 1;
                    return self.generateToken(ARRAY_TABLE_CLOSE);
                }
                return self.generateToken(CLOSE_BRACKET);
            }
            "," => {
                return self.generateToken(SEPARATOR);
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

                if (regex:matches(<string>peekValue, DECIMAL_DIGIT_PATTERN)) {
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
                        return self.generateError("Invalid character '" + self.line[self.index + 1] + "' after '0'");
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
                        return self.generateError("There must me digits after '+'");
                    }
                    "n" => { // NAN token
                        self.lexeme = self.line[self.index];
                        self.index += 1;
                        return check self.tokensInSequence("nan", NAN);
                    }
                    "i" => { // Infinity tokens
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
            "e"|"E" => { // Exponential tokens
                return self.generateToken(EXPONENTIAL);
            }
            "{" => { // Inline table
                return self.generateToken(INLINE_TABLE_OPEN);
            }
            "}" => { // Inline table
                return self.generateToken(INLINE_TABLE_CLOSE);
            }
        }

        // Check for values starting with an integer.
        if ((self.state == EXPRESSION_VALUE) && regex:matches(self.line[self.index], DECIMAL_DIGIT_PATTERN)) {
            return check self.iterate(self.digit(DECIMAL_DIGIT_PATTERN), DECIMAL);
        }

        return self.generateError("Invalid character '" + self.line[self.index] + "'");
    }

    # Check for the lexemes to create an basic string.
    #
    # + return - True if the end of the string, An error message for an invalid character.  
    private function basicString() returns LexicalError|boolean {
        if self.matchRegexPattern(BASIC_STRING_PATTERN) {
            // Process escaped characters
            if (self.peek() == "\\") {
                self.forward();
                check self.escapedCharacter();
                return false;
            }

            self.lexeme += <string>self.peek();
            return false;
        }

        if self.peek() == "\"" {
            return true;
        }

        return self.generateError(self.formatErrorMessage(BASIC_STRING));
    }

    # Check for the lexemes to create a basic string for a line in multiline strings.
    #
    # + return - True if the end of the string, An error message for an invalid character.  
    private function multilineBasicString() returns boolean|LexicalError {
        if (!self.matchRegexPattern(BASIC_STRING_PATTERN)) {
            if (self.checkCharacter("\"")) {
                if (self.peek(1) == "\"" && self.peek(2) == "\"") {

                    // Check if the double quotes are at the end of the line
                    if (self.peek(3) == "\"" && self.peek(4) == "\"") {
                        self.lexeme += "\"\"";
                        self.index += 1;
                        return true;
                    }

                    self.index -= 1;
                    return true;
                }
            } else {
                return self.generateError(self.formatErrorMessage(MULTI_BSTRING_CHARS));
            }
        }

        // Process the escape symbol
        if (self.checkCharacter("\\")) {
            self.index -= 1;
            return true;
        }

        // Ignore whitespace if the multiline escape symbol is detected
        if (self.state == MULTILINE_ESCAPE && self.checkCharacter(" ")) {
            return false;
        }

        self.lexeme += <string>self.peek();
        self.state = MULTILINE_BSTRING;
        return false;
    }

    # Scan lexemes for the escaped characters.
    # Adds the processed escaped character to the lexeme.
    #
    # + return - An error on failure
    private function escapedCharacter() returns LexicalError? {
        string currentChar;

        // Check if the character is empty
        if (self.peek() == ()) {
            return self.generateError("Escaped character cannot be empty");
        } else {
            currentChar = <string>self.peek();
        }

        // Check for predefined escape characters
        if (self.escapedCharMap.hasKey(currentChar)) {
            self.lexeme += <string>self.escapedCharMap[currentChar];
            return;
        }

        // Check for unicode characters
        match currentChar {
            "u" => {
                check self.unicodeEscapedCharacters("u", 4);
                return;
            }
            "U" => {
                check self.unicodeEscapedCharacters("U", 8);
                return;
            }
        }
        return self.generateError(self.formatErrorMessage(BASIC_STRING));
    }

    # Process the hex codes under the unicode escaped character.
    #
    # + escapedChar - Escaped character before the digits  
    # + length - Number of digits
    # + return - An error on failure
    private function unicodeEscapedCharacters(string escapedChar, int length) returns LexicalError? {

        // Check if the required digits do not overflow the current line.
        if self.line.length() < length + self.index {
            return self.generateError("Expected " + length.toString() + " characters for the '\\" + escapedChar + "' unicode escape");
        }

        string unicodeDigits = "";

        // Check if the digits adhere to the hexadecimal code pattern.
        foreach int i in 0 ... length - 1 {
            self.forward();
            if self.matchRegexPattern(HEXADECIMAL_DIGIT_PATTERN) {
                unicodeDigits += <string>self.peek();
                continue;
            }
            return self.generateError(self.formatErrorMessage(HEXADECIMAL));
        }
        int|error hexResult = 'int:fromHexString(unicodeDigits);
        if hexResult is error {
            return self.generateError('error:message(hexResult));
        }

        string|error unicodeResult = 'string:fromCodePointInt(hexResult);
        if unicodeResult is error {
            return self.generateError('error:message(unicodeResult));
        }

        self.lexeme += unicodeResult;
    }

    # Check for the lexemes to create an literal string.
    #
    # + return - True if the end of the string, An error message for an invalid character.  
    private function literalString() returns boolean|LexicalError {
        if self.matchRegexPattern(LITERAL_STRING_PATTERN) {
            self.lexeme += <string>self.peek();
            return false;
        }
        if (self.checkCharacter("'")) {
            return true;
        }
        return self.generateError(self.formatErrorMessage(LITERAL_STRING));

    }

    # Check for the lexemes to create a basic string for a line in multiline strings.
    #
    # + return - True if the end of the string, An error message for an invalid character.  
    private function multilineLiteralString() returns boolean|LexicalError {
        if (!self.matchRegexPattern(LITERAL_STRING_PATTERN)) {
            if (self.checkCharacter("'")) {
                if (self.peek(1) == "'" && self.peek(2) == "'") {

                    // Check if the double quotes are at the end of the line
                    if (self.peek(3) == "'" && self.peek(4) == "'") {
                        self.lexeme += "''";
                        self.index += 1;
                        return true;
                    }

                    self.index -= 1;
                    return true;
                }
            } else {
                return self.generateError(self.formatErrorMessage(MULTI_BSTRING_CHARS));
            }
        }

        self.lexeme += <string>self.peek();
        return false;
    }

    # Check for the lexemes to create an unquoted key token.
    #
    # + return - True if the end of the key, An error message for an invalid character.  
    private function unquotedKey() returns boolean|LexicalError {
        if self.matchRegexPattern(UNQUOTED_STRING_PATTERN) {
            self.lexeme += <string>self.peek();
            return false;
        }

        if (self.checkCharacter([" ", ".", "]", "="])) {
            self.index = self.index - 1;
            return true;
        }

        return self.generateError(self.formatErrorMessage(UNQUOTED_KEY));

    }

    # Check for the lexemes to crete an DECIMAL token.
    #
    # + digitPattern - Regex pattern of the number system
    # + return - Generates a function which checks the lexemes for the given number system.  
    private function digit(string digitPattern) returns function () returns boolean|LexicalError {
        return function() returns boolean|LexicalError {
            if self.matchRegexPattern(digitPattern) {
                self.lexeme += <string>self.peek();
                return false;
            }

            if (self.checkCharacter([" ", "#", "\t"])) {
                self.index -= 1;
                return true;
            }

            // Both preceding and succeeding chars of the '_' should be digits
            if (self.checkCharacter("_")) {
                // '_' should be after a digit
                if (self.lexeme.length() > 0) {
                    string? nextChr = self.peek(1);
                    // '_' should be before a digit
                    if (nextChr == ()) {
                        self.forward();
                        return self.generateError("A digit must appear after the '_'");
                    }
                    // check if the next character is a digit
                    if (regex:matches(<string>nextChr, digitPattern)) {
                        return false;
                    }
                    return self.generateError("Invalid character \"" + <string>self.peek() + "\" after '_'");
                }
                return self.generateError("Invalid character \"" + <string>self.peek() + "\" after '='");
            }

            // Float number allows only a decimal number a prefix.
            // Check for decimal points and exponential in decimal numbers.
            // Check for separators and end symbols.
            if (digitPattern == DECIMAL_DIGIT_PATTERN) {
                if (self.checkCharacter([".", "e", "E", ",", "]", "}"])) {
                    self.index -= 1;
                }
                if (self.checkCharacter(["-", ":"])) {
                    self.index -= 1;
                    self.state = DATE_TIME;
                }
                if (self.state == DATE_TIME && self.checkCharacter(["-", ":", "t", "T", "+", "-", "Z"])) {
                    self.index -= 1;
                }
                return true;
            }

            return self.generateError(self.formatErrorMessage(DECIMAL));

        };
    }

    # Encapsulate a function to run solely on the remaining characters.
    # Function lookahead to capture the lexemes for a targeted token.
    #
    # + process - Function to be executed on each iteration  
    # + successToken - Token to be returned on successful traverse of the characters  
    # + message - Message to display if the end delimiter is not shown  
    # + return - Lexical Error if available
    private function iterate(function () returns boolean|LexicalError process,
                            TOMLToken successToken,
                            string message = "") returns Token|LexicalError {

        // Iterate the given line to check the DFA
        while self.index < self.line.length() {
            if (check process()) {
                return self.generateToken(successToken);
            }
            self.forward();
        }
        self.index = self.line.length() - 1;

        // If the lexer does not expect an end delimiter at EOL, returns the token. Else it an error.
        return message.length() == 0 ? self.generateToken(successToken) : self.generateError(message);
    }
    # Increments the index of the column by k indexes
    #
    # + k - Number of indexes to forward. Default = 1
    private function forward(int k = 1) {
        if (self.index + k <= self.line.length()) {
            self.index += k;
        }
    }

    # Peeks the character succeeding after k indexes. 
    # Returns the character after k spots.
    #
    # + k - Number of characters to peek. Default = 0
    # + return - Character at the peek if not null  
    private function peek(int k = 0) returns string? {
        return self.index + k < self.line.length() ? self.line[self.index + k] : ();
    }

    # Check if the tokens adhere to the given string.
    #
    # + chars - Expected string  
    # + successToken - Output token if succeed
    # + return - If success, returns the token. Else, returns the parsing error.  
    private function tokensInSequence(string chars, TOMLToken successToken) returns Token|LexicalError {
        foreach string char in chars {
            if (!self.checkCharacter(char)) {
                return self.generateError(self.formatErrorMessage(successToken));
            }
            self.forward();
        }
        self.lexeme += chars;
        self.index -= 1;
        return self.generateToken(successToken);
    }

    # Assert the character of the current index
    #
    # + expectedCharacters - Expected characters at the current index  
    # + index - Index of the character. If null, takes the lexer's 
    # + return - True if the assertion is true. Else, an lexical error
    private function checkCharacter(string|string[] expectedCharacters, int? index = ()) returns boolean {
        if (expectedCharacters is string) {
            return expectedCharacters == self.line[index == () ? self.index : index];
        } else if (expectedCharacters.indexOf(self.line[index == () ? self.index : index]) == ()) {
            return false;
        }
        return true;
    }

    # Matches the character pointed by the index with the regex pattern.
    #
    # + pattern - Regex pattern to be validate against
    # + index - Index of the character to be validate.
    # + return - True if the character follows the pattern.
    private function matchRegexPattern(string pattern, int? index = ()) returns boolean {
        return regex:matches(self.line[index == () ? self.index : index], pattern);
    }

    # Generates a Lexical Error.
    #
    # + message - Error message  
    # + return - Constructed Lexical Error message
    private function generateError(string message) returns LexicalError {
        string text = "Lexical Error at line "
                        + (self.lineNumber + 1).toString()
                        + " index "
                        + self.index.toString()
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
        self.forward();
        string lexemeBuffer = self.lexeme;
        self.lexeme = "";
        return {
            token: token,
            value: lexemeBuffer
        };
    }

    # Generate the template error message "Invalid character '${char}' for a '${token}'"
    #
    # + tokenName - Expected token name
    # + return - Generated error message
    private function formatErrorMessage(TOMLToken tokenName) returns string {
        return "Invalid character '" + <string>self.peek() + "' for a '" + tokenName + "'";
    }
}
