#!/bin/bash
set -euo pipefail

################################################################################
# split-tests.sh
#
# Purpose: Filter test files by opcode range and create a ZIP archive for
#          NuGet package distribution. This script takes all extracted test
#          files and creates a range-specific subset.
#
# Responsibilities:
#   - Parse hexadecimal range boundaries (e.g., 00-3F)
#   - Filter test files by opcode (based on filename)
#   - Copy files matching the range to a temporary directory
#   - Create a ZIP archive containing only the range-specific tests
#
# Usage: ./split-tests.sh <cpu_name> <range>
#
# Arguments:
#   cpu_name: CPU model (e.g., 8088, 80286)
#   range: Hexadecimal opcode range (e.g., 00-3F, 40-7F, 00-FF)
#
# Input:
#   - Directory: ${cpu_name}-tests/ (created by extract-tests.sh)
#
# Output:
#   - ZIP file: ${cpu_name}.${range}.zip containing filtered test files
#
# Examples:
#   ./split-tests.sh 8088 00-3F  # Creates 8088.00-3F.zip with opcodes 0x00-0x3F
#   ./split-tests.sh 8088 40-7F  # Creates 8088.40-7F.zip with opcodes 0x40-0x7F
#   ./split-tests.sh 80286 00-FF # Creates 80286.00-FF.zip with all opcodes
################################################################################

CPU_NAME=$1
RANGE=$2

if [ -z "$CPU_NAME" ] || [ -z "$RANGE" ]; then
    echo "Usage: $0 <cpu_name> <range>"
    echo "  cpu_name: CPU model (e.g., 8088, 80286)"
    echo "  range: Hexadecimal opcode range (e.g., 00-3F, 40-7F, 00-FF)"
    exit 1
fi

# Parse range boundaries (convert hex to decimal for comparison)
RANGE_START_HEX="${RANGE%-*}"
RANGE_END_HEX="${RANGE#*-}"
RANGE_START=$((16#${RANGE_START_HEX}))
RANGE_END=$((16#${RANGE_END_HEX}))

SOURCE_TESTS_DIR="${CPU_NAME}-tests"
RANGE_TESTS_DIR="${CPU_NAME}-tests-${RANGE}"
ZIP_NAME="${CPU_NAME}.${RANGE}.zip"

echo "================================================"
echo "Splitting ${CPU_NAME} Tests for Range ${RANGE}"
echo "================================================"
echo "Range: 0x${RANGE_START_HEX}-0x${RANGE_END_HEX} (${RANGE_START}-${RANGE_END} decimal)"

# Validate source directory exists
if [ ! -d "$SOURCE_TESTS_DIR" ]; then
    echo "Error: Source directory '${SOURCE_TESTS_DIR}' not found."
    echo "Please run extract-tests.sh first."
    exit 1
fi

# Filter test files by range
echo "Filtering test files..."
mkdir -p "${RANGE_TESTS_DIR}"

file_count=0
skipped_count=0
for jsonfile in "${SOURCE_TESTS_DIR}"/*.json; do
    if [ -f "$jsonfile" ]; then
        filename=$(basename "$jsonfile")
        
        # Extract hex opcode from filename
        # Supports: "3F.json", "F6.0.json", "F6.1.json", etc.
        if [[ "$filename" =~ ^([0-9a-fA-F]+)(\..+)?\.json$ ]]; then
            hex_opcode="${BASH_REMATCH[1]}"
            # Convert hex to decimal
            decimal_value=$((16#${hex_opcode}))
            
            # Check if opcode is within the specified range
            if [ $decimal_value -ge $RANGE_START ] && [ $decimal_value -le $RANGE_END ]; then
                echo "  ✓ $filename (opcode 0x$hex_opcode = $decimal_value) - IN RANGE"
                mv "$jsonfile" "${RANGE_TESTS_DIR}/"
                file_count=$((file_count + 1))
            else
                echo "  ✗ $filename (opcode 0x$hex_opcode = $decimal_value) - OUT OF RANGE"
                skipped_count=$((skipped_count + 1))
            fi
        else
            echo "  ⊘ $filename - NOT AN OPCODE FILE (skipping)"
        fi
    fi
done

# Copy LICENSE file
if [ -f "${SOURCE_TESTS_DIR}/SingleStepTests-LICENSE" ]; then
    cp "${SOURCE_TESTS_DIR}/SingleStepTests-LICENSE" "${RANGE_TESTS_DIR}/"
fi

echo ""
echo "Summary: $file_count included, $skipped_count skipped"

# Create ZIP archive
echo "Creating ${ZIP_NAME}..."
cd "${RANGE_TESTS_DIR}"
zip -q -r "../${ZIP_NAME}" .
cd ..

# Get zip file size
zip_size=$(du -h "$ZIP_NAME" | cut -f1)

echo "================================================"
echo "ZIP created: ${ZIP_NAME} (${zip_size})"
echo "Included: $file_count test files for opcodes 0x${RANGE_START_HEX}-0x${RANGE_END_HEX}"
echo "Skipped:  $skipped_count test files outside range"
echo "================================================"
