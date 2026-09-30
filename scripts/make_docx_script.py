import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH

doc = docx.Document()

for section in doc.sections:
    section.top_margin = Inches(0.8)
    section.bottom_margin = Inches(0.8)
    section.left_margin = Inches(0.8)
    section.right_margin = Inches(0.8)
    footer = section.footer
    f_p = footer.paragraphs[0]
    f_p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    f_run = f_p.add_run('Renance | Official Video Pitch Script')
    f_run.font.name = 'Calibri'
    f_run.font.size = Pt(9)
    f_run.font.color.rgb = RGBColor(120, 120, 120)

with open('docs/RENANCE_VIDEO_SCRIPT.txt', 'r', encoding='utf-8') as f:
    text = f.read()

lines = text.split('\n')
for line in lines:
    line_s = line.strip()
    if not line_s:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(4)
        continue
    
    if line_s.startswith('====='):
        continue
    elif line_s.startswith('RENANCE:'):
        p = doc.add_paragraph()
        run = p.add_run(line_s)
        run.bold = True
        run.font.name = 'Calibri'
        run.font.size = Pt(20)
        run.font.color.rgb = RGBColor(17, 28, 45)
    elif line_s.startswith('PART 1:') or line_s.startswith('PART 2:') or line_s.startswith('PART 3:'):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(14)
        p.paragraph_format.space_after = Pt(6)
        run = p.add_run(line_s)
        run.bold = True
        run.font.name = 'Calibri'
        run.font.size = Pt(14)
        run.font.color.rgb = RGBColor(19, 27, 46)
    elif line_s.startswith('[SCENE') or line_s.startswith('Timecode:'):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(8)
        p.paragraph_format.space_after = Pt(2)
        run = p.add_run(line_s)
        run.bold = True
        run.font.name = 'Calibri'
        run.font.size = Pt(12)
        run.font.color.rgb = RGBColor(139, 92, 246)
    elif line_s.startswith('VISUAL & SCREEN ACTION') or line_s.startswith('VISUAL:'):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(6)
        p.paragraph_format.space_after = Pt(2)
        run = p.add_run(line_s)
        run.bold = True
        run.font.name = 'Calibri'
        run.font.size = Pt(11)
        run.font.color.rgb = RGBColor(16, 185, 129)
    elif line_s.startswith('SPOKEN DIALOGUE') or line_s.startswith('SPOKEN:'):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(6)
        p.paragraph_format.space_after = Pt(2)
        run = p.add_run(line_s)
        run.bold = True
        run.font.name = 'Calibri'
        run.font.size = Pt(11)
        run.font.color.rgb = RGBColor(245, 158, 11)
    elif line_s.startswith('"'):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after = Pt(6)
        p.paragraph_format.left_indent = Inches(0.2)
        run = p.add_run(line_s)
        run.bold = True
        run.font.name = 'Calibri'
        run.font.size = Pt(11.5)
        run.font.color.rgb = RGBColor(20, 20, 25)
    else:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(3)
        run = p.add_run(line_s)
        run.font.name = 'Calibri'
        run.font.size = Pt(10.5)
        run.font.color.rgb = RGBColor(50, 50, 55)

doc.save('docs/RENANCE_VIDEO_SCRIPT.docx')
print('Script docx successfully generated at docs/RENANCE_VIDEO_SCRIPT.docx')
