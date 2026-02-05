# What is Jerelo?

**Jerelo** is a Dart library for building cold, lazy, reusable computations. It provides operations for chaining, transforming, branching, merging, and error handling.


# Design goals

- Pure Dart 
- Zero dependencies 
- Minimal API 
- Modular boundaries - swap HTTP/DB/cache/logging without rewriting flows 
- Execution agnostic - same flow works sync, async, and in tests 
- Failures are captured by contract - unexpected throws become explicit termination 
- Extensible via add-ons - core stays stable, extras stay optional

# Documentation

Documentation is available in [documentation/doc.md](documentation/doc.md).

API reference is available in [documentation/api.md](documentation/api.md).