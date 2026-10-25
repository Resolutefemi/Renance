#!/usr/bin/env python3
"""tert/router.py — route every tertiary course to its discipline pack.
Keyword rules on title + department + faculty. Returns the pack key or
'generic' (the tiny fallback pack for anything unmatched)."""
import re

RULES = [
    # computing
    ("computing_python", r"python"),
    ("networking", r"cyber|network(ing)? security|network(ing)?\b|computer architect|operating system|information security|ethical hack"),
    ("computing_general", r"web\b|multimedia|graphic|information (system|technology)|computer (appreciation|literacy|fundamental|package|basics|science|study)|ict\b|library|librarianship|software engineer|office automation|computer(engineering| engin)"),
    ("eng_electrical", r"computer engineer|electr|electron|telecom|power system|control system|instrumentation|mechatron"),
    # engineering
    ("eng_civil", r"civil|structural|construction|building (tech|services|)|quantity survey|highway|transportation engineer|geotech"),
    ("eng_mechanical", r"mechanical|thermodynamic|fluid|machine shop|manufactur|metallurg|material(s)? engineer|automob|production engineer|agricultural engineer|biosystems"),
    ("eng_chemical", r"chemical engineer|petrol|polymer|process engineer|gas engineer|refin"),
    # sciences
    ("data_analytics", r"statistic|data (science|analytic|structure)|mathemat|actuar|demograph|operations research|numerical"),
    ("chem_phys", r"chemist|physic|geolog|geophys|mining|geoscien|meteorolog|industr math"),
    ("bio_sciences", r"biolog|botan|zool|microbio|biochem|genetic|parasit|entomolog|marine|ocean|ecolog|science lab|applied biology"),
    # agriculture
    ("agriculture", r"agric|agronom|crop|soil sci|horticult|forestry|fisher|fish|animal (prod|sci|breed)|pasture|extension|food (sci|tech|process)|wildlife"),
    ("medicine", r"nutrition|dietet|veterinar|animal health"),
    # medicine
    ("medicine", r"medic|medical|surgery|nurs|anatom|physiolog|pharmac|patholog|midwifer|health|dent|radio|optom|physiother|communit|epidemiolog|public health|radiograp|medical lab|health information"),
    # business/economics
    ("accounting_finance", r"account|financ|banking|taxation|audit|insurance|actuarial science"),
    ("business", r"business|manag|entrepreneur|marketing|human resource|office tech|procurement|purchasing|transport manag|co-operative|secretarial|logistics|supply chain|hospitality|tourism|hotel|event"),
    ("economics", r"econom"),
    ("law", r"law|legal|juris|crimin|security studies"),
    # education
    ("education", r"education|teaching|curriculum|pedagog|classroom|educational"),
    # humanities
    ("english_lang", r"english|linguist|language|communication skills|use of|literac"),
    ("arts", r"literature|literary|history|philosoph|religious|theolog|islamic|christian|arabic|french|mandarin|chinese|yoruba|hausa|igbo|music|theatre|drama|fine (and applied )?art|creative|archaeolog|heritage|performing|classics|greek|latin|film|cinema|nollywood"),
    # social
    ("social_sciences", r"political|sociolog|psycholog|social work|international (stud|relat)|anthropolog|mass comm|journal|media stud|publishing|peace|conflict|citizenship|nigerian peoples|civic"),
    # environment
    ("environment", r"geograph|environment|urban|estate|architecture|town (and )?(country|regional) plan|surveying|geo-informatics|geoinformatics|land survey|meteorol"),
    # department-based sweep for niche programmes
    ("eng_chemical", r"food engineer"),
    ("data_analytics", r"systems engineer"),
    ("eng_mechanical", r"aeronautic|astronautic|wood products|textile|leather|glass|ceramic|welding|fabrication"),
    ("eng_civil", r"railway"),
    ("economics", r"development stud"),
    ("business", r"industrial training|siwes"),
    ("chem_phys", r"integrated science|basic science"),
    ("social_sciences", r"social studies"),
    # gst course-title sweep
    ("english_lang", r"academic writing|report writing|public speaking|reading & comprehension|reading and comprehension|minute-writing|editing|communication in the digital"),
    ("arts", r"symbolic logic|introduction to logic|critical thinking|ethics|african studies|religion & society|religion and society|globalisation|globalization"),
    ("social_sciences", r"security awareness|corruption|drug abuse|cultism|public safety"),
    ("computing_general", r"computer studies|internet skills|coding|computational thinking|emerging technologies|e-government|digital public"),
    ("environment", r"climate change|sustainable development|renewable energy|resource conservation"),
    ("social_sciences", r"leadership|governance|public service|youth empowerment|future readiness"),
    ("chem_phys", r"science, technology & society|science, technology and society"),
    ("business", r"industrial attachment"),
    # gst sweep
    ("english_lang", r"general studies.*(english|communication)|(use of )?english for|communication in english"),
    ("arts", r"logic and philosophy|nigerian peoples|philosophy and logic"),
    ("business", r"entrepreneurship"),
    ("social_sciences", r"peace stud|conflict resolution"),
    ("computing_general", r"computer appreciation|ict\b|information (and |& )?communication|computing"),
]


def route(course):
    blob = (course["title"] + " " + course["dept_name"] + " " + course["faculty"]).lower()
    for pack, pat in RULES:
        if re.search(pat, blob):
            return pack
    return "generic"
