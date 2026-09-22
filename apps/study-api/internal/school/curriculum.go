// Package school holds the school-platform domain logic: the Nigerian
// curriculum catalog (NERDC-aligned), seed syllabuses with starter notes,
// and the pure helpers the HTTP handlers and store layer share.
package school

// SeedClass is one row of the class catalog offered to schools.
type SeedClass struct {
	Name  string
	Level string // primary | junior | senior
	Seq   int
}

// SeedSubject is one row of the subject catalog. Level says which class
// bands the subject is offered in; "both" means everywhere it applies.
type SeedSubject struct {
	Name  string
	Code  string
	Level string // primary | junior | senior | both
	Seq   int
}

// Classes: the full Nigerian basic-education ladder.
var Classes = []SeedClass{
	{"Primary 1", "primary", 1}, {"Primary 2", "primary", 2}, {"Primary 3", "primary", 3},
	{"Primary 4", "primary", 4}, {"Primary 5", "primary", 5}, {"Primary 6", "primary", 6},
	{"JSS 1", "junior", 7}, {"JSS 2", "junior", 8}, {"JSS 3", "junior", 9},
	{"SSS 1", "senior", 10}, {"SSS 2", "senior", 11}, {"SSS 3", "senior", 12},
}

// Subjects: the NERDC curriculum offer. Primary and junior secondary
// carry the broad general-education set; senior secondary specializes.
var Subjects = []SeedSubject{
	// Primary (Basic 1-6)
	{"English Studies", "ENG-P", "primary", 1},
	{"Mathematics", "MTH-P", "primary", 2},
	{"Basic Science & Technology", "BST-P", "primary", 3},
	{"National Values Education", "NVE-P", "primary", 4},
	{"Pre-vocational Studies", "PVS-P", "primary", 5},
	{"Cultural & Creative Arts", "CCA-P", "primary", 6},
	{"Christian Religious Studies", "CRS", "both", 7},
	{"Islamic Religious Studies", "IRS", "both", 8},
	{"Nigerian Language", "NLG", "both", 9},
	{"French", "FRE", "both", 10},
	{"Physical & Health Education", "PHE", "both", 11},
	{"Agricultural Science", "AGR", "both", 12},
	// Junior secondary (JSS 1-3)
	{"English Studies", "ENG-J", "junior", 20},
	{"Mathematics", "MTH-J", "junior", 21},
	{"Basic Science", "BSC", "junior", 22},
	{"Basic Technology", "BTE", "junior", 23},
	{"Social Studies", "SOS", "junior", 24},
	{"Civic Education", "CIV", "both", 25},
	{"Security Education", "SEC", "junior", 26},
	{"Business Studies", "BUS", "junior", 27},
	{"Computer Studies", "CMP", "junior", 28},
	{"Home Economics", "HEC", "junior", 29},
	{"Cultural & Creative Arts", "CCA-J", "junior", 30},
	// Senior secondary (SSS 1-3)
	{"English Language", "ENG-S", "senior", 40},
	{"Mathematics", "MTH-S", "senior", 41},
	{"Economics", "ECO", "senior", 42},
	{"Physics", "PHY", "senior", 43},
	{"Chemistry", "CHM", "senior", 44},
	{"Biology", "BIO", "senior", 45},
	{"Geography", "GEO", "senior", 46},
	{"Government", "GOV", "senior", 47},
	{"Literature-in-English", "LIT", "senior", 48},
	{"Commerce", "COM", "senior", 49},
	{"Financial Accounting", "FAC", "senior", 50},
	{"Further Mathematics", "FMT", "senior", 51},
	{"Computer Science", "CSC", "senior", 52},
	{"Technical Drawing", "TDR", "senior", 53},
}

// SubjectsFor returns the catalog rows offered to a class level.
func SubjectsFor(classLevel string) []SeedSubject {
	var out []SeedSubject
	for _, s := range Subjects {
		if s.Level == classLevel || s.Level == "both" {
			out = append(out, s)
		}
	}
	return out
}
