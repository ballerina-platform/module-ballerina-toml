import toml.lexer;

class ParserState {
    # Properties for the TOML lines
    string[] lines;
    readonly & int numLines;
    int lineIndex = -1;

    # Current token
    lexer:Token currentToken = {token: lexer:DUMMY};

    # Output TOML object
    map<json> tomlObject = {};

    # Current map structure the parser is working on
    map<json> currentStructure = {};

    # Key stack to the current structure
    string[] keyStack = [];

    # Already defined table keys
    string[] definedTableKeys = [];

    # If the token for a next grammar rule has been buffered to the current token
    boolean tokenConsumed = false;

    # Buffers the key in the full format
    string bufferedKey = "";

    # If set, the parser is currently working on an array table
    boolean isArrayTable = false;

    # The current table key name. If empty, then current table is the root.
    string currentTableKey = "";

    readonly & boolean parseOffsetDateTime;

    lexer:LexerState lexerState = new ();

    function init(string[] inputLines, boolean parseOffsetDateTime) {
        self.lines = inputLines;
        self.numLines = inputLines.length();
        self.parseOffsetDateTime = parseOffsetDateTime;
    }

    function updateLexerContext(lexer:Context context) {
        self.lexerState.context = context;
    }

    # Initialize the lexer with the attributes of a new line.
    #
    # + message - Error message to display when if the initialization fails 
    # + incrementLine - Sets the next line to the lexer
    # + return - An error if it fails to initialize  
    function initLexer(string message, boolean incrementLine = true) returns ParsingError? {
        if (incrementLine) {
            self.lineIndex += 1;
        }
        if (self.lineIndex >= self.numLines) {
            return generateError(self, message);
        }
        self.lexerState.line = self.lines[self.lineIndex];
        self.lexerState.index = 0;
        self.lexerState.lineNumber = self.lineIndex;
    }

    function addTableKey(string tableKey) {
        if tableKey.length() != 0 {
            self.definedTableKeys.push(tableKey);
        }
    }
}
