#!/usr/bin/env bash

#
# sign_docs.sh – DOCUMENT SIGNING & INTEGRITY SEALER
#
# Author:  © 2026 sandokan.cat – https://sandokan.cat
# License: MIT – https://opensource.org/licenses/MIT
# Version: 1.1.0
# Date:    2026-01-24
#
# Description:
# Prepares a directory of PDFs for distribution by:
# 1. Formatting directory structure (pdf_signed, pgp_asc).
# 2. PGP signing each PDF.
# 3. Generating SHA-512 hashes.
# 4. Signing the hash manifest.
# 5. Exporting the public key.
# 6. (Optional) TSA timestamping of the manifest.
#

set -euo pipefail

# === OUTPUT COLORS ===
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

# === GLOBAL CONFIG ===
INPUT_DIR=""
OUTPUT_DIR=""
GPG_USER=""
TSA_URL=""
INITIAL_PWD="$PWD"

# === CONSTANTS ===
HASH_FILE="SHA512SUMS"
HASH_SIG="SHA512SUMS.asc"
PUB_KEY="publickey.asc"
TSA_REQ="SHA512SUMS.tsq"
TSA_RESP="SHA512SUMS.tsr"

# === UTILITIES ===

print_step() {
    printf "\n=== %s ===\n" "$1"
}

relpath() {
    realpath --relative-to="$INITIAL_PWD" "$1"
}

error_exit() {
    printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1"
    exit 1
}

usage() {
    printf "Usage: %s -i INPUT_DIR -o OUTPUT_DIR -u GPG_USER_ID [-t TSA_URL]\n" "$(basename "$0")"
    printf "  -i, --input    Source directory containing PDFs\n"
    printf "  -o, --output   Destination directory for signed artifacts\n"
    printf "  -u, --user     GPG Key ID or Email to sign with\n"
    printf "  -t, --tsa      (Optional) TSA URL for timestamping\n"
    exit 0
}

# === ARGUMENT PARSING ===
if [[ $# -eq 0 ]]; then
    usage
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input)
            INPUT_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -u|--user)
            GPG_USER="$2"
            shift 2
            ;;
        -t|--tsa)
            TSA_URL="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            error_exit "Unknown argument: $1"
            ;;
    esac
done

# === VALIDATION ===
[[ -n "$INPUT_DIR" ]] || error_exit "Input directory is required"
[[ -n "$OUTPUT_DIR" ]] || error_exit "Output directory is required"
[[ -n "$GPG_USER" ]] || error_exit "GPG user ID is required"

[[ -d "$INPUT_DIR" ]] || error_exit "Input directory not found: $INPUT_DIR"

# === SETUP PATHS ===
INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

PDF_DEST="$OUTPUT_DIR/pdf_signed"
ASC_DEST="$OUTPUT_DIR/pgp_asc"

# === 1. PREPARE DIRECTORIES ===
print_step "Preparing directory structure"
mkdir -p "$PDF_DEST"
mkdir -p "$ASC_DEST"

# Display created paths (Green label, Cyan path)
printf "%b[CREATED] %b%s%b\n" "$GREEN" "$CYAN" "$(relpath "$PDF_DEST")" "$NC"
printf "%b[CREATED] %b%s%b\n" "$GREEN" "$CYAN" "$(relpath "$ASC_DEST")" "$NC"

# === 2. COPY AND SIGN PDFS ===
print_step "Signing PDFs with PGP key"

# Use find to locate PDFs and process them
find "$INPUT_DIR" -type f -name "*.pdf" | while read -r pdf; do
    filename=$(basename "$pdf")
    target_pdf="$PDF_DEST/$filename"
    
    # Copy file
    cp "$pdf" "$target_pdf"
    
    # Sign file (Detach Sign)
    # --yes to overwrite without asking
    asc_name="$filename.asc"
    if gpg --batch --yes --default-key "$GPG_USER" --armor --detach-sign --output "$ASC_DEST/$asc_name" "$target_pdf" 2>/dev/null; then
        printf "%b[SIGNED] %b%s%b\n" "$GREEN" "$CYAN" "$asc_name" "$NC"
    else
        printf "%b[FAIL] %b%s%b\n" "$RED" "$CYAN" "$filename" "$NC"
    fi
done

# === 3. GENERATE CHECKSUMS ===
print_step "Generating SHA-512 Checksums"

cd "$OUTPUT_DIR"
# Calculate hashes for files in pdf_signed and pgp_asc
find "pdf_signed" "pgp_asc" -type f -print0 | xargs -0 sha512sum > "$HASH_FILE"

printf "%b[HASHED] %b%s%b\n" "$GREEN" "$CYAN" "$HASH_FILE" "$NC"

# === 4. SIGN MANIFEST ===
print_step "Signing Manifest"
gpg --batch --yes --default-key "$GPG_USER" --armor --detach-sign --output "$HASH_SIG" "$HASH_FILE" 2>/dev/null
printf "%b[SIGNED] %b%s%b\n" "$GREEN" "$CYAN" "$HASH_SIG" "$NC"

# === 5. EXPORT PUBLIC KEY ===
print_step "Exporting Public Key"
gpg --armor --export "$GPG_USER" > "$PUB_KEY" 2>/dev/null
printf "%b[EXPORTED] %b%s%b\n" "$GREEN" "$CYAN" "$PUB_KEY" "$NC"

# === 6. TSA TIMESTAMP (OPTIONAL) ===
if [[ -n "$TSA_URL" ]]; then
    print_step "Requesting TSA Timestamp"
    
    # Check for openssl dependency
    if command -v openssl >/dev/null; then
        # Create Query
        openssl ts -query -data "$HASH_FILE" -sha512 -out "$TSA_REQ"
        
        # Send Query (via curl)
        if command -v curl >/dev/null; then
            curl -H "Content-Type: application/timestamp-query" --data-binary @"$TSA_REQ" "$TSA_URL" -o "$TSA_RESP" --fail --silent
            if [[ -f "$TSA_RESP" ]]; then
                printf "%b[TIMESTAMPED] TSA response saved to %b%s%b\n" "$GREEN" "$CYAN" "$TSA_RESP" "$NC"
                rm "$TSA_REQ"
            else
                printf "%b[FAIL] Could not fetch timestamp from %b%s%b\n" "$RED" "$CYAN" "$TSA_URL" "$NC"
            fi
        else
            printf "%b[WARN] curl not found, skipping TSA network request%b\n" "$YELLOW" "$NC"
        fi
    else
        printf "%b[WARN] openssl not found, skipping TSA%b\n" "$YELLOW" "$NC"
    fi
fi

# === SUMMARY ===
print_step "Summary"
printf "%b[DONE] Output ready in: %b%s%b\n" "$GREEN" "$CYAN" "$(relpath "$OUTPUT_DIR")" "$NC"

print_step "Reminder"
printf "You can verify this output using %bcheck_docs.sh%b\n\n" "$CYAN" "$NC"
