#!/bin/bash
set -euo pipefail

################################################################################
# package-nuget.sh
#
# Purpose: Create a NuGet package (.nupkg) from a range-specific ZIP archive
#          of test files. This script generates all necessary NuGet metadata
#          files and uses dotnet pack to create the final package.
#
# Responsibilities:
#   - Generate package metadata (description, tags, release notes)
#   - Create README.md with usage instructions and version info
#   - Generate .csproj file with package configuration
#   - Run dotnet pack to create the .nupkg file
#
# Usage: ./package-nuget.sh <cpu_name> <range> <version> <commit_hash> <commit_date> <repo_url>
#
# Arguments:
#   cpu_name: CPU model (e.g., 8088, 80286)
#   range: Hexadecimal opcode range (e.g., 00-3F, 40-7F, 00-FF)
#   version: Package version (e.g., 2025.1.15)
#   commit_hash: Git commit hash from upstream repo
#   commit_date: Full commit date (YYYY-MM-DD)
#   repo_url: URL to upstream repository
#
# Input:
#   - ZIP file: ${cpu_name}-${range}.zip (created by split-tests.sh)
#   - LICENSE file (root of project)
#
# Output:
#   - NuGet package: nuget-${cpu_name}-${range}/${package_id}.${version}.nupkg
#
# Examples:
#   ./package-nuget.sh 8088 00-3F 2025.1.15 abc1234 2025-01-15 "https://github.com/..."
################################################################################

CPU_NAME=$1
RANGE=$2
VERSION=$3
COMMIT_HASH=$4
COMMIT_DATE=$5
REPO_URL=$6

if [ -z "$CPU_NAME" ] || [ -z "$RANGE" ] || [ -z "$VERSION" ] || [ -z "$COMMIT_HASH" ] || [ -z "$COMMIT_DATE" ] || [ -z "$REPO_URL" ]; then
    echo "Usage: $0 <cpu_name> <range> <version> <commit_hash> <commit_date> <repo_url>"
    echo "  cpu_name: CPU model (e.g., 8088, 80286)"
    echo "  range: Opcode range (e.g., 00-3F)"
    echo "  version: Package version (e.g., 2025.1.15)"
    echo "  commit_hash: Git commit hash"
    echo "  commit_date: Commit date (YYYY-MM-DD)"
    echo "  repo_url: Repository URL"
    exit 1
fi

# Parse range for display
RANGE_START_HEX="${RANGE%-*}"
RANGE_END_HEX="${RANGE#*-}"

ZIP_NAME="${CPU_NAME}.${RANGE}.zip"
NUGET_DIR="nuget-${CPU_NAME}-${RANGE}"
PACKAGE_ID="SingleStepTests.Intel${CPU_NAME}.${RANGE}"

# Package metadata
DESCRIPTION="Hardware-validated test suite for Intel ${CPU_NAME} CPU emulator validation (opcodes ${RANGE}). Contains thousands of tests per opcode with cycle-accurate execution data."
TAGS="cpu;emulator;testing;validation;${CPU_NAME};intel;hardware;opcodes"
RELEASE_NOTES="Tests for opcodes ${RANGE} from upstream SingleStepTests/${CPU_NAME} commit ${COMMIT_HASH} (${COMMIT_DATE})"

echo "================================================"
echo "Creating NuGet Package"
echo "================================================"
echo "Package ID: ${PACKAGE_ID}"
echo "Version: ${VERSION}"
echo "Range: 0x${RANGE_START_HEX}-0x${RANGE_END_HEX}"
echo "Commit: ${COMMIT_HASH} (${COMMIT_DATE})"

# Validate ZIP file exists
if [ ! -f "$ZIP_NAME" ]; then
    echo "Error: ZIP file '${ZIP_NAME}' not found."
    echo "Please run split-tests.sh first."
    exit 1
fi

# Create NuGet package structure
echo "Creating package structure..."
mkdir -p "${NUGET_DIR}/content/tests"
cp "$ZIP_NAME" "${NUGET_DIR}/content/tests/"
cp LICENSE "${NUGET_DIR}/"

