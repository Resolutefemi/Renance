// Home Economics starter questions (junior band). Original content
// written for Renance.

package school

var examBankHomeEconomics = []SeedExamQuestion{
	// First Term
	{SubjectCode: "HEC", Band: "junior", Term: 1,
		Question:    "The six classes of food are carbohydrate, protein, fat, vitamins, minerals and:",
		Options:     [4]string{"Sugar", "Water", "Oil", "Salt"},
		AnswerIndex: 1,
		Explanation: "Water completes the six classes as an essential nutrient."},
	{SubjectCode: "HEC", Band: "junior", Term: 1,
		Question:    "A balanced diet contains all nutrient classes in the:",
		Options:     [4]string{"Wrong amounts", "Right proportions", "Same quantity", "Smallest quantity"},
		AnswerIndex: 1,
		Explanation: "Right proportions, not equal amounts, make a diet balanced."},
	{SubjectCode: "HEC", Band: "junior", Term: 1,
		Question:    "Proteins are mainly needed in the body for:",
		Options:     [4]string{"Energy only", "Growth and repair", "Cooling", "Colour"},
		AnswerIndex: 1,
		Explanation: "Amino acids build and repair body tissues."},

	// Second Term
	{SubjectCode: "HEC", Band: "junior", Term: 2,
		Question:    "The best method of preserving vegetables for a short period is:",
		Options:     [4]string{"Refrigeration", "Sun-drying", "Salting", "Canning"},
		AnswerIndex: 0,
		Explanation: "Cool temperatures slow spoilage without heavy processing."},
	{SubjectCode: "HEC", Band: "junior", Term: 2,
		Question:    "Kitchen hygiene requires washing hands:",
		Options:     [4]string{"Once a day", "Before and after handling food", "Only after eating", "Never"},
		AnswerIndex: 1,
		Explanation: "Clean hands break the chain that carries germs into food."},
	{SubjectCode: "HEC", Band: "junior", Term: 2,
		Question:    "Which of these is a correct way to extinguish an oil fire?",
		Options:     [4]string{"Pour water", "Cover the pot with a lid", "Fan it", "Add more oil"},
		AnswerIndex: 1,
		Explanation: "Smothering cuts off oxygen; water spreads burning oil."},

	// Third Term
	{SubjectCode: "HEC", Band: "junior", Term: 3,
		Question:    "The first stitch a beginner learns for a torn hem is usually the:",
		Options:     [4]string{"Running stitch", "Cross stitch", "Chain stitch", "Buttonhole stitch"},
		AnswerIndex: 0,
		Explanation: "The running stitch is the simplest, even in-and-out stitch."},
	{SubjectCode: "HEC", Band: "junior", Term: 3,
		Question:    "A family resource that money belongs to is described as:",
		Options:     [4]string{"Human resource", "Material or financial resource", "Time", "Energy"},
		AnswerIndex: 1,
		Explanation: "Financial resources are the money and assets a family manages."},
	{SubjectCode: "HEC", Band: "junior", Term: 3,
		Question:    "Good posture while sewing helps to prevent:",
		Options:     [4]string{"Neatness", "Back strain", "Speed", "Wrinkles in cloth"},
		AnswerIndex: 1,
		Explanation: "Sitting upright protects the back during long work."},
}

// Part two: three more per term.
var examBankHomeEconomicsP2 = []SeedExamQuestion{
        {SubjectCode: "HEC", Band: "junior", Term: 1,
                Question:    "Vitamin C is abundant in:",
                Options:     [4]string{"Citrus fruits", "Red meat", "Butter", "Rice"},
                AnswerIndex: 0,
                Explanation: "Oranges and other citrus carry ascorbic acid."},
        {SubjectCode: "HEC", Band: "junior", Term: 2,
                Question:    "The correct order for washing up is:",
                Options:     [4]string{"Glassware, plates, pots", "Pots first", "Whatever is nearest", "Dry first, wash later"},
                AnswerIndex: 0,
                Explanation: "Wash the cleanest first so greasy water lasts less."},
        {SubjectCode: "HEC", Band: "junior", Term: 3,
                Question:    "Ironing cotton clothing requires a ______ iron than silk.",
                Options:     [4]string{"Hotter", "Cooler", "Wetter", "Cleaner"},
                AnswerIndex: 0,
                Explanation: "Cotton tolerates high heat; silk scorches easily."},
}
