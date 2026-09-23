// The starter exam bank: original, NERDC-aligned questions written for
// Renance. Nothing here is scraped or copied; every question is ours,
// tagged renance-original, and schools grow the pool from the portal.
// Subject codes match the curriculum catalog in curriculum.go, so the
// pour resolves subjects per school.

package school

// SeedExamQuestion is one bank row the seeder pours into a school.
type SeedExamQuestion struct {
	SubjectCode string // curriculum code, e.g. ENG-J
	Band        string // primary | junior | senior
	Term        int    // 1..3
	Question    string
	Options     [4]string
	AnswerIndex int
	Explanation string
}

// ExamBankBands lists the bands the starter bank covers.
var ExamBankBands = []string{"junior", "senior"}

// ExamBank returns every starter question across the bands. The store
// pour consumes this list.
func ExamBank() []SeedExamQuestion {
	all := make([]SeedExamQuestion, 0,
		len(examBankJunior)+len(examBankSeniorScience)+len(examBankSeniorCore))
	all = append(all, examBankJunior...)
	all = append(all, examBankSeniorScience...)
	all = append(all, examBankSeniorCore...)
	return all
}
