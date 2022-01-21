import ballerina/regex;

class Lexer {
    int index;
    int lineNumber;
    string line;

    function init() {
        self.index = 0;
        self.lineNumber = 0;
        self.line = "";
    }

    # Generates a Token for the next imediate lexemes.
    # 
    # + return - If success, returns a token, else returns a Lexical Error 
    function getToken() returns Token|error {
        // Reset the parameters at the end of the line.
        if (self.index >= self.line.length() - 1) {
            self.index = 0;
            self.line = "";
            self.lineNumber += 1;
            return {token: EOL};
        }

        // Keys are started at the beginning of the character.
        if (self.index == 0 && regex:matches(self.line[0], UNQUOTED_STRING_PATTERN)) {
            check self.iterate(self.unquotedKey);
            return {token: KEY};
        }

        match self.line[self.index] {
            "#" => {
                return {token: COMMENT};
            }
            " " => {
                check self.iterate(self.whitespace);
                return {token: WHITESPACE};
            }
        }

        return {token: ERROR};
    }

    # Check for the lexemes to create an unquoted key token.
    #
    # + i - Current index
    # + return - True if the end of the key, An error message for an invalid character.  
    private function unquotedKey(int i) returns boolean|LexicalError {
        if (!regex:matches(self.line[i], UNQUOTED_STRING_PATTERN)) {
            if (self.line[i] == " ") {
                return true;
            }
            return self.generateError("Invalid character \"" + self.line[i] + "\" for an unquoted key");
        }
        return false;
    }

    # Check for whitespace and tab lexemes.
    #
    # + i - Current index
    # + return - True if end of the token  
    private function whitespace(int i) returns boolean {
        return self.line[i] != " ";
    }

    # Encapsulate a function to run isolatedly on the remaining characters. 
    # Function lookaheads to capture the lexems for a targetted token.
    #
    # + process - Function to be executed on each iteration
    # + return - Lexical Error if available 
    private function iterate(function (int) returns boolean|LexicalError process) returns error?{
        foreach int i in self.index ... self.line.length() - 1 {
            if (check process(i)) {
                self.index = i;
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
    # + return - Constructed Lexcial Error message  
    private function generateError(string message) returns LexicalError {
        string text = "Lexical Error at line " 
                        + self.lineNumber.toString() + 
                        " index " 
                        + self.index.toString()
                        + ": "
                        + message
                        + ".";
        return error LexicalError(text);
    }
}

type Token record {|
    TOMLToken token;
    string value = "";
|};

enum TOMLToken {
    EXPRESSION,
    COMMENT,
    WHITESPACE,
    KEY,
    EOL,
    ERROR
}

enum RegexPatterns {
    UNQUOTED_STRING_PATTERN = "[a-zA-Z0-9\\-\\_]{1}"
}

type LexicalError distinct error;
