type Token record {|
    TOMLToken token;
    string value = "";
|};

enum TOMLToken {
    DUMMY,
    UNQUOTED_KEY,
    KEY_VALUE_SEPERATOR,
    DOT,
    BASIC_STRING,
    LITERAL_STRING,
    EOL
}