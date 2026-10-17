/**
 * The Renance guides library - substantive, factual articles about the
 * Nigerian exam system (JAMB, WAEC, NECO, Post-UTME, CBT practice).
 *
 * This is the site's answer to "no blog, no articles, nothing for AI to
 * cite": every guide is real content a candidate can act on, committed
 * with the site so static export bakes it and the sitemap can never
 * drift from the pages. Edit here only; the index, the article pages,
 * the sitemap and the footer links all read from this module.
 */

export interface GuideSection {
  heading: string;
  paragraphs: string[];
  list?: string[];
}

export interface GuideFAQ {
  q: string;
  a: string;
}

export interface Guide {
  slug: string;
  title: string;
  description: string;
  tag: string;
  published: string;
  updated: string;
  minutes: number;
  sections: GuideSection[];
  faq: GuideFAQ[];
}

export const GUIDES: Guide[] = [
  {
    slug: 'jamb-utme-format-explained',
    title: 'How the JAMB UTME works: subjects, questions, scores and timing',
    description:
      'The four-subject rule, how 180 questions become a score over 400, how long the paper lasts, and what the machine does with your answers - the UTME format, explained plainly.',
    tag: 'JAMB',
    published: '2026-10-17',
    updated: '2026-10-17',
    minutes: 7,
    sections: [
      {
        heading: 'What the UTME actually is',
        paragraphs: [
          'The Unified Tertiary Matriculation Examination (UTME) is the entrance exam the Joint Admissions and Matriculation Board (JAMB) runs every year for candidates seeking admission into Nigerian universities, polytechnics and colleges of education. It is a computer-based test: you sit in a CBT centre, answers go to a machine, and nobody marks anything by hand.',
          'Every candidate registers once per exam year. Registration usually opens early in the year and needs your National Identification Number (NIN), so sort the NIN out before registration season - it is the single most common avoidable delay. After registration you get your registration number, and later your exam slip tells you the centre, date and time you were assigned.',
        ],
      },
      {
        heading: 'The four-subject rule',
        paragraphs: [
          'Every candidate sits exactly four subjects. Use of English is compulsory for everyone, and you choose three more subjects that match the course you want to study - a medicine aspirant sits English, Biology, Chemistry and Physics, while a law aspirant sits English, Literature, Government and one more arts or social-science subject. The subject combination matters more than most candidates realise: a brilliant score in the wrong combination can disqualify your course choice at screening, so check your chosen institution\'s brochure before you register, not after.',
        ],
      },
      {
        heading: 'How many questions, and how the score is built',
        paragraphs: [
          'In the recent UTME format, Use of English carries 60 questions and each of your three other subjects carries 40 questions - 180 questions in total. Each subject is scored over 100, and the four subject scores sum to the aggregate over 400 everybody quotes. English questions are weighted differently from the others, which is why 60 English questions and 40 Physics questions can both come out of 100.',
          'There is no negative marking in the UTME: a wrong answer costs you nothing beyond the time you spent on it, and an unanswered question and a wrong answer score the same zero. That makes leaving blanks indefensible - if time is running out, guess the remaining questions before you submit.',
        ],
      },
      {
        heading: 'Timing and the CBT hall',
        paragraphs: [
          'The paper is timed - the exam board sets the duration for the year, and in recent UTMEs candidates have had roughly two hours for the 180 questions. The timer on your screen is the authority: when it ends, the system closes the paper. Practise with a clock from day one, because knowing the syllabus and finishing 180 questions inside the window are two different skills.',
          'The hall itself is strict: biometric verification before you sit, no phones or smart devices, no calculators, and rough work happens on whatever paper the centre provides. Your answers save to the server as you go, so a network hiccup does not wipe your paper - but only answers you actually clicked count, so never walk out assuming the machine "saved what you meant".',
        ],
      },
      {
        heading: 'What happens after the exam',
        paragraphs: [
          'Results are usually released within days of your sitting, and you check them free on the board\'s portal with your registration number. After results, institutions screen candidates - some with their own Post-UTME test, some by aggregating your UTME score with your O\'level grades, and the weighting differs by school. Your UTME score starts the conversation; it rarely ends it on its own.',
        ],
      },
    ],
    faq: [
      {
        q: 'How many subjects do I write in JAMB?',
        a: 'Four: Use of English plus three subjects relevant to your intended course. The correct combination for your course is in your institution\'s admission brochure - verify it before registration.',
      },
      {
        q: 'What is the total score in JAMB?',
        a: '400. Each of the four subjects is scored over 100 and the four are added together.',
      },
      {
        q: 'Does JAMB deduct marks for wrong answers?',
        a: 'No. The UTME has no negative marking, so you should answer every question, even if that means guessing when time runs short.',
      },
    ],
  },
  {
    slug: 'what-your-jamb-score-means',
    title: 'What your JAMB score means for admission (and what to do next)',
    description:
      'The 400 aggregate in context: policy cutoffs, departmental competition, aggregate formulas, and the realistic next move for every score band.',
    tag: 'Admissions',
    published: '2026-10-17',
    updated: '2026-10-17',
    minutes: 6,
    sections: [
      {
        heading: 'The score itself is only half the story',
        paragraphs: [
          'A UTME score over 400 travels with you through the whole admission year, but no score admits you by itself. Admission in Nigeria is a pipeline: your UTME result, your O\'level grades, and your institution\'s own screening (test or aggregate) all feed the final departmental list. Understanding where your score sits in that pipeline tells you what to do next instead of guessing.',
        ],
      },
      {
        heading: 'Policy cutoffs versus departmental cutoffs',
        paragraphs: [
          'Every year, the national policy meeting announces minimum UTME scores per institution type - in recent years that floor has sat somewhere between 140 and 160 for degree-awarding institutions, with polytechnics and colleges of education lower. That number is a permission slip to participate in screening, not a promise of admission.',
          'The cutoff that actually decides your fate is departmental: each course in each school sets its own bar each year based on the scores of the people who applied. Competitive programmes - medicine, nursing, law, pharmacy, engineering at the big-name schools - routinely need scores far above the national floor, often in the high 200s and above for the most oversubscribed courses. Less contested courses in less saturated schools can admit at much lower scores. The same 220 can be a strong score in one department and a weak one in another.',
        ],
      },
      {
        heading: 'How schools combine your scores',
        paragraphs: [
          'Institutions differ in how they weigh the pieces, and the formula is theirs to choose and publish. Common patterns include splitting the aggregate 50-50 between UTME and Post-UTME, 60-40 in favour of one component, adding O\'level grade points into the mix, or screening on O\'level grades with UTME as a threshold. Two candidates with the same UTME score can land on opposite sides of a cutoff because their O\'level grades or Post-UTME scores differ.',
          'This is why the practical advice is boring and vital: get your O\'level results as strong as you can before admission season, find your school\'s published aggregate formula, and compute your own standing instead of hoping.',
        ],
      },
      {
        heading: 'The realistic play for each score band',
        paragraphs: [
          'Above all, remember the calendar: after your result, the next steps are the change of institution/course window (where candidates whose scores fall short of their first choice move to a school their score serves) and each school\'s screening registration. Missing those windows strands good scores.',
        ],
        list: [
          '280 and above: competitive-course territory at most schools. Stay the course, prepare hard for Post-UTME, and keep your O\'level spotless.',
          '220-279: strong for many courses; competitive at the most oversubscribed departments. Consider the departmental cutoffs of past years at your school and have a second course in mind.',
          '170-219: admissible for many programmes, especially outside the most saturated schools. Research departments and schools honestly, and use the change-of-course window deliberately.',
          'Below the national floor: the UTME can be sat again next year, and a year of targeted preparation moves scores dramatically. Meanwhile, polytechnic and college-of-education routes remain real, respectable paths with their own progression (Direct Entry) into degree programmes later.',
        ],
      },
    ],
    faq: [
      {
        q: 'Is 200 a good JAMB score?',
        a: 'It clears the usual national floor and admits for many courses, but oversubscribed programmes at big schools usually demand more. Compare your score against your chosen department\'s recent cutoffs, not against a universal bar.',
      },
      {
        q: 'Can I change my course or school after my JAMB result?',
        a: 'Yes - JAMB opens a change of institution/course window after results, for a fee, with a deadline. Watch the official portal so you do not miss it.',
      },
    ],
  },
  {
    slug: 'waec-neco-nabteb-difference',
    title: 'WAEC, NECO and NABTEB: what each exam is and which one you need',
    description:
      'The three O\'level bodies compared - when each exam holds, how the grades work, what each certificate is accepted for, and how candidates combine them.',
    tag: "O'Level",
    published: '2026-10-17',
    updated: '2026-10-17',
    minutes: 6,
    sections: [
      {
        heading: 'Three bodies, one job',
        paragraphs: [
          'Nigeria\'s O\'level system runs on three examination bodies, and their certificates all do the same fundamental job: prove you completed secondary school with grades in the subjects admission and employers ask for. WAEC (the West African Examinations Council) is the oldest and the regional one - its WASSCE is also written in several West African countries. NECO (the National Examinations Council) is Nigeria\'s federal body. NABTEB (the National Business and Technical Examinations Board) serves technical and trade education specifically.',
          'For Nigerian admissions, all three are accepted - universities, polytechnics and colleges of education list "five O\'level credits" without caring which body issued them. The differences that matter to a candidate are the calendar, the style, and your own situation.',
        ],
      },
      {
        heading: 'When each exam holds',
        paragraphs: [
          'WASSCE for school candidates runs in the April-to-June window each year - this is the exam most SS3 students sit. Private candidates have their own WASSCE sittings (the "GCE"): a first series early in the year and a second series later. NECO\'s SSCE for school candidates follows in June-July, right after WASSCE, and NECO also runs a November-December GCE for private candidates. NABTEB\'s certificate exams hold around May-June.',
          'The sequencing is deliberate: a WASSCE candidate can sit NECO the same year if a result needs rescuing, and private-candidate series give school leavers repeated chances to top up missing credits.',
        ],
      },
      {
        heading: 'Grades: the A1-to-F9 scale',
        paragraphs: [
          'WAEC and NECO both grade on the same face scale: A1 is excellent, through B2, B3, C4, C5, C6, down to D7, E8 and F9. A credit is anything from C6 upward - A1 to C6. Admission talk almost always means "five credits including English and Mathematics (and the subjects your course needs)", and the stronger your grades, the more weight some schools give them in aggregate screening.',
          'One caution: passing a subject and having the credit your target course demands are different things. A course requiring a credit in Further Mathematics will not care that you passed Biology well. Read your course\'s O\'level requirements the way you read your subject combination - before the exam, while there is still time to sit the missing subject.',
        ],
      },
      {
        heading: 'Choosing between them',
        paragraphs: [
          'School candidates rarely choose - the school registers its cohort for WASSCE, often alongside NECO for double coverage. Private candidates (people resitting subjects, improving grades, or finishing outside the school system) pick based on timing: NECO\'s GCE late in the year, WASSCE\'s private series early. For technical pathways - welding, electrical installation, business trades - NABTEB\'s certificates are purpose-built and recognised.',
          'The exam you sit matters less than the preparation behind it. All three bodies publish syllabuses and past-paper traditions, and every one of their papers rewards candidates who practise on real questions under time pressure - which is exactly what a CBT and past-question platform is for.',
        ],
      },
    ],
    faq: [
      {
        q: 'Do universities prefer WAEC over NECO?',
        a: 'No. Nigerian tertiary institutions accept WAEC, NECO and NABTEB certificates equally for admission. What matters is the grades and the subjects your course requires.',
      },
      {
        q: 'Can I combine WAEC and NECO results for admission?',
        a: 'Yes. Institutions accept combining two sittings - for example, a credit in one body\'s paper plus credits in another\'s - as long as the combined subjects meet your course\'s requirements.',
      },
    ],
  },
];

