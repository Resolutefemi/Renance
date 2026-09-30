import os
import subprocess
import pymupdf

def main():
    html_path = os.path.abspath("docs/RENANCE_SEO_PLAYSTORE_STRATEGY_MEMO.html")
    pdf_path = os.path.abspath("docs/RENANCE_SEO_PLAYSTORE_STRATEGY_MEMO.pdf")
    chrome_path = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

    formatted_url = "file:///" + html_path.replace("\\", "/")

    cmd = [
        chrome_path,
        "--headless",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path}",
        formatted_url
    ]

    print("Compiling PDF via Headless Chrome...")
    subprocess.run(cmd, check=True)

    if os.path.exists(pdf_path):
        doc = pymupdf.open(pdf_path)
        print(f"SUCCESS! PDF Created at: {pdf_path}")
        print(f"Pages: {len(doc)}, File Size: {os.path.getsize(pdf_path)} bytes")
    else:
        print("Error: PDF output file not generated.")

if __name__ == "__main__":
    main()
