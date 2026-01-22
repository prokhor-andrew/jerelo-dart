# What is Jerelo?

**Jerelo** is a minimal, lawful Dart functional toolkit built around
a CPS-based `Cont<A>` abstraction for composing synchronous/asynchronous
workflows with structured termination and error reporting,
plus practical operators for sequencing and concurrency.


# Design goals

- Pure Dart 
- Zero dependencies 
- Minimal API 
- Modular boundaries - swap HTTP/DB/cache/logging without rewriting flows 
- Execution agnostic - same flow works sync, async, and in tests 
- Failures are captured by contract - unexpected throws become explicit termination 
- Extensible via add-ons - core stays stable, extras stay optional extras stay optional

# Documentation

Documentation is available in [documentation/doc.md](documentation/doc.md).

API reference is available in [documentation/api.md](documentation/api.md).