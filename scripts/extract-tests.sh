#!/bin/bash
set -euo pipefail

################################################################################
# extract-tests.sh
#
# Purpose: Clone the upstream SingleStepTests repository and extract all test
#          files to a working directory. This script handles both compressed
#          JSON files (.json.gz) and compressed MOO files (.moo.gz/.MOO.gz).
#          
# Responsibilities:
#   - Clone the specified Git repository
#   - Extract all .gz files from the test directory
#   - Auto-detect file format (JSON or MOO)
#   - Convert MOO files to JSON using the upstream conversion tool
#   - Export version information (commit hash, date) for downstream scripts
#
# Usage: ./extract-tests.sh <cpu_name> <repo_url> <test_dir>
#
# Arguments:
#   cpu_name: CPU model (e.g., 8088, 80286)
#   repo_url: Git repository URL
#   test_dir: Directory within repo containing test files (e.g., v2, v1_real_mode)
#
# Output:
#   - Directory: ${cpu_name}-tests/ containing all extracted JSON test files
#   - GitHub Actions outputs: VERSION, COMMIT_HASH, COMMIT_DATE_FULL
#
# Examples:
#   ./extract-tests.sh 8088 https://github.com/SingleStepTests/8088.git v2
#   ./extract-tests.sh 80286 https://github.com/SingleStepTests/80286.git v1_real_mode
################################################################################

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CPU_NAME=$1
REPO_URL=$2
TEST_DIR=$3

if [ -z "$CPU_NAME" ] || [ -z "$REPO_URL" ] || [ -z "$TEST_DIR" ]; then
    echo "Usage: $0 <cpu_name> <repo_url> <test_dir>"
    echo "  cpu_name: CPU model (e.g., 8088, 80286)"
    echo "  repo_url: Git repository URL"
    echo "  test_dir: Directory containing tests (e.g., v2 or v1_real_mode)"
    exit 1
fi

REPO_DIR="${CPU_NAME}-repo"
TESTS_DIR="${CPU_NAME}-tests"

echo "================================================"
echo "Extracting ${CPU_NAME} Tests"
echo "================================================"

# Clone repository
echo "Cloning ${REPO_URL}..."
git clone "$REPO_URL" "$REPO_DIR"

# Get version information from git
cd "$REPO_DIR"
COMMIT_DATE=$(git log -1 --format=%cd --date=format:'%Y.%-m.%-d')
COMMIT_HASH=$(git rev-parse --short HEAD)
COMMIT_DATE_FULL=$(git log -1 --format=%cd --date=iso8601)
cd ..

echo "Version: $COMMIT_DATE"
echo "Commit: $COMMIT_HASH ($COMMIT_DATE_FULL)"

# Export for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "VERSION=$COMMIT_DATE" >> "$GITHUB_OUTPUT"
    echo "COMMIT_HASH=$COMMIT_HASH" >> "$GITHUB_OUTPUT"
    echo "COMMIT_DATE_FULL=$COMMIT_DATE_FULL" >> "$GITHUB_OUTPUT"
fi

# Create output directory
mkdir -p "$TESTS_DIR"

# Step 1: Extract all .gz files
echo "Extracting .gz files from ${TEST_DIR}..."
cd "${REPO_DIR}/${TEST_DIR}"
for gzfile in *.gz; do
    if [ -f "$gzfile" ]; then
        extracted_name=$(basename "$gzfile" .gz)
        echo "  Extracting $gzfile -> $extracted_name"
        gunzip -c "$gzfile" > "../../${TESTS_DIR}/${extracted_name}"
        # Remove .gz file after successful extraction to save space
        rm "$gzfile"
    fi
done
cd ../..

# Step 2: Process extracted files - convert MOO to JSON if needed
echo "Processing extracted files..."
has_moo_files=false
for file in "${TESTS_DIR}"/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        
        # Check if it's a JSON file (already good)
        if [[ "$filename" == *.json ]]; then
            echo "  ✓ $filename (already JSON)"
            continue
        fi
        
        # Check if it's a MOO file (needs conversion)
        if [[ "$filename" == *.moo ]] || [[ "$filename" == *.MOO ]]; then
            has_moo_files=true
            # Remove extension (case-insensitive)
            basename_no_ext="${filename%.moo}"
            basename_no_ext="${basename_no_ext%.MOO}"
            
            echo "  Converting $filename to ${basename_no_ext}.json..."
            python3 "${SCRIPT_DIR}/moo2json.py" "$file" "${TESTS_DIR}/${basename_no_ext}.json"
            
            # Remove the .moo file after successful conversion
            rm "$file"
        fi
    fi
done

if [ "$has_moo_files" = true ]; then
    echo "MOO to JSON conversion completed"
fi

# Copy LICENSE file
echo "Copying LICENSE..."
cp "${REPO_DIR}/LICENSE" "${TESTS_DIR}/SingleStepTests-LICENSE"

# Copy revocation list if it exists
if [ -f "${REPO_DIR}/revocation_list.txt" ]; then
    echo "Copying revocation_list.txt..."
    cp "${REPO_DIR}/revocation_list.txt" "${TESTS_DIR}/revocation_list.txt"
else
    touch "${TESTS_DIR}/revocation_list.txt"
fi

# Count extracted test files
test_count=$(find "${TESTS_DIR}" -name "*.json" | wc -l)

# Clean up cloned repository to save disk space
echo "Cleaning up cloned repository..."
rm -rf "${REPO_DIR}"
echo "✓ Removed ${REPO_DIR}/"

echo "================================================"
echo "Extraction complete: ${test_count} test files"
echo "Output directory: ${TESTS_DIR}/"
echo "Version: ${COMMIT_DATE}"
echo "Commit: ${COMMIT_HASH}"
echo "================================================"
