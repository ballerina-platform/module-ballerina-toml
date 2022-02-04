class Writer {

    # The table key which the Writer currently processing. 
    # Root if the string is empty.
    private string tableKey;

    function init() {
        self.tableKey = "";
    }

    public function write() returns error? {

    }

    private function processPrimitiveValue() {

    }
}
