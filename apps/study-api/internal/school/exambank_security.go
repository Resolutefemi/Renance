// Security Education starter questions (junior band). Original content
// written for Renance.

package school

var examBankSecurity = []SeedExamQuestion{
	// First Term
	{SubjectCode: "SEC", Band: "junior", Term: 1,
		Question:    "Security is best described as freedom from:",
		Options:     [4]string{"Homework", "Danger and threat", "Games", "Company"},
		AnswerIndex: 1,
		Explanation: "Security protects life, property and information from harm."},
	{SubjectCode: "SEC", Band: "junior", Term: 1,
		Question:    "The emergency number for the Nigeria Police is:",
		Options:     [4]string{"199", "112", "123", "767"},
		AnswerIndex: 1,
		Explanation: "112 is the national emergency line that routes to police services."},
	{SubjectCode: "SEC", Band: "junior", Term: 1,
		Question:    "A stranger who offers you a lift on the way to school should be:",
		Options:     [4]string{"Accepted", "Reported and refused", "Followed home", "Paid"},
		AnswerIndex: 1,
		Explanation: "Children report such approaches to trusted adults immediately."},

	// Second Term
	{SubjectCode: "SEC", Band: "junior", Term: 2,
		Question:    "Keeping your online account safe requires a password that is:",
		Options:     [4]string{"Shared with friends", "Private and hard to guess", "Your birthday", "Written on the board"},
		AnswerIndex: 1,
		Explanation: "Passwords stay private, long and unpredictable."},
	{SubjectCode: "SEC", Band: "junior", Term: 2,
		Question:    "Which of these is a common cybercrime?",
		Options:     [4]string{"Typing practice", "Identity theft", "Painting", "Singing"},
		AnswerIndex: 1,
		Explanation: "Identity theft steals personal data for fraud."},
	{SubjectCode: "SEC", Band: "junior", Term: 2,
		Question:    "Suspicious emails asking for bank details are called:",
		Options:     [4]string{"Newsletters", "Phishing", "Blogs", "Spam filters"},
		AnswerIndex: 1,
		Explanation: "Phishing baits users into handing over sensitive information."},

	// Third Term
	{SubjectCode: "SEC", Band: "junior", Term: 3,
		Question:    "The first response to a fire outbreak in a classroom is to:",
		Options:     [4]string{"Post videos", "Raise the alarm and evacuate", "Hide in class", "Open more windows"},
		AnswerIndex: 1,
		Explanation: "Alert everyone and leave by the exit before any other action."},
	{SubjectCode: "SEC", Band: "junior", Term: 3,
		Question:    "Neighbourhood watch groups help security by:",
		Options:     [4]string{"Patrolling and reporting", "Collecting taxes", "Judging cases", "Selling land"},
		AnswerIndex: 0,
		Explanation: "Vigilante watch groups observe, report and support agencies."},
	{SubjectCode: "SEC", Band: "junior", Term: 3,
		Question:    "Emergency exits in a building must be kept:",
		Options:     [4]string{"Locked always", "Clear and accessible", "Broken", "Secret"},
		AnswerIndex: 1,
		Explanation: "Blocked exits turn small emergencies into disasters."},
}
