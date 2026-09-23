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

        // Second Term: drama and poetry
        {SubjectCode: "LIT", Band: "senior", Term: 2,
                Question:    "A long narrative poem celebrating heroic deeds is a(n):",
                Options:     [4]string{"Elegy", "Epic", "Ode", "Ballad"},
                AnswerIndex: 1,
                Explanation: "Epics exalt heroes and great deeds in elevated language."},
        {SubjectCode: "LIT", Band: "senior", Term: 2,
                Question:    "In drama, the speech a character makes alone on stage revealing inner thoughts is a:",
                Options:     [4]string{"Dialogue", "Soliloquy", "Aside", "Chorus"},
                AnswerIndex: 1,
                Explanation: "A soliloquy speaks thoughts aloud to the audience."},
        {SubjectCode: "LIT", Band: "senior", Term: 2,
                Question:    "A poem of mourning for the dead is an:",
                Options:     [4]string{"Elegy", "Ode", "Sonnet", "Idyll"},
                AnswerIndex: 0,
                Explanation: "Elegies lament loss and often end in consolation."},