# Create README.md with package documentation
echo "Generating README.md..."
cat > "${NUGET_DIR}/README.md" << EOF
# Intel ${CPU_NAME} Single Step Tests (Opcodes ${RANGE})

This package contains hardware-validated CPU tests for the Intel ${CPU_NAME} processor, covering opcodes ${RANGE}.

## Contents

- \`${ZIP_NAME}\`: Archive containing test files for opcodes 0x${RANGE_START_HEX} to 0x${RANGE_END_HEX} in JSON format

## About the Tests

These tests are from the [SingleStepTests/${CPU_NAME}](${REPO_URL}) repository.

For complete documentation about the test format, usage instructions, and test methodology, please refer to the [upstream repository README](${REPO_URL}#readme).

## Version Information

- **Package Version**: ${VERSION}
- **Source Commit**: [\`${COMMIT_HASH}\`](${REPO_URL}/commit/${COMMIT_HASH})
- **Commit Date**: ${COMMIT_DATE}

## Credits

All credit goes to [Daniel Balsom](https://github.com/dbalsom) for his incredible work in generating these hardware-validated test suites. This project simply repackages his tests for easier consumption in .NET projects.

## License

This package is distributed under the MIT License. See the LICENSE file for details.
EOF

# Create .csproj file for dotnet pack
echo "Generating .csproj file..."
cat > "${NUGET_DIR}/${PACKAGE_ID}.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <PackageId>${PACKAGE_ID}</PackageId>
    <Version>${VERSION}</Version>
    <Authors>Kevin Ferrare</Authors>
    <PackageLicenseFile>LICENSE</PackageLicenseFile>
    <PackageReadmeFile>README.md</PackageReadmeFile>
    <PackageProjectUrl>${REPO_URL}</PackageProjectUrl>
    <RepositoryUrl>${REPO_URL}</RepositoryUrl>
    <RepositoryType>git</RepositoryType>
    <RepositoryCommit>${COMMIT_HASH}</RepositoryCommit>
    <Description>${DESCRIPTION}</Description>
    <PackageTags>${TAGS}</PackageTags>
    <PackageReleaseNotes>${RELEASE_NOTES}</PackageReleaseNotes>
    <IncludeBuildOutput>false</IncludeBuildOutput>
    <GeneratePackageOnBuild>false</GeneratePackageOnBuild>
    <NoWarn>NU5128</NoWarn>
  </PropertyGroup>

  <ItemGroup>
    <None Include="LICENSE" Pack="true" PackagePath="/" />
    <None Include="README.md" Pack="true" PackagePath="/" />
    <None Include="content/tests/${ZIP_NAME}" Pack="true" PackagePath="content/tests" />
  </ItemGroup>

</Project>
EOF

# Pack the NuGet package using dotnet pack
echo "Packing NuGet package with dotnet pack..."
cd "$NUGET_DIR"
dotnet pack "${PACKAGE_ID}.csproj" --configuration Release --output . > /dev/null
cd ..

# Get package file size
nupkg_file="${NUGET_DIR}/${PACKAGE_ID}.${VERSION}.nupkg"
if [ -f "$nupkg_file" ]; then
    pkg_size=$(du -h "$nupkg_file" | cut -f1)
    echo "================================================"
    echo "✓ NuGet package created: ${PACKAGE_ID}.${VERSION}.nupkg"
    echo "  Location: ${nupkg_file}"
    echo "  Size: ${pkg_size}"
    echo "================================================"
    
    # Clean up ZIP file and temp directory to save disk space
    echo "Cleaning up temporary files..."
    rm -f "$ZIP_NAME"
    rm -rf "${CPU_NAME}-tests-${RANGE}"
    echo "✓ Cleaned up: $ZIP_NAME and ${CPU_NAME}-tests-${RANGE}/"
else
    echo "Error: Package file not created"
    exit 1
fi
