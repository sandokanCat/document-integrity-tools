#!/usr/bin/env bash
# ⏱ VERIFIED DOCUMENTS CHECKER
# Script to verify PGP, SHA-512 hashes, TSA timestamp and FNMT PAdES signatures
# Intended for Linux/macOS/WSL. Windows users should use WSL or PowerShell equivalent.

set -euo pipefail

# ===== Colors for output =====
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

# ===== Files & directories =====
PUB_KEY="publickey.asc"
HASH_FILE="SHA512SUMS"
HASH_SIG="SHA512SUMS.asc"
TSA_FILE="SHA512SUMS.tsr"
TSA_CERT="fnmt-tsa.pem" # Optional
PDF_DIR="pdf_signed"
PGP_DIR="pgp_asc"

# ===== Flags =====
FAILED=0

# ===== Functions =====

print_step() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

check_file_mandatory() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        FAILED=$((FAILED+1))
        echo -e "${RED}[ERROR] File not found: $file${NC}"
        exit 1
    fi
}

check_file_optional() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}[SKIPPED] Optional file not found: $file${NC}"
        return 1
    fi
    return 0
}

# ===== 0. Import public PGP key =====
print_step "Importing public PGP key"
if check_file_mandatory "$PUB_KEY"; then
    gpg --import $PUB_KEY >/dev/null 2>&1 || true
    echo -e "${GREEN}[OK] '$PUB_KEY'${NC}"
fi

# ===== 1. Verify global PGP signature of manifest =====
print_step "Verifying manifest PGP signature"
if check_file_mandatory "$HASH_SIG"; then
    if gpg --verify "$HASH_SIG" "$HASH_FILE" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] '$HASH_SIG' for '$HASH_FILE'${NC}"
    else
        FAILED=$((FAILED+1))
        echo -e "${RED}[FAILED] '$HASH_SIG' for '$HASH_FILE'${NC}"
    fi
fi

# ===== 1b. Optional TSA verification =====
print_step "Verifying TSA timestamp (optional)"
if check_file_optional "$TSA_FILE" && check_file_optional "$TSA_CERT"; then
    if openssl ts -verify -in "$TSA_FILE" -data "$HASH_FILE" -CAfile "$TSA_CERT" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] '$TSA_CERT' for '$TSA_FILE'${NC}"
    else
        FAILED=$((FAILED+1))
        echo -e "${RED}[FAILED] '$TSA_CERT' for '$TSA_FILE'${NC}"
    fi
else
    echo "Skipping TSA verification"
fi

# ===== 2. Verify SHA-512 hashes =====
print_step "Verifying SHA-512 hashes on all files"
if check_file_mandatory "$HASH_FILE"; then
    while read -r line; do
        file=$(echo "$line" | awk '{print $2}')
        target=""
        if [ -f "$PDF_DIR/$file" ]; then
            target="$PDF_DIR/$file"
        elif [ -f "$PGP_DIR/$file" ]; then
            target="$PGP_DIR/$file"
        else
            FAILED=$((FAILED+1))
            echo -e "${RED}[ERROR] File not found: $file${NC}"
            continue
        fi

        result=$(LANG=C sha512sum -c <(echo "$line" | sed "s|$file|$target|") 2>&1)
        status=$(echo "$result" | grep -o "OK\|FAILED")

        if [ "$status" == "OK" ]; then
            echo -e "${GREEN}[OK] $file${NC}"
        else
            FAILED=$((FAILED+1))
            echo -e "${RED}[FAILED] $file${NC}"
        fi
    done < "$HASH_FILE"
fi

# ===== 3. Verify PGP signatures on documents =====
print_step "Verifying PGP signatures on documents"
if [[ -d "$PGP_DIR" && -d "$PDF_DIR" ]]; then
    for asc in "$PGP_DIR"/*.asc; do
        pdf="$PDF_DIR/$(basename "$asc" .asc)"
        
        if [ ! -f "$pdf" ]; then
            echo -e "${RED}[ERROR] '$pdf' missing for '$asc', skipping${NC}"
            continue
        fi

        if gpg --verify "$asc" "$pdf" >/dev/null 2>&1; then
            echo -e "${GREEN}[OK] '$asc' for '$pdf'${NC}"
        else
            FAILED=$((FAILED+1))
            echo -e "${RED}[FAILED] '$asc' for '$pdf'${NC}"
        fi
    done
else
    FAILED=$((FAILED+1))
    echo -e "${RED}[ERROR] '$PGP_DIR' or '$PDF_DIR' directories missing. Skipping document PGP verification.${NC}"
fi

# ===== Summary =====
print_step "Summary"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] All checks completed successfully.${NC}"
else
    echo -e "${RED}[WARNING] $FAILED checks failed. Please review above.${NC}"
fi

print_step "Reminder"
echo "FNMT PAdES signatures must be verified visually in a PDF reader."
