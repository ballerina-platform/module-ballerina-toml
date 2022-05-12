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

    # Already defined array table keys
    string[] definedArrayTableKeys = [];

    # Keys defined specific for the current array table.
    string[] tempTableKeys = [];

    # If the token for a next grammar rule has been buffered to the current token.
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
    # + err - Error to be returned on failure
    # + incrementLine - Sets the next line to the lexer
    # + return - An error if it fails to initialize  
    function initLexer(GrammarError err, boolean incrementLine = true) returns ParsingError? {
        if (incrementLine) {
            self.lineIndex += 1;
        }
        if (self.lineIndex >= self.numLines) {
            return err;
        }
        self.lexerState.line = self.lines[self.lineIndex];
        self.lexerState.index = 0;
        self.lexerState.lineNumber = self.lineIndex;
    }

    # Add a table key to the respective array if possible.
    #
    # + tableKey - Table key to be added.
    function addTableKey(string tableKey) {
        // Array table keys are maintained separately
        if self.isArrayTable {
            if self.definedArrayTableKeys.indexOf(tableKey) == () {
                self.definedArrayTableKeys.push(tableKey);
            }
            return;
        }

        // Check if the standard table key is an extension of array table.
        // If it is, then added to a temp array that is only valid for that array table.
        foreach string arrayTableKey in self.definedArrayTableKeys {
            if tableKey.startsWith(arrayTableKey) {
                self.tempTableKeys.push(tableKey);
                return;
            }
        }

        // A regular standard key is persistent throughout the document.
        if tableKey.length() != 0 {
            self.definedTableKeys.push(tableKey);
        }
    }
}
