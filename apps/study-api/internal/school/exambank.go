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
var extraBanks []SeedExamQuestion

func ExamBank() []SeedExamQuestion {
	all := make([]SeedExamQuestion, 0,
		len(examBankJunior)+len(examBankSeniorScience)+len(examBankSeniorCore))
	all = append(all, examBankJunior...)
	all = append(all, examBankSeniorScience...)
	all = append(all, examBankSeniorCore...)
	all = append(all, extraBanks...)
	return all
}

// extraBanks gathers the per-subject starter files added after the
// first three core files; each lands in its own file under this
// package and joins the pour here.
func init() {
	extraBanks = append(extraBanks, examBankCivic...)
	extraBanks = append(extraBanks, examBankSocial...)
	extraBanks = append(extraBanks, examBankBasicTech...)
	extraBanks = append(extraBanks, examBankComputer...)
	extraBanks = append(extraBanks, examBankAgric...)
	extraBanks = append(extraBanks, examBankCRS...)
	extraBanks = append(extraBanks, examBankIRS...)
	extraBanks = append(extraBanks, examBankFrench...)
	extraBanks = append(extraBanks, examBankGovernment...)
	extraBanks = append(extraBanks, examBankGovernmentP2...)
	extraBanks = append(extraBanks, examBankLiterature...)
	extraBanks = append(extraBanks, examBankLiteratureP2...)
	extraBanks = append(extraBanks, examBankCommerce...)
	extraBanks = append(extraBanks, examBankCommerceP2...)
	extraBanks = append(extraBanks, examBankAccounting...)
	extraBanks = append(extraBanks, examBankAccountingP2...)
	extraBanks = append(extraBanks, examBankFurtherMaths...)
	extraBanks = append(extraBanks, examBankCompSci...)
	extraBanks = append(extraBanks, examBankGeography...)
	extraBanks = append(extraBanks, examBankTechDrawing...)
	extraBanks = append(extraBanks, examBankSecurity...)
	extraBanks = append(extraBanks, examBankHomeEconomics...)
	extraBanks = append(extraBanks, examBankBusiness...)
	extraBanks = append(extraBanks, examBankPHE...)
	extraBanks = append(extraBanks, examBankPrimaryCore...)
	extraBanks = append(extraBanks, examBankPrimaryWider...)
	extraBanks = append(extraBanks, examBankPrevocational...)
	extraBanks = append(extraBanks, examBankCCA...)
}
