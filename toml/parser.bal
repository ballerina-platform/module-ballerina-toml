type ParsingError distinct error;

enum ParserState {
    START
}

class Parser {
    # Input TOML lines
    private string[] lines;

    # Output TOML object
    private map<any> tomlObject;

    # Current token
    private Token|error currentToken;

    # Previous token
    private Token|error prevToken;

    # Lexical analyzer tool for getting the tokens
    private Lexer lexer;

    function init(string[] lines) {
        self.lines = lines;
        self.tomlObject = {};
        self.lexer = new Lexer();
    }

    
    public function parse()  {
        // Iterating each line of the TOML document.
        self.lines.forEach(function (string line) {
            self.currentToken = self.lexer.getToken();
            if (self.currentToken is error) {
                // return self.currentToken;
            }
        });
    }

    # Generates a Parsing Error Error.
    #
    # + message - Error message
    # + return - Constructed Parsing Error message  
    private function generateError(string message) returns LexicalError {
        string text = "Parsing Error at line " 
                        // + self.lineNumber.toString() + 
                        + " index " 
                        // + self.index.toString()
                        + ": "
                        + message
                        + ".";
        return error LexicalError(text);
    }
}