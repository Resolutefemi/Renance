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
}
