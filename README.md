# Single Step Tests NuGet Packages

This project packages hardware-generated CPU test suites from the SingleStepTests repositories as NuGet dependencies for easy integration into .NET projects:

- [SingleStepTests/8088](https://github.com/SingleStepTests/8088) - Intel 8088 CPU test suite
- [SingleStepTests/80286](https://github.com/SingleStepTests/80286) - Intel 80286 CPU test suite

## What Are Single Step Tests?

These are hardware-validated test suites for Intel CPUs (8088 and 80286) that test thousands of scenarios per opcode. Each test includes the initial CPU and memory state, instruction bytes, and expected final state with cycle-accurate execution data.

## What This Project Does

This project automates the packaging process for both test suites:
1. **Clone** the SingleStepTests/8088 repository
2. **Extract** all compressed test files from a `v2/` directory (`00.json.gz`, `01.json.gz`, etc.)
3. **Convert** the extracted files to JSON format if in MOO format
4. **Split** the test files by opcode range to stay within NuGet's 500MB package limit
5. **Package** each range into separate zip archives
6. **Publish** as multiple NuGet packages, one per opcode range

### Package Naming Convention

All packages follow the pattern: `SingleStepTests.Intel{CPU}.{RANGE}`

Where:
- `{CPU}` is the processor model (e.g., `8088`, `80286`)
- `{RANGE}` is the hexadecimal opcode range (e.g., `00-3F`, `40-7F`)

### Package Contents

Each package contains a zip file with test JSON files for its opcode range that can be extracted and used for CPU emulator validation and testing.

### Versioning Strategy
Package versions use the date of the last commit in the upstream repository (format: `YYYY.M.D`). This provides a clear timeline of when the tests were last updated. Release notes include the upstream commit hash for full traceability.


## Credits

All credit goes to the maintainers of the [SingleStepTests/8088](https://github.com/SingleStepTests/8088) and [SingleStepTests/80286](https://github.com/SingleStepTests/80286) projects for their incredible work in generating these hardware-validated test suites. This project simply repackages their tests for easier consumption in .NET projects.

## License

This packaging project is licensed under the MIT License, same as the SingleStepTests projects. See the [LICENSE](LICENSE) file for details.