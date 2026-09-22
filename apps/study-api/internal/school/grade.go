package school

// Grade maps a total score (0-100) onto the Nigerian report-card scale.
type Grade struct {
	Letter string
	Remark string
}

// GradeFor returns the letter grade + remark for a percentage total.
// Scale: A 70-100 Excellent, B 60-69 Very Good, C 50-59 Good,
// D 45-49 Pass, E 40-44 Fair, F 0-39 Fail.
func GradeFor(total float64) Grade {
	switch {
	case total >= 70:
		return Grade{"A", "Excellent"}
	case total >= 60:
		return Grade{"B", "Very Good"}
	case total >= 50:
		return Grade{"C", "Good"}
	case total >= 45:
		return Grade{"D", "Pass"}
	case total >= 40:
		return Grade{"E", "Fair"}
	default:
		return Grade{"F", "Fail"}
	}
}

// TermName renders 1 -> "First Term" etc.
func TermName(term int) string {
	switch term {
	case 1:
		return "First Term"
	case 2:
		return "Second Term"
	case 3:
		return "Third Term"
	default:
		return ""
	}
}
