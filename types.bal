# Configurations for writing a TOML document.
#
# + indentationPolicy - Number of spaces for an indentation
# + allowDottedKeys - If set, dotted keys are used instead of standard tables where applicable.
public type WriteConfig record {|
    int indentationPolicy = 2;
    boolean allowDottedKeys = true;
|};

# Configurations for reading a TOML document.
#
# + parseOffsetDateTime - If set, then offset date time is converted to Ballerina time:Utc
public type ReadConfig record {|
    boolean parseOffsetDateTime = true;
|};
