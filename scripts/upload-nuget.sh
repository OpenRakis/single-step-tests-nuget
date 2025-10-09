#!/bin/bash
set -euo pipefail

################################################################################
# upload-nuget.sh
#
# Purpose: Upload all created NuGet packages (.nupkg) to NuGet.org. This script
#          finds all package files and publishes them using the dotnet CLI.
#
# Responsibilities:
#   - Find all .nupkg files in nuget-* directories
#   - Upload each package to NuGet.org
#   - Skip duplicates if package version already exists
#   - Report success/failure for each upload
#
# Usage: ./upload-nuget.sh <api_key>
#
# Arguments:
#   api_key: NuGet.org API key for authentication
#
# Environment Variables:
#   NUGET_API_KEY: Alternative to passing API key as argument (more secure)
#
# Input:
#   - Package files: nuget-*/*.nupkg (created by package-nuget.sh)
#
# Examples:
#   ./upload-nuget.sh $NUGET_API_KEY
#   NUGET_API_KEY=abc123 ./upload-nuget.sh
#
# Notes:
#   - Uses --skip-duplicate to avoid errors if version already exists
#   - Returns non-zero exit code if any upload fails
################################################################################

API_KEY=$1

# Allow API key from environment variable
if [ -z "$API_KEY" ]; then
    API_KEY="$NUGET_API_KEY"
fi

if [ -z "$API_KEY" ]; then
    echo "Usage: $0 <api_key>"
    echo "  api_key: NuGet.org API key"
    echo ""
    echo "Or set NUGET_API_KEY environment variable:"
    echo "  export NUGET_API_KEY=your_key"
    echo "  $0"
    exit 1
fi

echo "================================================"
echo "Uploading NuGet Packages"
echo "================================================"

# Find all .nupkg files
shopt -s nullglob
packages=(nuget-*/*.nupkg)
shopt -u nullglob

if [ ${#packages[@]} -eq 0 ]; then
    echo "Error: No .nupkg files found."
    echo "Please run package-nuget.sh first."
    exit 1
fi

echo "Found ${#packages[@]} package(s) to upload"
echo ""

# Track upload results
upload_count=0
skip_count=0
error_count=0

# Upload each package
for package in "${packages[@]}"; do
    if [ -f "$package" ]; then
        package_name=$(basename "$package")
        echo "Uploading: $package_name"
        
        if dotnet nuget push "$package" \
            --api-key "$API_KEY" \
            --source https://api.nuget.org/v3/index.json \
            --skip-duplicate 2>&1 | tee /tmp/nuget-upload.log; then
            
            # Check if it was skipped or uploaded
            if grep -q "already exists" /tmp/nuget-upload.log || grep -q "duplicate" /tmp/nuget-upload.log; then
                echo "  ⊘ Skipped (already exists)"
                skip_count=$((skip_count + 1))
            else
                echo "  ✓ Uploaded successfully"
                upload_count=$((upload_count + 1))
            fi
        else
            echo "  ✗ Upload failed"
            error_count=$((error_count + 1))
        fi
        echo ""
    fi
done

# Clean up temp file
rm -f /tmp/nuget-upload.log

# Print summary
echo "================================================"
echo "Upload Summary"
echo "================================================"
echo "  Uploaded: $upload_count"
echo "  Skipped:  $skip_count"
echo "  Failed:   $error_count"
echo "================================================"

if [ $error_count -gt 0 ]; then
    echo "❌ Some uploads failed"
    exit 1
else
    echo "✅ All packages processed successfully"
fi
