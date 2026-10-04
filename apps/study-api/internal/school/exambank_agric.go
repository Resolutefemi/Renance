// Agricultural Science starter questions (junior band, subject offered
// across both bands). Original content written for Renance.

package school

var examBankAgric = []SeedExamQuestion{
	// First Term
	{SubjectCode: "AGR", Band: "junior", Term: 1,
		Question:    "The branch of agriculture that deals with fish production is:",
		Options:     [4]string{"Poultry", "Fishery", "Apiculture", "Horticulture"},
		AnswerIndex: 1,
		Explanation: "Fishery covers rearing and harvesting of fish."},
	{SubjectCode: "AGR", Band: "junior", Term: 1,
		Question:    "The first step in land preparation for farming is:",
		Options:     [4]string{"Planting", "Clearing", "Weeding", "Harvesting"},
		AnswerIndex: 1,
		Explanation: "Clearing removes vegetation before ploughing and planting."},
	{SubjectCode: "AGR", Band: "junior", Term: 1,
		Question:    "Which of these is a farm tool used for tilling soil?",
		Options:     [4]string{"Cutlass", "Hoe", "Watering can", "Wheelbarrow"},
		AnswerIndex: 1,
		Explanation: "The hoe digs and turns the topsoil."},

	// Second Term
	{SubjectCode: "AGR", Band: "junior", Term: 2,
		Question:    "Crops grown mainly for direct human food are called:",
		Options:     [4]string{"Cash crops", "Food crops", "Fiber crops", "Ornamental crops"},
		AnswerIndex: 1,
		Explanation: "Food crops like maize and cassava feed households directly."},
	{SubjectCode: "AGR", Band: "junior", Term: 2,
		Question:    "The reproductive part of a flowering plant is the:",
		Options:     [4]string{"Root", "Stem", "Flower", "Leaf"},
		AnswerIndex: 2,
		Explanation: "Flowers carry the organs that produce seeds."},
	{SubjectCode: "AGR", Band: "junior", Term: 2,
		Question:    "Which nutrient in fertilizer promotes leafy growth?",
		Options:     [4]string{"Nitrogen", "Phosphorus", "Potassium", "Calcium"},
		AnswerIndex: 0,
		Explanation: "Nitrogen drives vegetative, leafy development."},

	// Third Term
	{SubjectCode: "AGR", Band: "junior", Term: 3,
		Question:    "The rearing of honey bees is called:",
		Options:     [4]string{"Sericulture", "Apiculture", "Aquaculture", "Pisciculture"},
		AnswerIndex: 1,
		Explanation: "Apiculture is bee-keeping for honey and wax."},
	{SubjectCode: "AGR", Band: "junior", Term: 3,
		Question:    "A disease of crops spread by aphids is best controlled by:",
		Options:     [4]string{"Spraying insecticide", "Over-watering", "Adding more seeds", "Weeding only"},
		AnswerIndex: 0,
		Explanation: "Controlling the aphid vector with insecticide limits spread."},
	{SubjectCode: "AGR", Band: "junior", Term: 3,
		Question:    "Proper storage of farm produce mainly prevents:",
		Options:     [4]string{"Germination", "Pest damage and spoilage", "Photosynthesis", "Pollination"},
		AnswerIndex: 1,
		Explanation: "Good storage keeps pests and moisture away from produce."},
}

// Part two: three more per term.
var examBankAgricP2 = []SeedExamQuestion{
        {SubjectCode: "AGR", Band: "junior", Term: 1,
                Question:    "The rearing of cattle for milk and meat is called:",
                Options:     [4]string{"Dairy farming", "Fish farming", "Poultry", "Bee-keeping"},
                AnswerIndex: 0,
                Explanation: "Dairy farms keep milking cattle for milk products."},
        {SubjectCode: "AGR", Band: "junior", Term: 2,
                Question:    "The part of the plant that absorbs water from the soil is the:",
                Options:     [4]string{"Root", "Leaf", "Flower", "Fruit"},
                AnswerIndex: 0,
                Explanation: "Root hairs draw water and dissolved minerals upward."},
        {SubjectCode: "AGR", Band: "junior", Term: 3,
                Question:    "Which of these animals is a ruminant?",
                Options:     [4]string{"Goat", "Dog", "Cat", "Chicken"},
                AnswerIndex: 0,
                Explanation: "Ruminants chew cud; goats and cattle do."},
}
