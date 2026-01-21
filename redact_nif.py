#!/usr/bin/env python3

"""
RECURSIVE PDF DNI REDACTION
- SCANS ALL PDF(s) IN A DIRECTORY TREE
- REDACTS ALL VALID SPANISH NIFs/NIEs
- OUTPUTS SAFE COPIES ONLY
"""

from pathlib import Path
import fitz  # PyMuPDF
import re

# ==============================
# OUTPUT COLORS
# ==============================
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
NC = "\033[0m"

# ==============================
# GLOBAL CONFIG
# ==============================
NIF_REGEX = re.compile(r'\b([XYZ]?\d{7,8}[A-Z])\b', re.IGNORECASE)
ALPHA_LIST = "TRWAGMYFPDXBNJZSQVHLCKE"

# ==============================
# AUTO-RESOLVE INPUT DIR
# ==============================
def resolve_input_dir(script_dir: Path, target_name="doc", max_levels=5) -> Path:
    current = script_dir
    for _ in range(max_levels):
        candidate = current / target_name
        if candidate.is_dir():
            return candidate.resolve()
        current = current.parent
    raise FileNotFoundError(f"Could not locale '{target_name}' folder in repo hierarchy")

SCRIPT_DIR = Path(__file__).parent.resolve()
try:
    INPUT_DIR = resolve_input_dir(SCRIPT_DIR, "doc", 5)
except FileNotFoundError as e:
    print(f"{RED}[ERROR] {e}{NC}")
    exit(1)

OUTPUT_DIR = INPUT_DIR.parent / "redacted_output"

# ==============================
# CORE FUNCTION
# ==============================
def redact_pdf(input_pdf: Path, output_pdf: Path):
    doc = fitz.open(input_pdf)
    found = False
    redacted_count = 0

    for page_number, page in enumerate(doc, start=1):
        page_redacted = 0
        text = page.get_text("text")
        for match in NIF_REGEX.findall(text):
            candidate = match.upper()

            # --------------------------
            # VALIDATE NIF/NIE
            # --------------------------
            letter = candidate[-1]
            number = int(candidate[:-1].replace("X", "0").replace("Y", "1").replace("Z", "2"))
            correct_letter = ALPHA_LIST[number % 23]
            if letter != correct_letter:
                print(f"{YELLOW}[WARNING] Invalid NIF '{match}' on page {page_number}{NC}")
                continue

            # --------------------------
            # REDACT IN PDF
            # --------------------------
            rects = page.search_for(candidate)
            for rect in rects:
                page.add_redact_annot(rect, fill=(0, 0, 0))
                found = True
                page_redacted += 1 

        # APPLY ALL REDACTIONS FOR THIS PAGE
        page.apply_redactions()
        if page_redacted > 0:
            print(f"{GREEN}[PAGE {page_number}] Redacted {page_redacted} NIF(s){NC}")
            found = True
            redacted_count += page_redacted

    # SAVE REDACTED PDF
    output_pdf.parent.mkdir(parents=True, exist_ok=True)
    doc.save(output_pdf)
    doc.close()

    if found:
        print(f"{GREEN}[REDACTED {redacted_count}] {input_pdf}{NC}")
    else:
        print(f"{YELLOW}[NO MATCH] {input_pdf}{NC}")

# ==============================
# MAIN
# ==============================
def main():
    if not INPUT_DIR.exists():
        print(f"{RED}[ERROR] {INPUT_DIR} directory not found{NC}")
        return

    pdfs = list(INPUT_DIR.rglob("*.pdf"))

    if not pdfs:
        print(f"{YELLOW}[WARNING] No PDF files found on {INPUT_DIR}{NC}")
        return

    for pdf in pdfs:
        relative_path = pdf.relative_to(INPUT_DIR)
        output_pdf = OUTPUT_DIR / relative_path
        redact_pdf(pdf, output_pdf)

    print(f"{GREEN}[DONE] All files processed{NC}")

# ==============================
# ENTRY POINT
# ==============================
if __name__ == "__main__":
    main()
