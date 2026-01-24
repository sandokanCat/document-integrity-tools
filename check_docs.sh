#!/usr/bin/env bash

#
# check_docs.sh – VERIFIED DOCUMENTS CHECKER
#
# Author:  © 2026 sandokan.cat – https://sandokan.cat
# License: MIT – https://opensource.org/licenses/MIT
# Version: 1.3.0
# Date:    2026-01-23
#
# Description:
# Verifies PGP signatures, SHA-512 hashes, TSA timestamps,
# and FNMT PAdES signatures across a document repository.
#
# Supported on Linux, macOS and WSL.
#

set -euo pipefail

# === OUTPUT COLORS ===
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

# === GLOBAL STATE ===
CHECK_DIR=""
FAILED=0

# === UTILITIES ===

print_step() {
    printf "\n=== %s ===\n" "$1"
}

error_exit() {
    printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1"
    exit 1
}

usage() {
    printf "Usage: %s -i INPUT_DIR\n" "$(basename "$0")"
    printf "  -i, --input   Root 'doc' directory to verify\n"
    exit 0
}

relpath() {
    realpath --relative-to="$CHECK_DIR" "$1"
}

check_file_mandatory() {
    [[ -f "$1" ]] || error_exit "File not found: $(printf "%b%s%b" "$CYAN" "$(relpath "$1")" "$NC")"
}

check_file_optional() {
    [[ -f "$1" ]]
}

# === ARGUMENT PARSING ===
if [[ $# -eq 0 ]]; then
    usage
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input)
            CHECK_DIR="$2"
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

# === INITIAL SETUP ===
[[ -n "$CHECK_DIR" ]] || error_exit "Input directory is required"
[[ -d "$CHECK_DIR" ]] || error_exit "Input directory not found: $(printf "%b%s%b" "$CYAN" "$CHECK_DIR" "$NC")"
CHECK_DIR="$(cd "$CHECK_DIR" && pwd)"

PDF_DIR="$CHECK_DIR/pdf_signed"
PGP_DIR="$CHECK_DIR/pgp_asc"
PUB_KEY="$CHECK_DIR/publickey.asc"
HASH_FILE="$CHECK_DIR/SHA512SUMS"
HASH_SIG="$CHECK_DIR/SHA512SUMS.asc"
TSA_FILE="$CHECK_DIR/SHA512SUMS.tsr"
TSA_CERT="$CHECK_DIR/fnmt-tsa.pem"

# === 0. IMPORT PGP KEY ===
print_step "Importing public PGP key"
check_file_mandatory "$PUB_KEY"
gpg --import "$PUB_KEY" >/dev/null 2>&1 || true
printf "%b[IMPORTED]%b %b%s%b\n" "$GREEN" "$NC" "$CYAN" "$(relpath "$PUB_KEY")" "$NC"

# === 1. VERIFY MANIFEST SIGNATURE ===
print_step "Verifying manifest PGP signature"
check_file_mandatory "$HASH_SIG"

if gpg --verify "$HASH_SIG" "$HASH_FILE" >/dev/null 2>&1; then
    printf "%b[VERIFIED]%b %b%s%b\n" "$GREEN" "$NC" "$CYAN" "$(relpath "$HASH_SIG")" "$NC"
else
    FAILED=$((FAILED + 1))
    printf "%b[FAIL]%b %b%s%b\n" "$RED" "$NC" "$CYAN" "$(relpath "$HASH_SIG")" "$NC"
fi

# === 1b. TSA VERIFICATION (OPTIONAL) ===
print_step "Verifying TSA timestamp (optional)"
if check_file_optional "$TSA_FILE" && check_file_optional "$TSA_CERT"; then
    if openssl ts -verify -in "$TSA_FILE" -data "$HASH_FILE" -CAfile "$TSA_CERT" >/dev/null 2>&1; then
        printf "%b[VERIFIED] TSA timestamp%b\n" "$GREEN" "$NC"
    else
        FAILED=$((FAILED + 1))
        printf "%b[FAIL] TSA verification failed%b\n" "$RED" "$NC"
    fi
else
    printf "%b[SKIPPED] TSA files not found%b\n" "$YELLOW" "$NC"
fi

# === 2. VERIFY SHA-512 HASHES ===
print_step "Verifying SHA-512 hashes"
check_file_mandatory "$HASH_FILE"

while read -r hash file; do
    target=""
    # First, try file relative to CHECK_DIR (standard behavior)
    [[ -f "$CHECK_DIR/$file" ]] && target="$CHECK_DIR/$file"
    
    # Fallback/Legacy: Check in specific dirs if not found and file has no path info
    if [[ -z "$target" ]]; then
        [[ -f "$PDF_DIR/$file" ]] && target="$PDF_DIR/$file"
        [[ -f "$PGP_DIR/$file" ]] && target="$PGP_DIR/$file"
    fi

    if [[ -z "$target" ]]; then
        FAILED=$((FAILED + 1))
        printf "%b[ERROR]%b %b%s%b\n" "$RED" "$NC" "$CYAN" "$file" "$NC"
        continue
    fi

    if printf "%s  %s\n" "$hash" "$target" | sha512sum -c --quiet; then
        printf "%b[VERIFIED]%b %b%s%b\n" "$GREEN" "$NC" "$CYAN" "$file" "$NC"
    else
        FAILED=$((FAILED + 1))
        printf "%b[FAIL]%b %b%s%b\n" "$RED" "$NC" "$CYAN" "$file" "$NC"
    fi
done < "$HASH_FILE"

# === 3. VERIFY DOCUMENT PGP SIGNATURES ===
print_step "Verifying document PGP signatures"

if [[ -d "$PGP_DIR" && -d "$PDF_DIR" ]]; then
    for asc in "$PGP_DIR"/*.asc; do
        pdf="$PDF_DIR/$(basename "$asc" .asc)"

        if [[ ! -f "$pdf" ]]; then
            FAILED=$((FAILED + 1))
            printf "%b[ERROR]%b Missing %b%s%b\n" "$RED" "$NC" "$CYAN" "$(relpath "$pdf")" "$NC"
            continue
        fi

        if gpg --verify "$asc" "$pdf" >/dev/null 2>&1; then
            printf "%b[VERIFIED]%b %b%s%b\n" "$GREEN" "$NC" "$CYAN" "$(relpath "$pdf")" "$NC"
        else
            FAILED=$((FAILED + 1))
            printf "%b[FAIL]%b %b%s%b\n" "$RED" "$NC" "$CYAN" "$(relpath "$pdf")" "$NC"
        fi
    done
else
    error_exit "PGP or PDF directories missing"
fi

# === SUMMARY ===
print_step "Summary"
if [[ $FAILED -eq 0 ]]; then
    printf "%b[DONE] All checks passed%b\n" "$GREEN" "$NC"
else
    printf "%b[WARN] %d checks failed%b\n" "$YELLOW" "$FAILED" "$NC"
fi

print_step "Reminder"
printf "%bFNMT PAdES signatures must be verified visually in a PDF reader.%b\n\n" "$NC" "$NC"
