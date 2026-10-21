// Basic Technology starter questions (junior band). Original content
// written for Renance.

package school

var examBankBasicTech = []SeedExamQuestion{
	// First Term
	{SubjectCode: "BTE", Band: "junior", Term: 1,
		Question:    "Technical drawing that shows the exact shape of an object from one side is a:",
		Options:     [4]string{"Freehand sketch", "Orthographic view", "Photograph", "Map"},
		AnswerIndex: 1,
		Explanation: "Orthographic projection shows faces of the object to scale."},
	{SubjectCode: "BTE", Band: "junior", Term: 1,
		Question:    "The drawing instrument used to draw circles and arcs is the:",
		Options:     [4]string{"Set square", "Compass", "Protractor", "Tee-square"},
		AnswerIndex: 1,
		Explanation: "A compass holds a pencil point and swings a radius."},
	{SubjectCode: "BTE", Band: "junior", Term: 1,
		Question:    "Which scale reduces a 10 m building onto a 10 cm drawing?",
		Options:     [4]string{"1:1", "1:10", "1:100", "10:1"},
		AnswerIndex: 2,
		Explanation: "1:100 means 1 cm on paper equals 100 cm (1 m) on site."},

	// Second Term
	{SubjectCode: "BTE", Band: "junior", Term: 2,
		Question:    "The energy stored in a stretched catapult rubber is:",
		Options:     [4]string{"Kinetic energy", "Potential energy", "Chemical energy", "Heat energy"},
		AnswerIndex: 1,
		Explanation: "Stretched material stores elastic potential energy."},
	{SubjectCode: "BTE", Band: "junior", Term: 2,
		Question:    "A simple machine changes the:",
		Options:     [4]string{"Amount of work done", "Point, direction or size of a force", "Energy created", "Mass of the load"},
		AnswerIndex: 1,
		Explanation: "Machines transmit forces; total work is never reduced."},
	{SubjectCode: "BTE", Band: "junior", Term: 2,
		Question:    "The mechanical advantage of a lever with effort arm 60 cm and load arm 20 cm is:",
		Options:     [4]string{"3", "4", "40", "80"},
		AnswerIndex: 0,
		Explanation: "MA = effort arm / load arm = 60 / 20 = 3."},

	// Third Term
	{SubjectCode: "BTE", Band: "junior", Term: 3,
		Question:    "Which of these is a method of separating an impure solid?",
		Options:     [4]string{"Magnetism", "Filtration", "Sieving", "Sublimation"},
		AnswerIndex: 0,
		Explanation: "Magnetism removes iron filings from a solid mixture."},
	{SubjectCode: "BTE", Band: "junior", Term: 3,
		Question:    "The two square edges of a set square are used to draw:",
		Options:     [4]string{"Circles", "Perpendicular and 45 degree lines", "Arbitrary curves", "Freehand lines"},
		AnswerIndex: 1,
		Explanation: "Set squares draw vertical, perpendicular and angled lines."},
	{SubjectCode: "BTE", Band: "junior", Term: 3,
		Question:    "Friction in moving machine parts is reduced by:",
		Options:     [4]string{"Rust", "Lubrication", "Rough surfaces", "Extra load"},
		AnswerIndex: 1,
		Explanation: "Oil or grease between surfaces lowers friction and wear."},
}

// Part two: three more per term.
var examBankBasicTechP2 = []SeedExamQuestion{
        {SubjectCode: "BTE", Band: "junior", Term: 1,
                Question:    "The instrument for measuring angles in degrees is the:",
                Options:     [4]string{"Protractor", "Dividers", "Ruler", "French curve"},
                AnswerIndex: 0,
                Explanation: "The protractor's semicircular edge reads angles."},
        {SubjectCode: "BTE", Band: "junior", Term: 2,
                Question:    "A pulley with a fixed axle changes mainly the:",
                Options:     [4]string{"Direction of effort", "Size of the load", "Work done", "Energy created"},
                AnswerIndex: 0,
                Explanation: "A single fixed pulley redirects the pull for convenience."},
        {SubjectCode: "BTE", Band: "junior", Term: 3,
                Question:    "The first-aid response to a small cut in the workshop is to:",
                Options:     [4]string{"Clean and cover it", "Ignore it", "Blow on it", "Rub soil on it"},
                AnswerIndex: 0,
                Explanation: "Clean, dress and report the injury to the teacher."},
}
