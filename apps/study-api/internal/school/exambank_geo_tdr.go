// Geography and Technical Drawing starter questions (senior band,
// science track). Original content written for Renance.

package school

var examBankGeography = []SeedExamQuestion{
        // First Term
        {SubjectCode: "GEO", Band: "senior", Term: 1,
                Question:    "The latitude that divides the Earth into two equal halves is the:",
                Options:     [4]string{"Tropic of Cancer", "Equator", "Prime Meridian", "Arctic Circle"},
                AnswerIndex: 1,
                Explanation: "The equator sits at 0 degrees and splits Earth into hemispheres."},
        {SubjectCode: "GEO", Band: "senior", Term: 1,
                Question:    "The movement of the Earth around the sun once a year is its:",
                Options:     [4]string{"Rotation", "Revolution", "Eclipse", "Axis"},
                AnswerIndex: 1,
                Explanation: "Revolution around the sun drives the yearly seasons."},
        {SubjectCode: "GEO", Band: "senior", Term: 1,
                Question:    "Which rock type forms from cooling magma?",
                Options:     [4]string{"Sedimentary", "Igneous", "Metamorphic", "Limestone"},
                AnswerIndex: 1,
                Explanation: "Magma solidifies into igneous rock like granite."},
}

var examBankTechDrawing = []SeedExamQuestion{
        // First Term
        {SubjectCode: "TDR", Band: "senior", Term: 1,
                Question:    "The standard sheet symbol for first-angle projection is identified by the:",
                Options:     [4]string{"Cone", "Truncated cone", "Circle", "Triangle alone"},
                AnswerIndex: 1,
                Explanation: "A truncated cone distinguishes first-angle projection symbols."},
        {SubjectCode: "TDR", Band: "senior", Term: 1,
                Question:    "Lines drawn to show hidden edges of an object are:",
                Options:     [4]string{"Continuous thick", "Dashed (short dashes)", "Chain lines", "Wavy lines"},
                AnswerIndex: 1,
                Explanation: "Short dashes mark edges invisible from the viewing direction."},
        {SubjectCode: "TDR", Band: "senior", Term: 1,
                Question:    "The true length of a line is seen on a view taken:",
                Options:     [4]string{"Parallel to the line", "At an angle", "Perpendicular only", "In section"},
                AnswerIndex: 0,
                Explanation: "A view plane parallel to the line shows it without foreshortening."},
}
