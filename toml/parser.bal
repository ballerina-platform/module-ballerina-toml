type ParsingError distinct error;

enum ParserState {
    TOMLStart
}

class Parser {
    # Input TOML lines
    private string[] lines;
    private int numLines;

    # Output TOML object
    private map<any> tomlObject;

    # Current token
    private Token currentToken;

    # Previous token
    private Token prevToken;

    # State of the parser
    private ParserState state;

    # Lexical analyzer tool for getting the tokens
    private Lexer lexer;

    function init(string[] lines) {
        self.lines = lines;
        self.numLines = lines.length()-1;
        self.tomlObject = {};
        self.lexer = new Lexer();
        self.state = TOMLStart;
    }

    
    # Generates a map object for the TOML document.
    # Initally, considers the predictions for the 'expression'
    # 
    # + return - If success, map object for the TOMl document. 
    #            Else, a lexical or a parser error. 
    public function parse() returns error? {

        // Iterating each document line
        foreach int i in 0...self.numLines {
            self.lexer.line = self.lines[i];
            self.currentToken = check self.lexer.getToken();

            while (self.currentToken.token != EOL) {
                match self.currentToken.token {
                    UNQUOTED_KEY => {
                        
                    }
                }
            }
        }
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