#!/usr/bin/env -S uv --quiet run --script
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "PyMuPDF",
# ]
# ///
#

"""
A minimal pdfgrep equivalent using PyMuPDF.
Usage:
    ./pdfgrep.py [options] PATTERN file1.pdf [file2.pdf ...]
Options:
    -i, --ignore-case   Do a case-insensitive search.
"""

import sys
import re
import argparse
import fitz  # PyMuPDF

def search_pdf(pdf_path, pattern, flags):
    try:
        doc = fitz.open(pdf_path)
    except Exception as e:
        sys.stderr.write(f"Error opening {pdf_path}: {e}\n")
        return

    for page_num in range(len(doc)):
        page = doc.load_page(page_num)
        # Extract text as lines
        lines = page.get_text().splitlines()
        for line_no, line in enumerate(lines, start=1):
            if re.search(pattern, line, flags):
                # Format: filename:page:line: text
                print(f"{pdf_path}:{page_num+1}:{line_no}:{line}")

def main():
    parser = argparse.ArgumentParser(description="A pdfgrep equivalent using PyMuPDF")
    parser.add_argument("pattern", help="Regex pattern to search for")
    parser.add_argument("pdfs", nargs="+", help="PDF file(s) to search")
    parser.add_argument("-i", "--ignore-case", action="store_true", help="Ignore case")
    args = parser.parse_args()

    flags = re.IGNORECASE if args.ignore_case else 0
    for pdf in args.pdfs:
        search_pdf(pdf, args.pattern, flags)

if __name__ == "__main__":
    main()