GUIDES.push(
  {
    slug: 'how-to-prepare-for-jamb',
    title: 'How to prepare for JAMB and actually finish the syllabus',
    description:
      'A preparation plan built around past questions, spaced review and honest CBT mocks - how to cover the syllabus and walk into the hall calm.',
    tag: 'JAMB',
    published: '2026-10-17',
    updated: '2026-10-17',
    minutes: 7,
    sections: [
      {
        heading: 'Start from the syllabus, not the textbook',
        paragraphs: [
          'The fastest way to waste a preparation year is to study broadly and randomly. JAMB publishes a syllabus per subject, and the exam\'s questions are drawn against it. Print or open the syllabus for each of your four subjects, break each one into its topics, and turn that topic list into your study plan - every session you sit should visibly tick a topic or deepen one.',
          'With four subjects, rotation beats binging. Two or three subjects a day with full attention outperforms eight subjects touched shallowly, and the weekly rhythm matters more than any single heroic day. Candidates with a year to spare can afford long, deep cycles; candidates with weeks left should triage - high-yield topics first, with the syllabus as the map of what counts as high-yield.',
        ],
      },
      {
        heading: 'Past questions are the syllabus speaking',
        paragraphs: [
          'Nothing teaches the UTME\'s style, difficulty and phrasing faster than its own past questions. Work them by year and by topic: by year for exam realism, by topic for mastery. When you miss a question, the valuable part is not the correction - it is the diagnosis. Which topic was it testing? Was the miss a knowledge gap, a rushed read, or a trap in the options? A miss you understood is a topic you tightened; a miss you skimmed past is a repeat waiting to happen.',
          'This is where a review queue earns its place. Every missed question should come back to you on a schedule - tomorrow, next week, next month - until it sticks, instead of living once in your memory and dying there. Spaced repetition is not a study gimmick; it is how memory consolidation actually works, and it is the difference between recognising a topic and answering questions on it under pressure.',
        ],
      },
      {
        heading: 'Mock on a real CBT interface',
        paragraphs: [
          'Knowledge and exam performance are different assets, and the bridge between them is realistic practice. Sit full-length mocks on a CBT interface - the same layout, the same timer pressure, answers going in by click - because exam day should feel like your hundredth time, not your first. After each mock, read the topic breakdown the same way you read past questions: what did you miss, why, and what does that change in next week\'s plan?',
          'Track the boring numbers as you go: accuracy per subject, average time per question, and your finishing rate - whether you actually reach the last question with time left. Improving those three curves over months of mocks is what a rising score is made of.',
        ],
      },
      {
        heading: 'The weeks before the exam',
        paragraphs: [
          'In the final stretch, resist learning anything new. The last two weeks are for review queues, weak topics, and full mocks at exam pace - plus the administrative hygiene that sinks unprepared candidates every year: print your exam slip early, know your centre\'s location, and plan to arrive well ahead of your reporting time. Sleep properly the night before; a tired brain loses marks a prepared one would never drop.',
        ],
      },
    ],
    faq: [
      {
        q: 'How many months is enough to prepare for JAMB?',
        a: 'Three to six months of consistent, syllabus-driven study is a realistic window for most candidates. What matters is coverage plus practice volume - a focused hour daily beats an unfocused weekend marathon.',
      },
      {
        q: 'Are past questions enough to pass JAMB?',
        a: 'Past questions are the core, not the whole. Use them to learn the exam\'s style and to diagnose weak topics, then study those topics properly in the syllabus. Candidates who only memorise past-paper answers crack when the phrasing changes.',
      },
    ],
  },
  {
    slug: 'post-utme-screening-guide',
    title: 'Post-UTME and screening: how universities pick the final admission list',
    description:
      'What Post-UTME is, the aggregate formulas schools use, how O\'level grades fit in, and how to prepare for the stage after your JAMB result.',
    tag: 'Admissions',
    published: '2026-10-17',
    updated: '2026-10-17',
    minutes: 6,
    sections: [
      {
        heading: 'What Post-UTME actually is',
        paragraphs: [
          'After UTME results, most tertiary institutions run their own selection stage - commonly called Post-UTME. It takes two broad shapes: a test the school sets and marks itself (usually computer-based, usually drawn from your JAMB subject combination at Senior Secondary level), or a screening exercise where the school aggregates your existing results without holding another exam. Some schools test some departments and screen others. Which model your school runs, and when, is published on the school\'s portal during the admission year.',
          'The point of the stage is simple: the school has thousands of candidates with UTME scores and wants its own evidence before offering limited seats. Treat it as the second half of the match, not a formality.',
        ],
      },
      {
        heading: 'The aggregate: how the pieces combine',
        paragraphs: [
          'Schools publish how they compute the aggregate that ranks candidates per department, and the formulas differ. Common shapes include a 50-50 split between UTME and Post-UTME scores, a 60-40 weighting, formulas that convert O\'level grades into points and add them in, and screening models that rank on O\'level grades alone for candidates who clear a UTME threshold. Because the formulas differ, two schools can rank the same two candidates in opposite orders.',
          'Work an example by hand the moment your school publishes its formula. If the split is 50-50 and your UTME is 260, you walk into the Post-UTME knowing exactly what the other half of your aggregate needs to be for your department\'s recent cutoffs - and that number tells you whether to aim for solid or for spectacular.',
        ],
      },
      {
        heading: 'Your O\'level grades carry more weight than you think',
        paragraphs: [
          'Where O\'level grades enter the formula, the difference between a C6 and an A1 across five subjects is real aggregate points - and some competitive courses quietly prefer candidates with one-sitting results. More fundamentally, your O\'level subjects must include the credits your course demands. A great UTME score with a missing credit is a rejected file; no aggregate formula rescues an unmet requirement.',
          'If a credit is missing, the private-candidate series of WAEC or NECO exist precisely for that rescue, and combining two sittings is broadly accepted. Sort it before the screening window, not during it.',
        ],
      },
      {
        heading: 'Preparing for the test itself',
        paragraphs: [
          'Schools that test usually stay close to familiar ground: your JAMB subjects, Senior Secondary level, CBT format, time pressure. Practising past questions from your UTME subjects - and Post-UTME papers from your school where they circulate - covers the mechanics. Confirm the exact format on the school\'s portal when registration opens, watch the deadlines ruthlessly (candidates miss Post-UTME windows every year over a forgotten registration), and carry exactly what the instructions list on the day.',
        ],
      },
    ],
    faq: [
      {
        q: 'Do all schools write Post-UTME?',
        a: 'No. Some conduct their own test, others screen by aggregating UTME and O\'level results without a new exam, and the model can change year to year. Follow your institution\'s official portal for its current process.',
      },
      {
        q: 'Can a high JAMB score skip Post-UTME?',
        a: 'Not automatically. A high score positions you well, but schools apply their published process to every candidate. Check whether your school exempts or auto-admits top scorers in any programme - some announce such policies - and never assume it.',
      },
    ],
  },
  {
    slug: 'cbt-exam-day-checklist',
    title: 'CBT exam day: what to expect and the mistakes that cost real marks',
    description:
      'From the eve of the exam to hitting submit - the practical checklist for a computer-based test day, written for Nigerian exam centres.',
    tag: 'CBT',
    published: '2026-10-17',
    updated: '2026-10-17',
    minutes: 5,
    sections: [
      {
        heading: 'The night before',
        paragraphs: [
          'Exam-day losses are usually administrative, not academic. The night before, confirm the basics: your exam slip is printed (or saved offline on your phone), it carries the right centre and time, you know the route to the centre and when to leave, and everything the instructions permit - typically your slip and a pen - is in one place. Pack nothing the rules ban: phones are usually surrendered at the gate, and calculators or smart watches are near-universal disqualifiers.',
          'Then do the thing ambitious candidates skip: sleep. An exam sat on four hours of sleep loses you more marks than any topic you could have crammed at 2 a.m.',
        ],
      },
      {
        heading: 'At the centre',
        paragraphs: [
          'Arrive early - centres verify candidates in batches, and late arrivals can be refused or rushed into the paper flustered. Expect the sequence: queue and document check, biometric verification (your fingerprint confirms your registration), seat assignment, and a short orientation on the machine. The invigilators run a tight room; comply fast, ask only what matters, and get comfortable at your terminal.',
          'Before the timer starts, most systems let you look around the interface. Take the seconds: find the question navigation, the palette of answered and unanswered questions, the subject tabs if your paper has them, and the submit button. Knowing where everything lives removes the fumbling that eats time later.',
        ],
      },
      {
        heading: 'Inside the paper',
        paragraphs: [
          'Answer in the order that serves you: for most candidates that means sweeping the paper once for certain answers, marking the doubtful ones for return, and never letting one stubborn question eat five minutes. The timer is public - check it at natural checkpoints (a quarter done, half done, three-quarters) and adjust pace, because finishing the paper matters when there is no negative marking: blank answers are surrendered marks.',
          'Watch the classic CBT traps: clicking an option and forgetting to confirm where the system requires it; changing correct answers into wrong ones in a panic at the end; misreading "NOT" and "EXCEPT" in the question stem; and entering the paper thinking your scratch work transfers anywhere. It does not - only what you click counts.',
        ],
      },
      {
        heading: 'Submitting and leaving',
        paragraphs: [
          'When you finish - or when the timer forces the end - submit only after a final sweep of the palette for unanswered questions. Guess those rather than leave them. After submission, follow the centre\'s exit procedure; some exams print or issue a slip you should keep. Then leave the centre and resist the post-mortem with strangers: the result is sealed on a server, and the only thing that changes it now is nobody.',
        ],
      },
    ],
    faq: [
      {
        q: 'What should I bring to a CBT exam?',
        a: 'Typically your printed exam slip and a pen; some centres add specific instructions. Phones, calculators and smart devices are banned almost everywhere. Read your exam slip\'s instructions - they are the authority for your centre.',
      },
      {
        q: 'What if the power or network fails mid-exam?',
        a: 'CBT systems save answers to the server as you go, and centres have power backups. Raise your hand, report it, and follow the invigilator\'s instruction - do not abandon your seat or restart anything yourself.',
      },
    ],
  }
);
