# Single Step Tests NuGet Packages

This project packages hardware-generated CPU test suites from the SingleStepTests repositories as NuGet dependencies for easy integration into .NET projects:

- [SingleStepTests/8086](https://github.com/SingleStepTests/8086) - Intel 8086 CPU test suite
- [SingleStepTests/8088](https://github.com/SingleStepTests/8088) - Intel 8088 CPU test suite
- [SingleStepTests/80286](https://github.com/SingleStepTests/80286) - Intel 80286 CPU test suite
- [SingleStepTests/80386](https://github.com/SingleStepTests/80386) - Intel 80386 CPU test suite

## What Are Single Step Tests?

These are hardware-validated test suites for Intel CPUs (8086, 8088 and 80286) that test thousands of scenarios per opcode. Each test includes the initial CPU and memory state, instruction bytes, and expected final state with cycle-accurate execution data.

## What This Project Does

This project automates the packaging process for all test suites:
1. **Clone** the SingleStepTests repository
2. **Extract** all compressed test files from the appropriate directory (`v1/`, `v2/`, etc.)
3. **Convert** the extracted files to JSON format if in MOO format
4. **Split** the test files by opcode range when needed to stay within NuGet's 500MB package limit
5. **Package** each range into separate zip archives
6. **Publish** as NuGet packages, one per opcode range (or a single package if small enough)

### Package Naming Convention

All packages follow the pattern: `SingleStepTests.Intel{CPU}.{RANGE}`

Where:
- `{CPU}` is the processor model (e.g., `8086`, `8088`, `80286`)
- `{RANGE}` is the hexadecimal opcode range (e.g., `00-3F`, `40-7F`, `00-FF`)

### Package Contents

Each package contains a zip file with test JSON files for its opcode range that can be extracted and used for CPU emulator validation and testing.

### Versioning Strategy
Package versions use the date of the last commit in the upstream repository (format: `YYYY.M.D`). This provides a clear timeline of when the tests were last updated. Release notes include the upstream commit hash for full traceability.


## Credits

All credit goes to [Daniel Balsom](https://github.com/dbalsom) for his incredible work in generating these hardware-validated test suites. This project simply repackages his tests for easier consumption in .NET projects.

## License

This packaging project is licensed under the MIT License, same as the SingleStepTests projects. See the [LICENSE](LICENSE) file for details.
