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
#          or sub-range for specific opcode (e.g., 67.00-67.7F)
#
# Input:
#   - Directory: ${cpu_name}-tests/ (created by extract-tests.sh)
#
# Output:
#   - ZIP file: ${cpu_name}.${range}.zip containing filtered test files
#
# Examples:
#   ./split-tests.sh 8088 00-3F     # Creates 8088.00-3F.zip with opcodes 0x00-0x3F
#   ./split-tests.sh 8088 40-7F     # Creates 8088.40-7F.zip with opcodes 0x40-0x7F
#   ./split-tests.sh 80286 00-FF    # Creates 80286.00-FF.zip with all opcodes
#   ./split-tests.sh 80386 67.00-67.7F # Creates 80386.67.00-67.7F.zip with opcode 0x67, sub-range 0x00-0x7F
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
# Detect if this is a sub-range (contains dots) or standard range
if [[ "$RANGE" == *.* ]]; then
    # Sub-range format: 67.00-67.7F
    IS_SUBRANGE=true
    # Extract opcode prefix (before first dot)
    OPCODE_PREFIX="${RANGE%%.*}"
    # Extract the sub-range part (after first dot, before dash)
    # Example: "67.00-67.7F" -> extract "00" and "7F"
    TEMP="${RANGE#*.}"           # Remove "67." -> "00-67.7F"
    RANGE_START_HEX="${TEMP%%-*}"  # Get part before dash -> "00"
    TEMP="${RANGE##*-}"          # Get part after last dash -> "67.7F"
    RANGE_END_HEX="${TEMP#*.}"   # Remove "67." -> "7F"
    RANGE_START=$((16#${RANGE_START_HEX}))
    RANGE_END=$((16#${RANGE_END_HEX}))
else
    # Standard range format: 00-3F
    IS_SUBRANGE=false
    RANGE_START_HEX="${RANGE%-*}"
    RANGE_END_HEX="${RANGE#*-}"
    RANGE_START=$((16#${RANGE_START_HEX}))
    RANGE_END=$((16#${RANGE_END_HEX}))
fi

SOURCE_TESTS_DIR="${CPU_NAME}-tests"
RANGE_TESTS_DIR="${CPU_NAME}-tests-${RANGE}"
ZIP_NAME="${CPU_NAME}.${RANGE}.zip"

echo "================================================"
echo "Splitting ${CPU_NAME} Tests for Range ${RANGE}"
echo "================================================"
if [ "$IS_SUBRANGE" = true ]; then
    echo "Sub-range: Opcode 0x${OPCODE_PREFIX}, sub-values 0x${RANGE_START_HEX}-0x${RANGE_END_HEX} (${RANGE_START}-${RANGE_END} decimal)"
else
    echo "Range: 0x${RANGE_START_HEX}-0x${RANGE_END_HEX} (${RANGE_START}-${RANGE_END} decimal)"
fi

# Function to check if a file is in the specified range
# Returns: 0 (success) if in range, 1 (failure) if not in range
# Sets global variables: CHECK_RESULT_MSG (message to display)
check_file_in_range() {
    local filename="$1"
    
    # Extract hex opcode from filename
    # Supports: "3F.json", "F6.0.json", "F6.1.json", "67660FBF.json", etc.
    if [[ "$filename" =~ ^([0-9a-fA-F]+)(\..+)?\.json$ ]]; then
        local full_hex="${BASH_REMATCH[1]}"
        local hex_opcode="${full_hex:0:2}"
        
        if [ "$IS_SUBRANGE" = true ]; then
            # Sub-range mode: check if opcode matches prefix, then check sub-range
            if [ "${hex_opcode^^}" = "${OPCODE_PREFIX^^}" ]; then
                # Extract next 2 hex digits for sub-range comparison (positions 2-4)
                if [ ${#full_hex} -ge 4 ]; then
                    local sub_hex="${full_hex:2:2}"
                    local decimal_value=$((16#${sub_hex}))
                    
                    if [ $decimal_value -ge $RANGE_START ] && [ $decimal_value -le $RANGE_END ]; then
                        CHECK_RESULT_MSG="✓ $filename (opcode 0x$hex_opcode, sub 0x$sub_hex = $decimal_value) - IN RANGE"
                        return 0
                    else
                        CHECK_RESULT_MSG="✗ $filename (opcode 0x$hex_opcode, sub 0x$sub_hex = $decimal_value) - OUT OF RANGE"
                        return 1
                    fi
                else
                    CHECK_RESULT_MSG="⊘ $filename - INSUFFICIENT DIGITS FOR SUB-RANGE (skipping)"
                    return 1
                fi
            else
                CHECK_RESULT_MSG="✗ $filename (opcode 0x$hex_opcode) - OUT OF RANGE"
                return 1
            fi
        else
            # Standard range mode: compare opcode only
            local decimal_value=$((16#${hex_opcode}))
            
            if [ $decimal_value -ge $RANGE_START ] && [ $decimal_value -le $RANGE_END ]; then
                CHECK_RESULT_MSG="✓ $filename (opcode 0x$hex_opcode = $decimal_value) - IN RANGE"
                return 0
            else
                CHECK_RESULT_MSG="✗ $filename (opcode 0x$hex_opcode = $decimal_value) - OUT OF RANGE"
                return 1
            fi
        fi
    else
        CHECK_RESULT_MSG="⊘ $filename - NOT AN OPCODE FILE (skipping)"
        return 1
    fi
}

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
        
        if check_file_in_range "$filename"; then
            echo "  $CHECK_RESULT_MSG"
            mv "$jsonfile" "${RANGE_TESTS_DIR}/"
            file_count=$((file_count + 1))
        else
            echo "  $CHECK_RESULT_MSG"
            skipped_count=$((skipped_count + 1))
        fi
    fi
done

# Copy LICENSE file
if [ -f "${SOURCE_TESTS_DIR}/SingleStepTests-LICENSE" ]; then
    cp "${SOURCE_TESTS_DIR}/SingleStepTests-LICENSE" "${RANGE_TESTS_DIR}/"
fi
# Copy revocation list
cp "${SOURCE_TESTS_DIR}/revocation_list.txt" "${RANGE_TESTS_DIR}/"

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
