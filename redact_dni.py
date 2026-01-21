#!/usr/bin/env python3

"""
RECURSIVE PDF DNI REDACTION
- SCANS ALL PDFs IN A DIRECTORY TREE
- REDACTS A SPECIFIC DNI ONLY
- OUTPUTS SAFE COPIES ONLY
"""

from pathlib import Path
import fitz  # PyMuPDF

# ==============================
# CONFIG
# ==============================
INPUT_DIR = Path("./input")
OUTPUT_DIR = Path("./output")

DNI_TO_REDACT = "47590565T"  # DNI exacto a redactar

# ==============================
# CORE FUNCTION
# ==============================
def redact_pdf(input_pdf: Path, output_pdf: Path):
    doc = fitz.open(input_pdf)
    found = False

    for page_number, page in enumerate(doc, start=1):
        # SEARCH FOR EXACT DNI MATCH
        matches = page.search_for(DNI_TO_REDACT)
        for rect in matches:
            page.add_redact_annot(rect, fill=(0, 0, 0))
            found = True

        # APPLY REDACTIONS AFTER ALL MATCHES ON THIS PAGE
        page.apply_redactions()

    # CREATE OUTPUT DIRECTORY IF IT DOESN'T EXIST
    output_pdf.parent.mkdir(parents=True, exist_ok=True)
    doc.save(output_pdf)
    doc.close()

    status = "REDACTED" if found else "NO MATCH"
    print(f"[{status}] {input_pdf}")

# ==============================
# MAIN
# ==============================
def main():
    if not INPUT_DIR.exists():
        print("[ERROR] INPUT DIRECTORY NOT FOUND")
        return

    pdfs = list(INPUT_DIR.rglob("*.pdf"))

    if not pdfs:
        print("[WARNING] NO PDF FILES FOUND")
        return

    for pdf in pdfs:
        relative_path = pdf.relative_to(INPUT_DIR)
        output_pdf = OUTPUT_DIR / relative_path
        redact_pdf(pdf, output_pdf)

    print("[DONE] ALL FILES PROCESSED")

# ==============================
# ENTRY POINT
# ==============================
if __name__ == "__main__":
    main()
