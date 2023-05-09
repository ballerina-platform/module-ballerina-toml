## Overview

This module provides APIs to convert a TOML configuration file to `map<json>`, and vice-versa.

Since the parser is following LL(1) grammar, it follows a non-recursive predictive parsing algorithm which operates in a linear time complexity.

For information on the operations, which you can perform with the `toml` module, see the below **Functions**.
