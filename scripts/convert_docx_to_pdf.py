import win32com.client
import os
import pymupdf

def convert(docx_path, pdf_path):
    docx_abs = os.path.abspath(docx_path)
    pdf_abs = os.path.abspath(pdf_path)
    
    word = win32com.client.Dispatch("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0  # wdAlertsNone
    
    try:
        doc = word.Documents.Open(docx_abs, ReadOnly=True)
        doc.SaveAs(pdf_abs, FileFormat=17) # 17 = wdFormatPDF
        doc.Close(SaveChanges=False)
        print(f"Successfully converted {docx_path} to {pdf_path}")
    finally:
        word.Quit()
        
    doc_pdf = pymupdf.open(pdf_abs)
    print(f"PDF Page count: {len(doc_pdf)}, File size: {os.path.getsize(pdf_abs)} bytes")

if __name__ == "__main__":
    convert("docs/RENANCE_50M_SUPPLEMENTARY_APPENDIX.docx", "docs/RENANCE_50M_SUPPLEMENTARY_APPENDIX.pdf")
