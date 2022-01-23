import ballerina/regex;

enum RegexPatterns {
    UNQUOTED_STRING_PATTERN = "[a-zA-Z0-9\\-\\_]{1}",
    BASIC_STRING_PATTERN = "[/s\\x21\\x23-\\x5b\\x5d-\\x7e\\x80-\\xd7ff\\xe000-\\xffff]{1}",
    LITERAL_STRING_PATTERN = "[\\x09\\x20-\\x26\\x28-\\x7e\\x80-\\xd7ff\\xe000-\\xffff]{1}",
    ESCAPE_STRING_PATTERN = "[\\x22\\x5c\\x62\\x66\\x6e\\x72\\x74\\x75\\x55]{1}"
}

type LexicalError distinct error;

class Lexer {
    int index;
    int lineNumber;
    string line;
    string lexeme;

    function init() {
        self.index = 0;
        self.lineNumber = 0;
        self.line = "";
        self.lexeme = "";
    }

    # Generates a Token for the next immediate lexeme.
    #
    # + return - If success, returns a token, else returns a Lexical Error 
    function getToken() returns Token|error {

        // Reset the parameters at the end of the line.
        if (self.index >= self.line.length() - 1) {
            self.index = 0;
            self.line = "";
            self.lexeme = "";
            return {token: EOL};
        }

        // Check for bare keys at the start of a line.
        if (self.index == 0 && regex:matches(self.line[0], UNQUOTED_STRING_PATTERN)) {
            check self.iterate(self.unquotedKey);
            return self.generateToken(UNQUOTED_KEY);
        }

        match self.line[self.index] {
            "#" => {
                return self.generateToken(EOL);
            }
            " " => {
                check self.iterate(self.whitespace);
                return self.generateToken(WHITESPACE);
            }
            "=" => {
                return self.generateToken(KEY_VALUE_SEPERATOR);
            }
            "\"" => {
                self.index += 1;
                check self.iterate(self.basicString);
                return self.index == 0 ? self.generateToken(QUOTED_KEY) : self.generateToken(BASIC_STRING);
            }
            "'" => {
                self.index += 1;
                check self.iterate(self.literalString);
                return self.index == 0 ? self.generateToken(QUOTED_KEY) : self.generateToken(LITERAL_STRING);
            }
        }

        return self.generateToken(EOL);
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

    # Check for the lexemes to create an unquoted key token.
    #
    # + i - Current index
    # + return - True if the end of the key, An error message for an invalid character.  
    private function unquotedKey(int i) returns boolean|LexicalError {
        if (!regex:matches(self.line[i], UNQUOTED_STRING_PATTERN)) {
            if (self.line[i] == " ") {
                self.index = i - 1;
                return true;
            }
            return self.generateError("Invalid character \"" + self.line[i] + "\" for an unquoted key", i);
        }
        self.lexeme += self.line[i];
        return false;
    }

    # Check for whitespace and tab lexemes.
    #
    # + i - Current index
    # + return - True if end of the token  
    private function whitespace(int i) returns boolean {
        if (self.line[i] == " ") {
            return false;
        }
        self.index = i - 1;
        return true;
    }

    # Encapsulate a function to run isolatedly on the remaining characters. 
    # Function lookaheads to capture the lexems for a targetted token.
    #
    # + process - Function to be executed on each iteration
    # + return - Lexical Error if available 
    private function iterate(function (int) returns boolean|LexicalError process) returns error? {
        foreach int i in self.index ... self.line.length() - 1 {
            if (check process(i)) {
                return;
            }
        }

        // EOL is reached
        self.index = self.line.length() - 1;
        return;
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

    # Generate a lexical token.Ø
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
