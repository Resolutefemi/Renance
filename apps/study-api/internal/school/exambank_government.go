// Government starter questions (senior band, art track). Original
// content written for Renance; the bank grows term by term.

package school

var examBankGovernment = []SeedExamQuestion{
	// First Term
	{SubjectCode: "GOV", Band: "senior", Term: 1,
		Question:    "A state is characterized by population, territory, government and:",
		Options:     [4]string{"Currency", "Sovereignty", "Language", "Army"},
		AnswerIndex: 1,
		Explanation: "Sovereignty is the supreme authority within a territory."},
	{SubjectCode: "GOV", Band: "senior", Term: 1,
		Question:    "The theory of separation of powers is associated with:",
		Options:     [4]string{"Karl Marx", "Montesquieu", "Adam Smith", "John Locke alone"},
		AnswerIndex: 1,
		Explanation: "Montesquieu argued for dividing legislature, executive and judiciary."},
	{SubjectCode: "GOV", Band: "senior", Term: 1,
		Question:    "Democracy differs from monarchy because power belongs to:",
		Options:     [4]string{"The king", "The people", "The army", "The priests"},
		AnswerIndex: 1,
		Explanation: "In democracy the people hold sovereignty through elections."},

	// Second Term
	{SubjectCode: "GOV", Band: "senior", Term: 2,
		Question:    "Federalism is a system where power is shared between:",
		Options:     [4]string{"The rich and the poor", "Central and component units", "The police and courts", "Two presidents"},
		AnswerIndex: 1,
		Explanation: "A federation divides powers between national and state or regional governments."},
	{SubjectCode: "GOV", Band: "senior", Term: 2,
		Question:    "The body that interprets the law in a state is the:",
		Options:     [4]string{"Legislature", "Executive", "Judiciary", "Civil service"},
		AnswerIndex: 2,
		Explanation: "Courts interpret laws and settle disputes."},
	{SubjectCode: "GOV", Band: "senior", Term: 2,
		Question:    "Universal adult suffrage means every adult citizen has the right to:",
		Options:     [4]string{"Contest only", "Vote in elections", "Bear arms", "Free education"},
		AnswerIndex: 1,
		Explanation: "Suffrage is the voting right, regardless of status."},

	// Third Term
	{SubjectCode: "GOV", Band: "senior", Term: 3,
		Question:    "Nigeria became a federation with the creation of regions in:",
		Options:     [4]string{"1914", "1946", "1954", "1960"},
		AnswerIndex: 2,
		Explanation: "The 1954 constitution established a federal structure."},
	{SubjectCode: "GOV", Band: "senior", Term: 3,
		Question:    "The change of Nigeria's capital from Lagos to Abuja happened in:",
		Options:     [4]string{"1976", "1981", "1991", "1999"},
		AnswerIndex: 2,
		Explanation: "Abuja officially became the seat of government in 1991."},
	{SubjectCode: "GOV", Band: "senior", Term: 3,
		Question:    "Which body audits government spending in Nigeria?",
		Options:     [4]string{"The legislature alone", "The Auditor-General", "The police", "The senate president"},
		AnswerIndex: 1,
		Explanation: "The Auditor-General checks public accounts for the nation."},
}
