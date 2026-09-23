// Literature-in-English starter questions (senior band, art track).
// Original content written for Renance; grows term by term.

package school

var examBankLiterature = []SeedExamQuestion{
        // First Term: the elements
        {SubjectCode: "LIT", Band: "senior", Term: 1,
                Question:    "The sequence of events in a novel is called the:",
                Options:     [4]string{"Theme", "Plot", "Setting", "Mood"},
                AnswerIndex: 1,
                Explanation: "Plot is the arranged chain of happenings in a story."},
        {SubjectCode: "LIT", Band: "senior", Term: 1,
                Question:    "A comparison using like or as is a:",
                Options:     [4]string{"Metaphor", "Simile", "Hyperbole", "Irony"},
                AnswerIndex: 1,
                Explanation: "Similes compare explicitly with like or as."},
        {SubjectCode: "LIT", Band: "senior", Term: 1,
                Question:    "The time and place of a story make up its:",
                Options:     [4]string{"Plot", "Theme", "Setting", "Conflict"},
                AnswerIndex: 2,
                Explanation: "Setting anchors when and where events unfold."},
}
