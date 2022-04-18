public class LexerState {
    # Properties to represent current position 
    int index = 0;
    int lineNumber = 0;

    # Line to be lexically analyzed
    string line = "";

    # Value of the generated token
    string lexeme = "";

    # Current context of the Lexer
    Context context = EXPRESSION_KEY;

    # Output TOML token
    TOMLToken token = DUMMY;

    function appendToLexeme(string appendLine) {
        self.lexeme += appendLine;
    }

    # Increment the index of the column by k indexes
    #
    # + k - Number of indexes to forward. Default = 1
    function forward(int k = 1) {
        if (self.index + k <= self.line.length()) {
            self.index += k;
        }
    }

    # Peeks the character succeeding after k indexes. 
    # Returns the character after k spots.
    #
    # + k - Number of characters to peek. Default = 0
    # + return - Character at the peek if not null  
    function peek(int k = 0) returns string? {
        return self.index + k < self.line.length() ? self.line[self.index + k] : ();
    }

    # Add the output TOML token to the current state
    #
    # + token - TOML token
    # + return - Generated lexical token  
    function tokenize(TOMLToken token) returns LexerState {
        self.forward();
        self.token = token;
        return self;
    }

    # Obtain the lexer token
    # 
    # + return - Lexer token
    public function getToken() returns Token {
        TOMLToken tokenBuffer = self.token;
        self.token = DUMMY;
        string lexemeBuffer = self.lexeme;
        self.lexeme = "";
        return {
            token: tokenBuffer,
            value: lexemeBuffer
        };
    }
}
