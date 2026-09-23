// Business Studies and Physical & Health Education starter questions
// (junior band). Original content written for Renance.

package school

var examBankBusiness = []SeedExamQuestion{
        // First Term
        {SubjectCode: "BUS", Band: "junior", Term: 1,
                Question:    "A business is an organization that provides goods or services to:",
                Options:     [4]string{"Make a profit", "Lose money", "Hide money", "Give gifts"},
                AnswerIndex: 0,
                Explanation: "Profit motivates business activity alongside service."},
        {SubjectCode: "BUS", Band: "junior", Term: 1,
                Question:    "The two broad types of business activity are industry and:",
                Options:     [4]string{"Commerce", "Agriculture", "Banking", "Travel"},
                AnswerIndex: 0,
                Explanation: "Industry produces; commerce distributes."},
        {SubjectCode: "BUS", Band: "junior", Term: 1,
                Question:    "A sole proprietorship is owned by:",
                Options:     [4]string{"Two people", "One person", "Shareholders", "The government"},
                AnswerIndex: 1,
                Explanation: "One owner carries the risk and the profit alone."},
}

var examBankPHE = []SeedExamQuestion{
        // First Term
        {SubjectCode: "PHE", Band: "junior", Term: 1,
                Question:    "Physical fitness is the ability of the body to:",
                Options:     [4]string{"Sleep well", "Carry out daily work without undue fatigue", "Grow tall", "Read fast"},
                AnswerIndex: 1,
                Explanation: "Fitness means performing daily tasks with energy to spare."},
        {SubjectCode: "PHE", Band: "junior", Term: 1,
                Question:    "The number of players in a football (soccer) team on the pitch is:",
                Options:     [4]string{"9", "10", "11", "12"},
                AnswerIndex: 2,
                Explanation: "Eleven players per side, including the goalkeeper."},
        {SubjectCode: "PHE", Band: "junior", Term: 1,
                Question:    "Warming up before exercise mainly helps to:",
                Options:     [4]string{"Waste time", "Prevent muscle injury", "Increase weight", "Cool the body"},
                AnswerIndex: 1,
                Explanation: "Gradual warm-up raises blood flow and readies muscles."},
}
