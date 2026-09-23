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
// Department marks the senior-band track the subject belongs to
// (art / science / commercial); is_core subjects are compulsory for
// every SSS student regardless of track.
type SeedSubject struct {
        Name       string
        Code       string
        Level      string // primary | junior | senior | both
        Seq        int
        Department string // '' | art | science | commercial
        IsCore     bool
}

// Classes: the full Nigerian basic-education ladder.
var Classes = []SeedClass{
        {"Primary 1", "primary", 1}, {"Primary 2", "primary", 2}, {"Primary 3", "primary", 3},
        {"Primary 4", "primary", 4}, {"Primary 5", "primary", 5}, {"Primary 6", "primary", 6},
        {"JSS 1", "junior", 7}, {"JSS 2", "junior", 8}, {"JSS 3", "junior", 9},
        {"SSS 1", "senior", 10}, {"SSS 2", "senior", 11}, {"SSS 3", "senior", 12},
}

// Subjects: the NERDC curriculum offer. Primary and junior secondary
// carry the broad general-education set; senior secondary specializes
// into the art / science / commercial tracks.
var Subjects = []SeedSubject{
        // Primary (Basic 1-6)
        {"English Studies", "ENG-P", "primary", 1, "", false},
        {"Mathematics", "MTH-P", "primary", 2, "", false},
        {"Basic Science & Technology", "BST-P", "primary", 3, "", false},
        {"National Values Education", "NVE-P", "primary", 4, "", false},
        {"Pre-vocational Studies", "PVS-P", "primary", 5, "", false},
        {"Cultural & Creative Arts", "CCA-P", "primary", 6, "", false},
        {"Christian Religious Studies", "CRS", "both", 7, "art", false},
        {"Islamic Religious Studies", "IRS", "both", 8, "art", false},
        {"Nigerian Language", "NLG", "both", 9, "art", false},
        {"French", "FRE", "both", 10, "art", false},
        {"Physical & Health Education", "PHE", "both", 11, "", false},
        {"Agricultural Science", "AGR", "both", 12, "science", false},
        // Junior secondary (JSS 1-3)
        {"English Studies", "ENG-J", "junior", 20, "", false},
        {"Mathematics", "MTH-J", "junior", 21, "", false},
        {"Basic Science", "BSC", "junior", 22, "", false},
        {"Basic Technology", "BTE", "junior", 23, "", false},
        {"Social Studies", "SOS", "junior", 24, "", false},
        {"Civic Education", "CIV", "both", 25, "", true},
        {"Security Education", "SEC", "junior", 26, "", false},
        {"Business Studies", "BUS", "junior", 27, "commercial", false},
        {"Computer Studies", "CMP", "junior", 28, "science", false},
        {"Home Economics", "HEC", "junior", 29, "", false},
        {"Cultural & Creative Arts", "CCA-J", "junior", 30, "", false},
        // Senior secondary (SSS 1-3): core + the three tracks
        {"English Language", "ENG-S", "senior", 40, "", true},
        {"Mathematics", "MTH-S", "senior", 41, "", true},
        {"Economics", "ECO", "senior", 42, "commercial", false},
        {"Physics", "PHY", "senior", 43, "science", false},
        {"Chemistry", "CHM", "senior", 44, "science", false},
        {"Biology", "BIO", "senior", 45, "science", false},
        {"Geography", "GEO", "senior", 46, "science", false},
        {"Government", "GOV", "senior", 47, "art", false},
        {"Literature-in-English", "LIT", "senior", 48, "art", false},
        {"Commerce", "COM", "senior", 49, "commercial", false},
        {"Financial Accounting", "FAC", "senior", 50, "commercial", false},
        {"Further Mathematics", "FMT", "senior", 51, "science", false},
        {"Computer Science", "CSC", "senior", 52, "science", false},
        {"Technical Drawing", "TDR", "senior", 53, "science", false},
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
