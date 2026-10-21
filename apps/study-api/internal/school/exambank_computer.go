// Computer Studies starter questions (junior band). Original content
// written for Renance.

package school

var examBankComputer = []SeedExamQuestion{
	// First Term
	{SubjectCode: "CMP", Band: "junior", Term: 1,
		Question:    "The physical parts of a computer are called:",
		Options:     [4]string{"Software", "Hardware", "Programs", "Data"},
		AnswerIndex: 1,
		Explanation: "Hardware is the tangible machinery; software is the instructions."},
	{SubjectCode: "CMP", Band: "junior", Term: 1,
		Question:    "Which unit is the brain of the computer?",
		Options:     [4]string{"RAM", "CPU", "Monitor", "Keyboard"},
		AnswerIndex: 1,
		Explanation: "The central processing unit executes instructions."},
	{SubjectCode: "CMP", Band: "junior", Term: 1,
		Question:    "1 kilobyte equals approximately:",
		Options:     [4]string{"8 bytes", "100 bytes", "1024 bytes", "1 million bytes"},
		AnswerIndex: 2,
		Explanation: "A kilobyte is 1024 bytes in binary measure."},

	// Second Term
	{SubjectCode: "CMP", Band: "junior", Term: 2,
		Question:    "Which of these is an input device?",
		Options:     [4]string{"Printer", "Scanner", "Speaker", "Monitor"},
		AnswerIndex: 1,
		Explanation: "A scanner feeds information into the computer."},
	{SubjectCode: "CMP", Band: "junior", Term: 2,
		Question:    "Software that manages computer hardware and other programs is the:",
		Options:     [4]string{"Spreadsheet", "Operating system", "Browser", "Antivirus"},
		AnswerIndex: 1,
		Explanation: "The operating system supervises resources and applications."},
	{SubjectCode: "CMP", Band: "junior", Term: 2,
		Question:    "The binary number 101 equals which decimal number?",
		Options:     [4]string{"3", "5", "6", "7"},
		AnswerIndex: 1,
		Explanation: "101 binary is 4 + 0 + 1 = 5 in decimal."},

	// Third Term
	{SubjectCode: "CMP", Band: "junior", Term: 3,
		Question:    "A collection of related web pages is called a:",
		Options:     [4]string{"Browser", "Website", "Hyperlink", "Server"},
		AnswerIndex: 1,
		Explanation: "A website groups pages under one address."},
	{SubjectCode: "CMP", Band: "junior", Term: 3,
		Question:    "The best way to protect a computer from viruses is to:",
		Options:     [4]string{"Share flash drives freely", "Install updated antivirus", "Open every email attachment", "Switch it off often"},
		AnswerIndex: 1,
		Explanation: "Updated antivirus plus careful habits keeps systems safe."},
	{SubjectCode: "CMP", Band: "junior", Term: 3,
		Question:    "Word processing software is mainly used to:",
		Options:     [4]string{"Create documents", "Edit photographs", "Play games", "Design buildings"},
		AnswerIndex: 0,
		Explanation: "Word processors type, edit and format text documents."},
}

// Part two: three more per term.
var examBankComputerP2 = []SeedExamQuestion{
        {SubjectCode: "CMP", Band: "junior", Term: 1,
                Question:    "Which of these is permanent storage that keeps files when powered off?",
                Options:     [4]string{"RAM", "Hard disk", "CPU cache", "Registers"},
                AnswerIndex: 1,
                Explanation: "Disks are non-volatile; RAM forgets at power loss."},
        {SubjectCode: "CMP", Band: "junior", Term: 2,
                Question:    "The small blinking line that shows where typing goes is the:",
                Options:     [4]string{"Cursor", "Icon", "Folder", "Desktop"},
                AnswerIndex: 0,
                Explanation: "The insertion cursor marks your place in the text."},
        {SubjectCode: "CMP", Band: "junior", Term: 3,
                Question:    "Sending a message instantly over the internet is:",
                Options:     [4]string{"Email", "Printing", "Scanning", "Faxing only"},
                AnswerIndex: 0,
                Explanation: "Electronic mail travels in seconds across networks."},
}
