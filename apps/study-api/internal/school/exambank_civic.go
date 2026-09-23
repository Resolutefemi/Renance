// Civic Education starter questions (junior band). Original content
// written for Renance; the subject is core across the ladder.

package school

var examBankCivic = []SeedExamQuestion{
	// First Term
	{SubjectCode: "CIV", Band: "junior", Term: 1,
		Question:    "Democracy is best described as government of the people, by the people and:",
		Options:     [4]string{"For the rulers", "For the people", "For the army", "For the rich"},
		AnswerIndex: 1,
		Explanation: "Abraham Lincoln's definition ends with for the people."},
	{SubjectCode: "CIV", Band: "junior", Term: 1,
		Question:    "A citizen of a country is a person who enjoys rights and performs:",
		Options:     [4]string{"Punishments", "Duties", "Trades", "Ceremonies"},
		AnswerIndex: 1,
		Explanation: "Citizenship pairs rights with duties and obligations."},
	{SubjectCode: "CIV", Band: "junior", Term: 1,
		Question:    "The green in the Nigerian flag stands for:",
		Options:     [4]string{"Peace", "Forests and agriculture", "Courage", "Wealth"},
		AnswerIndex: 1,
		Explanation: "Green represents forests and farmland; white stands for peace."},

	// Second Term
	{SubjectCode: "CIV", Band: "junior", Term: 2,
		Question:    "The rule of law means that nobody is:",
		Options:     [4]string{"Allowed to vote", "Above the law", "A member of parliament", "Entitled to a fair hearing"},
		AnswerIndex: 1,
		Explanation: "Under the rule of law every person, however highly placed, is subject to the law."},
	{SubjectCode: "CIV", Band: "junior", Term: 2,
		Question:    "Which of these is a civic duty of a good citizen?",
		Options:     [4]string{"Paying taxes", "Attending parties", "Travelling abroad", "Buying property"},
		AnswerIndex: 0,
		Explanation: "Paying taxes funds public services; it is a legal duty."},
	{SubjectCode: "CIV", Band: "junior", Term: 2,
		Question:    "The process by which a person becomes a citizen of a country by birth is:",
		Options:     [4]string{"Naturalization", "Registration", "Citizenship by birth", "Dual citizenship"},
		AnswerIndex: 2,
		Explanation: "Birth citizenship flows from parents or place of birth, not application."},

	// Third Term
	{SubjectCode: "CIV", Band: "junior", Term: 3,
		Question:    "National consciousness means having a sense of belonging to one's:",
		Options:     [4]string{"Village only", "Ethnic group only", "Nation", "Family only"},
		AnswerIndex: 2,
		Explanation: "National consciousness puts the nation above sectional interests."},
	{SubjectCode: "CIV", Band: "junior", Term: 3,
		Question:    "The agency responsible for conducting elections in Nigeria is:",
		Options:     [4]string{"EFCC", "INEC", "NYSC", "NAPTAN"},
		AnswerIndex: 1,
		Explanation: "The Independent National Electoral Commission organizes federal elections."},
	{SubjectCode: "CIV", Band: "junior", Term: 3,
		Question:    "Which of these best describes integrity?",
		Options:     [4]string{"Saying one thing and doing another", "Being honest and consistent", "Avoiding hard work", "Following the crowd"},
		AnswerIndex: 1,
		Explanation: "Integrity means honesty plus consistency between word and action."},
}

// Part two: three more per term.
var examBankCivicP2 = []SeedExamQuestion{
        {SubjectCode: "CIV", Band: "junior", Term: 1,
                Question:    "The yellow colour on the Nigerian coat of arms represents:",
                Options:     [4]string{"The nation's flower", "The plains and deserts", "The seas", "The sky"},
                AnswerIndex: 1,
                Explanation: "The coat of arms band blends colours of the plains and deserts."},
        {SubjectCode: "CIV", Band: "junior", Term: 2,
                Question:    "A responsible parent provides the family with:",
                Options:     [4]string{"Needs like food and shelter", "Only phones", "Only games", "Nothing"},
                AnswerIndex: 0,
                Explanation: "Family welfare begins with meeting basic needs."},
        {SubjectCode: "CIV", Band: "junior", Term: 3,
                Question:    "National service that builds unity among graduates is:",
                Options:     [4]string{"NYSC", "JAMB", "WAEC", "NEPA"},
                AnswerIndex: 0,
                Explanation: "The NYSC scheme posts graduates across states to serve."},
}
