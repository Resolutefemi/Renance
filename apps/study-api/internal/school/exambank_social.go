// Social Studies starter questions (junior band). Original content
// written for Renance.

package school

var examBankSocial = []SeedExamQuestion{
	// First Term
	{SubjectCode: "SOS", Band: "junior", Term: 1,
		Question:    "A family made up of father, mother and children is called:",
		Options:     [4]string{"Extended family", "Nuclear family", "Compound family", "Communal family"},
		AnswerIndex: 1,
		Explanation: "The nuclear family is the parents and their children."},
	{SubjectCode: "SOS", Band: "junior", Term: 1,
		Question:    "The process by which a child learns the culture of his society is:",
		Options:     [4]string{"Socialization", "Migration", "Adaptation", "Integration"},
		AnswerIndex: 0,
		Explanation: "Socialization passes values, language and norms to the young."},
	{SubjectCode: "SOS", Band: "junior", Term: 1,
		Question:    "Which of these is a primary social group?",
		Options:     [4]string{"The family", "A political party", "A trade union", "A company"},
		AnswerIndex: 0,
		Explanation: "The family is the first and most intimate social group."},

	// Second Term
	{SubjectCode: "SOS", Band: "junior", Term: 2,
		Question:    "Culture that is passed from generation to generation through customs is called:",
		Options:     [4]string{"Material culture", "Non-material culture", "Heritage", "Fashion"},
		AnswerIndex: 2,
		Explanation: "Heritage covers customs, beliefs and artifacts handed down."},
	{SubjectCode: "SOS", Band: "junior", Term: 2,
		Question:    "Marriage between a man and one wife is called:",
		Options:     [4]string{"Polygamy", "Monogamy", "Polyandry", "Endogamy"},
		AnswerIndex: 1,
		Explanation: "Monogamy is one spouse at a time."},
	{SubjectCode: "SOS", Band: "junior", Term: 2,
		Question:    "The movement of people from villages to cities in search of better life is:",
		Options:     [4]string{"Immigration", "Rural-urban migration", "Emigration", "Deportation"},
		AnswerIndex: 1,
		Explanation: "Rural-urban migration is a common feature of developing economies."},

	// Third Term
	{SubjectCode: "SOS", Band: "junior", Term: 3,
		Question:    "Which of these is a consequence of over-population?",
		Options:     [4]string{"More jobs per person", "Pressure on social services", "Lower crime rates", "Cheaper housing"},
		AnswerIndex: 1,
		Explanation: "Over-population stretches schools, hospitals and housing."},
	{SubjectCode: "SOS", Band: "junior", Term: 3,
		Question:    "The safest way to resolve a conflict between two parties is:",
		Options:     [4]string{"Fighting", "Dialogue", "Retaliation", "Silence"},
		AnswerIndex: 1,
		Explanation: "Dialogue addresses the grievance without new harm."},
	{SubjectCode: "SOS", Band: "junior", Term: 3,
		Question:    "The three major ethnic groups in Nigeria are Hausa, Igbo and:",
		Options:     [4]string{"Fulani", "Yoruba", "Tiv", "Efik"},
		AnswerIndex: 1,
		Explanation: "Hausa, Igbo and Yoruba are the three largest groups."},
}
