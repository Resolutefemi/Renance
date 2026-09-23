// Scheme-of-work seeds: NERDC-aligned week-by-week topic strips for the
// most widely taught subjects. Each entry lists the topics a term
// typically walks through; the pour writes them into any term syllabus
// whose scheme of work is still empty, so teachers start from a draft
// they edit instead of a blank page.

package school

// SchemeSeedTopic is one week of a seeded scheme.
type SchemeSeedTopic struct {
        Week  int
        Topic string
}

// SchemeSeeds maps subject code -> term -> ordered weekly topics.
var SchemeSeeds = map[string]map[int][]string{
        "ENG-J": {
                1: {"The paragraph: writing simple descriptions", "Nouns and their kinds", "Number work: singular and plural", "Comprehension: following a story", "Verbs and tenses", "Punctuation: full stop, comma, question mark", "Vocabulary: word families", "Letter writing: informal letters"},
                2: {"Adjectives and comparison", "Pronouns in sentences", "Comprehension: reading for detail", "Tenses: past and present", "Formal letters", "Summary writing: main ideas", "Adverbs of manner", "Poetry: reading a short poem"},
                3: {"Prepositions and conjunctions", "Direct and reported speech", "Comprehension: factual passages", "Debate: stating an argument", "Idioms and proverbs", "Essay writing: narrative", "Drama: reading a short play", "Revision and structure practice"},
        },
        "MTH-J": {
                1: {"Whole numbers and place value", "Fractions: types and equivalence", "Decimals and percentages", "Factors and multiples", "LCM and HCF", "Approximation and estimation", "Addition and subtraction of directed numbers", "Multiplication and division practice"},
                2: {"Simple equations", "Word problems with equations", "Geometry: lines and angles", "Triangles and their properties", "Quadrilaterals and circles", "Perimeter and area", "Ratio and proportion", "Money: profit and loss"},
                3: {"Statistics: frequency tables", "Bar charts and pictograms", "Averages: mean, median, mode", "Probability: simple events", "Scale drawing", "Time, speed and distance", "Volume of simple solids", "Revision with past checks"},
        },
        "BSC": {
                1: {"Living and non-living things", "Classification of living things", "The cell as a basic unit", "Characteristics of living things", "Human body systems: digestion", "Human body systems: respiration", "Matter: states and changes", "Measurement: length, mass, time"},
                2: {"Elements, compounds and mixtures", "Separation techniques", "Air and its components", "Water: sources and uses", "Acids, bases and salts", "Energy: forms and sources", "Force and motion basics", "Simple machines"},
                3: {"The environment and ecosystems", "Food chains and webs", "Pollution and conservation", "Reproduction in plants", "Reproduction in animals", "Growth and development", "Diseases: causes and prevention", "Science and technology in life"},
        },
        "CIV": {
                1: {"Meaning of citizenship", "Rights of a citizen", "Duties and obligations", "Democracy: meaning and features", "The rule of law", "National symbols", "Values: honesty and integrity", "Community service"},
                2: {"Discipline: meaning and importance", "Respect for national institutions", "Law and order in society", "Causes of indiscipline", "Effects of indiscipline", "Cooperation and tolerance", "Self-reliance", "National consciousness"},
                3: {"Government: meaning and levels", "The legislature", "The executive", "The judiciary", "Elections and voting", "Political parties", "Public opinion", "Protection of human rights"},
        },
        "ENG-S": {
                1: {"Vocabulary development: register", "Comprehension: content and inference", "Summary: identifying main points", "Lexis: antonyms and synonyms", "Consonant clusters and stress", "Essay: expository writing", "Grammatical accuracy: concord", "Oral English: vowel sounds"},
                2: {"Comprehension: writer's purpose", "Summary: phrase and sentence use", "Tenses and sequence", "Essay: argumentative writing", "Intonation and sentence stress", "Lexis: idioms and collocations", "Report writing", "Literary appreciation basics"},
                3: {"Comprehension: figurative usage", "Summary: meaning-based questions", "Clauses and sentence types", "Letter writing: formal register", "Diphthongs and vowel contrast", "Speech work: emphasis", "Essay: narrative craft", "Revision across papers"},
        },
        "MTH-S": {
                1: {"Surds: simplification", "Indices and logarithms", "Quadratic equations: factorisation", "Quadratic equations: formula", "Simultaneous linear equations", "Variation: direct and inverse", "Sets and Venn diagrams", "Logic: simple statements"},
                2: {"Trigonometry: ratios", "Angles of elevation and depression", "Circle theorems", "Coordinate geometry: lines", "Sequences and series", "Inequalities", "Mensuration of solids", "Statistics: measures of location"},
                3: {"Probability: simple and combined", "Differentiation: first principles", "Integration: basic antiderivatives", "Applications of calculus", "Matrices and determinants", "Binary operations", "Longitude and latitude", "Revision and past checks"},
        },
}
