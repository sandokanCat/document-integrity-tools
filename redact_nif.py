#!/usr/bin/env python3

"""
redact_nif.py – RECURSIVE SPANISH NIF REDACTION TOOL
====================================================

Author:    © 2026 sandokan.cat – https://sandokan.cat
License:   MIT – https://opensource.org/licenses/MIT
Version:   1.2.0
Date:      2026-01-23

Description
-----------
Recursive PDF redaction tool to detect and permanently redact valid Spanish
DNI/NIE identifiers. Processes PDFs in a directory recursively, redacts
valid NIFs, and logs all findings in JSONL format for historical record.

Redacted PDFs are written to a separate output folder, preserving the
original directory hierarchy. Console output is color-coded for status.
"""

# === STANDARD LIBRARY ===
from collections import Counter
from pathlib import Path
import re
import argparse
import json
from datetime import datetime

# === THIRD-PARTY ===
import fitz  # PyMuPDF

# === OUTPUT COLORS ===
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
CYAN = "\033[0;36m"
NC = "\033[0m"

# === GLOBAL CONFIG ===
NIF_REGEX = re.compile(r'\b([XYZ]?\d{7,8}[A-Z])\b', re.IGNORECASE)
ALPHA_LIST = "TRWAGMYFPDXBNJZSQVHLCKE"


def print_step(title: str) -> None:
    """Print a colored banner to indicate major script progress."""
    print(f"\n=== {title} ===")


def redact_pdf(input_pdf: Path, output_pdf: Path) -> dict:
    """
    Scan and redact all valid Spanish DNI/NIE numbers in a PDF.

    Args:
        input_pdf (Path): PDF to process.
        output_pdf (Path): Path where redacted PDF will be saved.

    Returns:
        dict: Summary per page, total redacted, and error if any.
    """
    print_step(f"Processing {CYAN}{input_pdf}{NC}")
    total_redacted = 0
    pdf_log = {}
    table_rows = []

    try:
        with fitz.open(input_pdf) as doc:
            if doc.is_encrypted:
                print(f"{RED}[ERROR] PDF is encrypted: {input_pdf}{NC}")
                pdf_log["error"] = "encrypted"
                return pdf_log

            for page_number, page in enumerate(doc, start=1):
                page_nifs = Counter()
                text = page.get_text("text")
                candidates = {m.upper() for m in NIF_REGEX.findall(text)}

                for candidate in candidates:
                    # Default status
                    status = "VALID"
                    color = GREEN

                    # Validate NIF/NIE
                    try:
                        letter = candidate[-1]
                        number = int(candidate[:-1].replace("X", "0").replace("Y", "1").replace("Z", "2"))
                        if ALPHA_LIST[number % 23] != letter:
                            status = "INVALID"
                            color = RED
                    except ValueError:
                        status = "MALFORMED"
                        color = YELLOW

                    # Redact valid NIFs
                    rects = page.search_for(candidate)
                    if rects and status == "VALID":
                        for rect in rects:
                            page.add_redact_annot(rect, fill=(0, 0, 0))
                        total_redacted += len(rects)

                    page_nifs[candidate] += len(rects)
                    table_rows.append((page_number, candidate, page_nifs[candidate], status, color))

                page.apply_redactions()
                if page_nifs:
                    pdf_log[f"page_{page_number}"] = dict(page_nifs)

            output_pdf.parent.mkdir(parents=True, exist_ok=True)
            doc.save(output_pdf)

    except Exception as e:
        print(f"{RED}[ERROR] Failed to process {input_pdf}: {e}{NC}")
        pdf_log["error"] = str(e)

    # Print table
    if table_rows:
        print(f"{'Page':<6} | {'NIF':<12} | {'Count':<5} | {'Status':<10}")
        print(f"{'-'*40}")
        for page, nif, count, status, color in table_rows:
            print(f"{color}{page:<6}{NC} | {color}{nif:<12}{NC} | {color}{count:<5}{NC} | {color}{status:<10}{NC}")
        print(f"{'-'*40}")
        print(f"{GREEN}[REDACTED] {total_redacted}{NC}")
        print(f"{GREEN}[SAVED] {CYAN}{output_pdf}{NC}")
    elif not pdf_log.get("error"):
        print(f"{YELLOW}[NO MATCH] {CYAN}{input_pdf}{NC}")

    pdf_log["total_redacted"] = total_redacted
    return pdf_log


def main(input_dir: Path, output_dir: Path | None = None) -> None:
    """
    Recursively process PDFs, redact NIF/NIEs, and append JSONL log.

    Args:
        input_dir (Path): Root directory containing PDFs.
        output_dir (Path | None): Directory for redacted PDFs.
            Defaults to 'redacted_output' next to input_dir.

    JSONL log format:
        {
            "timestamp": "<ISO datetime>",
            "input_dir": "<path>",
            "output_dir": "<path>",
            "files": {
                "<relative_pdf_path>": {
                    "page_1": {"NIF": count, ...},
                    "total_redacted": <int>,
                    "error": "<error_message_if_any>"
                }
            }
        }
    """
    if not input_dir.exists():
        print(f"{RED}[ERROR] {input_dir} not found{NC}")
        return

    if output_dir is None:
        output_dir = input_dir.parent / "redacted_output"
    output_dir.mkdir(parents=True, exist_ok=True)

    pdfs = list(input_dir.rglob("*.pdf"))
    if not pdfs:
        print(f"{YELLOW}[WARN] No PDFs found in {input_dir}{NC}")
        return

    execution_log = {
        "timestamp": datetime.now().isoformat(),
        "input_dir": str(input_dir),
        "output_dir": str(output_dir),
        "files": {}
    }

    total_files = 0

    for pdf in pdfs:
        relative_path = pdf.relative_to(input_dir)
        output_pdf = output_dir / relative_path
        pdf_log = redact_pdf(pdf, output_pdf)
        execution_log["files"][str(relative_path)] = pdf_log
        total_files += 1

    log_file = output_dir / "redaction_log.jsonl"
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(json.dumps(execution_log, ensure_ascii=False) + "\n")

    print_step("Summary")
    print(f"{GREEN}[DONE] {total_files} files processed in: {CYAN}{output_dir}{NC}\n"
          f"[LOG] Appended at: {CYAN}{log_file}{NC}")

    print_step("Reminder")
    print(f"You can sign this output using {CYAN}sign_docs.sh{NC}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Recursive Spanish NIF/NIE redaction tool for PDFs"
    )
    parser.add_argument(
        "-i", "--input",
        type=Path,
        required=True,
        help="Root directory containing PDFs to redact"
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=None,
        help="Directory for redacted PDFs. Default: 'redacted_output' next to input folder"
    )
    args = parser.parse_args()
    main(input_dir=args.input, output_dir=args.output)
