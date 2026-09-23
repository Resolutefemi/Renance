// Further Mathematics and Computer Science starter questions (senior
// band, science track). Original content written for Renance.

package school

var examBankFurtherMaths = []SeedExamQuestion{
        // First Term
        {SubjectCode: "FMT", Band: "senior", Term: 1,
                Question:    "The derivative of 3x squared with respect to x is:",
                Options:     [4]string{"3x", "6x", "6x squared", "x cubed"},
                AnswerIndex: 1,
                Explanation: "Differentiate 3x^2: multiply by the power and reduce it, giving 6x."},
        {SubjectCode: "FMT", Band: "senior", Term: 1,
                Question:    "If A is a 2 by 2 matrix with determinant 0, then A is:",
                Options:     [4]string{"Invertible", "Singular", "Symmetric", "Orthogonal"},
                AnswerIndex: 1,
                Explanation: "A zero determinant makes the matrix singular and non-invertible."},
        {SubjectCode: "FMT", Band: "senior", Term: 1,
                Question:    "The roots of the quadratic x squared - 5x + 6 = 0 are:",
                Options:     [4]string{"1 and 6", "2 and 3", "3 and 4", "-2 and -3"},
                AnswerIndex: 1,
                Explanation: "Factor as (x-2)(x-3), so the roots are 2 and 3."},
}

var examBankCompSci = []SeedExamQuestion{
        // First Term
        {SubjectCode: "CSC", Band: "senior", Term: 1,
                Question:    "An algorithm is best described as a:",
                Options:     [4]string{"Computer part", "Step-by-step solution procedure", "Programming language", "File format"},
                AnswerIndex: 1,
                Explanation: "Algorithms are ordered steps that solve a defined problem."},
        {SubjectCode: "CSC", Band: "senior", Term: 1,
                Question:    "Which number system uses only 0 and 1?",
                Options:     [4]string{"Decimal", "Binary", "Octal", "Hexadecimal"},
                AnswerIndex: 1,
                Explanation: "Binary is base two, the machine's native language."},
        {SubjectCode: "CSC", Band: "senior", Term: 1,
                Question:    "A flowchart symbol shaped like a diamond represents:",
                Options:     [4]string{"Start", "Input", "Decision", "Output"},
                AnswerIndex: 2,
                Explanation: "Diamonds test a condition and branch on the result."},
}
