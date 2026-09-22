package school

// SeedTopic is one note-carrying topic of a seed syllabus.
type SeedTopic struct {
	Title   string
	Week    int
	Content string
}

// SeedSyllabus declares a term's scheme of work + topics + notes for one
// class+subject pair. Schools instantiate these via the seed endpoint and
// then edit everything in the portal.
type SeedSyllabus struct {
	Class   string
	Subject string
	Term    int
	Topics  []SeedTopic
}

// SeedSyllabuses: NERDC-aligned first-term schemes of work for JSS 1 core
// subjects and Primary 4, each topic carrying a starter note. Schools can
// edit or replace every word of this in the portal; the point is that a
// new school opens a populated syllabus, not a blank screen.
var SeedSyllabuses = []SeedSyllabus{
	{
		Class: "JSS 1", Subject: "English Studies", Term: 1,
		Topics: []SeedTopic{
			{"The Sentence", 1, "A sentence is a group of words that expresses a complete thought. Every sentence begins with a capital letter and ends with a full stop, a question mark or an exclamation mark. A sentence must have a subject (who or what) and a predicate (what is said about the subject). Example: 'Ade reads his book every night.' Compare this with a phrase such as 'in the garden', which does not express a complete thought on its own."},
			{"Nouns", 2, "A noun is a naming word. It names a person (teacher, Chike), a place (Lagos, school), a thing (book, chalk) or an idea (honesty, freedom). Nouns are divided into proper nouns, which name particular people or places and always take a capital letter, and common nouns, which name general things. Nouns can also be concrete (things we can touch) or abstract (ideas we cannot touch)."},
			{"Pronouns", 3, "A pronoun is a word used in place of a noun to avoid repeating it. The personal pronouns are I, you, he, she, it, we and they. Pronouns change form depending on their job in the sentence: 'She gave the book to me' uses 'she' as the subject and 'me' as the object. Possessive pronouns such as mine, yours, his, hers, ours and theirs show ownership."},
			{"Verbs", 4, "A verb is an action or state-of-being word. Action verbs show what the subject does: run, write, sing, jump. Being verbs (is, am, are, was, were) tell us what the subject is or was. Verbs also change form to show time, which is called tense: 'I walk' (present), 'I walked' (past), 'I will walk' (future). Every complete sentence must contain at least one verb."},
			{"Adjectives", 5, "An adjective is a word that describes a noun or pronoun. It tells us what kind (a red bag), how many (three pupils), or which one (that tall boy). Adjectives make our speaking and writing clearer and more interesting. The comparison forms are: positive (tall), comparative (taller than) and superlative (the tallest)."},
			{"Adverbs", 6, "An adverb is a word that describes a verb, an adjective or another adverb. Adverbs tell us how (quickly, carefully), when (today, soon), where (here, outside) and how often (always, sometimes). Many adverbs of manner end in -ly, formed from adjectives: quick becomes quickly, careful becomes carefully."},
			{"Comprehension: Reading to Understand", 7, "Comprehension means understanding what we read. Good readers read the passage first for the general idea, then read again to answer questions. Always look for the main idea of each paragraph, the meaning of new words from context, and the details that support the writer's message. Answer comprehension questions in complete sentences using your own words where possible."},
			{"Composition: Narrative Essay", 8, "A narrative composition tells a story in the order it happened. Plan your story with a beginning (setting and characters), a middle (the events or problem) and an end (how it was resolved). Use past tense, join events with words like first, then, after that and finally, and keep one clear paragraph for each stage of the story."},
			{"Literature: Poetry", 9, "A poem is a piece of writing that expresses ideas and feelings in compact, musical language. Poems are arranged in lines and stanzas, and often use rhyme, rhythm and imagery. A rhyme is the repetition of similar ending sounds, while imagery uses words that appeal to our senses. Read a poem aloud to hear its music before you study its meaning."},
			{"Vocabulary Development", 10, "Building vocabulary means learning new words and how to use them. The best strategies are reading widely, keeping a personal word list with meanings, and using each new word in your own sentence at least three times. Word families help too: from the word 'care' we get careful, careless, carefully and carelessness."},
		},
	},
	{
		Class: "JSS 1", Subject: "Mathematics", Term: 1,
		Topics: []SeedTopic{
			{"Whole Numbers", 1, "Whole numbers are the counting numbers 0, 1, 2, 3 and so on. We write large numbers with place values of units, tens, hundreds, thousands and beyond: 45,612 means 4 ten-thousands, 5 thousands, 6 hundreds, 1 ten and 2 units. Whole numbers can be compared using the symbols < (less than), > (greater than) and = (equal to)."},
			{"Fractions", 2, "A fraction names a part of a whole. The bottom number (denominator) tells how many equal parts the whole is divided into; the top number (numerator) tells how many parts we take. In 3/4, the whole is cut into 4 equal parts and we take 3. Like fractions have the same denominator, unlike fractions do not, and equivalent fractions such as 1/2 and 2/4 name the same amount."},
			{"Decimal Fractions", 3, "A decimal fraction is a fraction whose denominator is 10, 100, 1000 or another power of ten, written with a decimal point. 0.7 means 7/10 and 0.25 means 25/100. Decimals are added and subtracted by lining up the decimal points. Every fraction can be changed to a decimal by dividing, so 1/4 = 0.25."},
			{"Factors and Multiples", 4, "A factor of a number divides it exactly with no remainder; the factors of 12 are 1, 2, 3, 4, 6 and 12. A multiple of a number is the result of multiplying it by a whole number; the multiples of 5 are 5, 10, 15, 20 and so on. A prime number has exactly two factors, itself and 1, like 2, 3, 5, 7 and 11."},
			{"LCM and HCF", 5, "The Lowest Common Multiple (LCM) of two numbers is the smallest number that is a multiple of both; the LCM of 4 and 6 is 12. The Highest Common Factor (HCF) is the largest number that divides both exactly; the HCF of 12 and 18 is 6. List multiples or factors, or use prime factorisation, to find them. LCM is used when adding unlike fractions; HCF is used to reduce fractions."},
			{"Approximation and Estimation", 6, "Approximation means rounding a number to a stated place value. To round, look at the next digit: 5 or more rounds up, less than 5 rounds down. So 4,782 to the nearest hundred is 4,800. Estimation gives a sensible quick answer before calculating exactly, and it helps us check whether an exact answer is reasonable."},
			{"Simple Equations", 7, "An equation is a mathematical sentence that says two expressions are equal, like x + 5 = 12. To solve it, find the value of the unknown letter that makes the sentence true. Use inverse operations on both sides: subtract 5 from both sides to get x = 7. Always check your answer by substituting it back into the original equation."},
			{"Number Patterns and Sequences", 8, "A sequence is a list of numbers that follows a rule. In 2, 5, 8, 11 the rule is add 3, so the next term is 14. Each number is called a term. Some patterns grow by adding (arithmetic), some by multiplying (geometric, like 2, 4, 8, 16), and finding the rule is the key skill."},
			{"Angles", 9, "An angle is the amount of turn between two lines that meet at a point, measured in degrees with a protractor. A full turn is 360 degrees, a straight angle is 180 degrees and a right angle is 90 degrees. Angles smaller than 90 degrees are acute, between 90 and 180 are obtuse, and greater than 180 but less than 360 are reflex."},
			{"Data Collection and Presentation", 10, "Statistics begins with collecting data, which is information in raw form, for example the shoe sizes of pupils in a class. A tally chart organises data using strokes in groups of five, and a frequency table shows how many times each value occurs. We can then present data in a pictogram or a bar chart so it is easy to read and compare."},
		},
	},
	{
		Class: "JSS 1", Subject: "Basic Science", Term: 1,
		Topics: []SeedTopic{
			{"Living and Non-living Things", 1, "Science is the study of nature through observation and experiment. Living things carry out life processes: they feed, respire, grow, move, respond to their surroundings, excrete and reproduce. Non-living things such as stones and water do none of these on their own. Objects that were once alive, like wood and paper, are said to be once-living."},
			{"Classification of Living Things", 2, "Classification means grouping living things by their similarities. The two great kingdoms are the plant kingdom and the animal kingdom. Plants make their own food by photosynthesis and are fixed in the soil, while animals move about and feed on other organisms. Further groups include vertebrates (animals with backbones) and invertebrates (animals without backbones)."},
			{"The Human Body: Movement", 3, "The skeleton is the frame of bones that supports the human body and protects organs such as the brain, heart and lungs. Joints are the places where bones meet, allowing movement: the hinge joint at the elbow and the ball-and-socket joint at the shoulder. Muscles work in pairs, pulling on bones to produce movement."},
			{"The Human Body: Respiration", 4, "Respiration is the process of taking in oxygen and releasing carbon dioxide and energy from food. We breathe in air through the nose, down the windpipe into the lungs, where oxygen passes into the blood. The diaphragm, a muscle under the lungs, drives breathing in and out. Regular exercise keeps the lungs strong."},
			{"Matter: States of Matter", 5, "Matter is anything that has mass and takes up space. It exists in three states: solid, liquid and gas. Solids keep their shape, liquids flow and take the shape of their container, and gases spread out to fill any space. Matter changes state by heating and cooling: ice melts to water, and water boils to steam."},
			{"Measurement", 6, "Scientists measure length, mass and time using standard units. The SI unit of length is the metre, of mass the kilogram and of time the second. A metre rule measures length, a beam balance or scale measures mass, and a stopwatch measures time. Measurement instruments must be read carefully at eye level to avoid error."},
			{"Energy", 7, "Energy is the ability to do work. It exists in many forms: light, heat, sound, electrical, chemical and kinetic (movement) energy. Energy cannot be created or destroyed, only changed from one form to another; a torch changes chemical energy in its battery into light. The sun is the main source of energy for the earth."},
			{"Forces", 8, "A force is a push or a pull. Forces can start motion, stop motion, speed things up, slow them down or change their direction and shape. Friction is the force that opposes motion between two surfaces in contact; it can be useful, as in walking and braking, or a waste of energy, which is why machines are lubricated."},
			{"The Earth in Space", 9, "The earth is one of eight planets that move round the sun, forming the solar system. The earth spins on its axis once every 24 hours, giving day and night, and journeys round the sun once every year. The moon travels round the earth, and its phases change through the month."},
			{"Environmental Pollution", 10, "Pollution is the addition of harmful substances to the environment. Air pollution comes from smoke and exhaust fumes; water pollution from sewage, oil and industrial waste; land pollution from refuse dumping. Pollution damages health, kills plants and animals, and can be reduced by proper waste disposal, recycling and laws against open dumping."},
		},
	},
	{
		Class: "JSS 1", Subject: "Social Studies", Term: 1,
		Topics: []SeedTopic{
			{"Meaning and Scope of Social Studies", 1, "Social Studies is the study of man and his environment, and of how people live and work together. It draws knowledge from geography, history, economics and civic life to help us understand our society and solve its problems. Its scope covers the family, the community, the nation and the wider world."},
			{"The Family: The Basic Unit of Society", 2, "The family is the smallest social unit, made up of father, mother and children, sometimes with other relatives. It provides food, shelter, love, protection and the first teaching of values. The family a child grows up in shapes his or her character more than any other influence."},
			{"Types of Families", 3, "There are two main types of family. The nuclear family contains parents and their children only, while the extended family adds grandparents, uncles, aunts, cousins and in-laws living together or in close contact. In Nigeria the extended family remains strong, providing support in times of need."},
			{"Roles of Family Members", 4, "Every member of the family has duties. Parents provide the needs of the home, discipline the children and model good behaviour. Children help with house chores, respect their elders and face their studies seriously. When each person plays his or her role, the home enjoys peace and progress."},
			{"The Community", 5, "A community is a group of people living in one place and sharing common interests and rules. Communities provide schools, markets, hospitals and roads, and members contribute through levies, work and good conduct. Cooperation among community members brings development such as electrification and clean water."},
			{"Culture", 6, "Culture is the total way of life of a people: their language, food, dress, music, festivals, beliefs and values. Culture is learned from parents and society, and it changes slowly over time. Nigeria is rich in cultures, from the Yoruba, Hausa and Igbo to hundreds of smaller groups, and we must respect cultures other than our own."},
			{"Socialization", 7, "Socialization is the process by which a child learns the language, values and acceptable behaviour of his or her society. The main agents are the family, the school, the peer group, the mass media and religious bodies. Good socialization produces responsible citizens; poor socialization can lead to antisocial behaviour."},
			{"National Consciousness", 8, "National consciousness means feeling proud of and loyal to one's country. National symbols express it: the flag, the anthem, the pledge, the coat of arms and the naira. Showing national consciousness includes respecting the symbols, obeying the law, paying taxes and treating all Nigerians as brothers and sisters regardless of tribe or religion."},
		},
	},
	{
		Class: "JSS 1", Subject: "Civic Education", Term: 1,
		Topics: []SeedTopic{
			{"Meaning of Civic Education", 1, "Civic Education teaches citizens their rights, duties and the workings of government so that they can participate properly in national life. It builds good citizens who know the law, respect others and contribute to development. Without civic education, people cannot defend their rights or perform their duties well."},
			{"Rights of a Nigerian Citizen", 2, "The constitution guarantees fundamental rights: the right to life, dignity of the human person, personal liberty, fair hearing, private and family life, freedom of thought, conscience and religion, freedom of expression, peaceful assembly and movement, and freedom from discrimination. Every citizen should know these rights and claim them peacefully through the courts."},
			{"Duties and Obligations of Citizens", 3, "Rights go hand in hand with duties. Citizens must obey the law, pay taxes, vote in elections, protect public property, defend the country, help law enforcement and respect the rights of others. A nation grows when its citizens perform their obligations honestly and promptly."},
			{"Values", 4, "Values are the important ideas a society holds, such as honesty, hard work, respect, cooperation and self-reliance. Values guide our choices and are learned from parents, teachers and religion. A young person who holds good values earns trust and contributes to a peaceful community."},
			{"National Symbols", 5, "Nigeria's national symbols stand for the country's unity and sovereignty. They include the national flag of green-white-green, the national anthem and pledge, the coat of arms with its Y-junction and horses, and the national currency. These symbols must be handled with respect at all times."},
			{"Democracy", 6, "Democracy is government of the people, by the people and for the people, in which leaders are elected in free and fair elections. Its features include the rule of law, separation of powers, a free press and majority rule with respect for minority rights. Democracy thrives when citizens vote wisely and hold leaders accountable."},
		},
	},
	{
		Class: "JSS 1", Subject: "Business Studies", Term: 1,
		Topics: []SeedTopic{
			{"Meaning and Importance of Business", 1, "A business is any activity carried out to produce or buy and sell goods and services in order to make a profit. Business provides the goods people need, creates jobs, pays taxes that build roads and schools, and keeps money moving in the economy. Examples range from a kiosk selling bread to a large bank."},
			{"Forms of Business Ownership", 2, "Businesses can be owned in different ways. Sole proprietorship is owned by one person who bears all profits and risks. Partnership is owned by two to twenty people who share profit and loss. A company is a separate legal entity owned by shareholders, and a cooperative is owned by members who pool resources for their common benefit."},
			{"The Office", 3, "An office is a room or building where the clerical and administrative work of an organisation is done. It receives and sends information, keeps records and files, receives visitors and safeguards property. A good office is well laid out, ventilated and equipped with furniture, stationery and machines."},
			{"Office Staff and Their Duties", 4, "Office staff include the clerk, typist, receptionist, accountant and the manager. The clerk writes letters, files documents and keeps simple records; the receptionist receives visitors and answers calls; the manager plans, organises and controls the organisation. Each staff member must be honest, punctual and neat."},
			{"Documents Used in the Office", 5, "Common office documents include the letter, memorandum (memo), invoice, receipt, cheque and requisition form. A letter is used for external communication, a memo for internal notes, an invoice shows goods sold and their prices, and a receipt is proof of payment. Correct documents keep business transactions clear and trustworthy."},
			{"Book-keeping: Meaning and Importance", 6, "Book-keeping is the careful recording of all money matters of a business, in books such as the cash book and the ledger. It shows whether the business is making profit or loss, helps to detect fraud, and provides the figures needed for tax and loans. The two sides of an account are debit (left) and credit (right)."},
		},
	},
	{
		Class: "Primary 4", Subject: "English Studies", Term: 1,
		Topics: []SeedTopic{
			{"Phonics: Vowel and Consonant Sounds", 1, "Phonics is the study of the sounds letters make. The five vowels are a, e, i, o, u, and every other letter is a consonant. Each vowel has a short sound as in 'cat', 'bed', 'sit', 'pot' and 'cup', and a long sound as in 'cake', 'see' and 'go'. Good phonics helps us read new words and spell correctly."},
			{"Nouns and Their Plurals", 2, "Nouns are naming words for people, animals, places and things. Most nouns add -s to become plural (bag, bags), some add -es (box, boxes), some change form (man, men; child, children) and some stay the same (sheep, sheep). Knowing plurals helps us talk about one thing or many things correctly."},
			{"Comprehension: Reading Short Passages", 3, "To understand a passage, read it slowly twice: first for the general story, then for the details. Ask yourself who did what, where and when. New words can be guessed from the words around them. Then answer questions in complete sentences."},
			{"Composition: My Family", 4, "A good composition about your family tells the reader the names of your family members, what each person does, and what you enjoy doing together. Begin with an introduction, write one idea per paragraph, and end with how you feel about your family. Use capital letters and full stops correctly."},
			{"Verbs and Simple Tenses", 5, "Verbs are doing words: run, eat, write, sing. The tense shows the time of the action. Present tense tells what happens now: 'I eat rice.' Past tense tells what already happened: 'I ate rice yesterday.' Future tense tells what will happen: 'I will eat rice tomorrow.'"},
			{"Adjectives: Making Comparisons", 6, "Adjectives describe nouns: a big house, a red pen. To compare two things, add -er: 'Tolu is taller than Ada.' To compare many things, add -est: 'Tolu is the tallest in the class.' Long adjectives use more and most instead: more beautiful, most beautiful."},
		},
	},
	{
		Class: "Primary 4", Subject: "Mathematics", Term: 1,
		Topics: []SeedTopic{
			{"Whole Numbers to 100,000", 1, "Large numbers are read and written using place value: units, tens, hundreds, thousands and ten-thousands. The number 45,678 has 4 ten-thousands, 5 thousands, 6 hundreds, 7 tens and 8 units. Practise writing numbers in words and figures, and ordering them from smallest to largest."},
			{"Addition of Whole Numbers", 2, "To add large numbers, write them under one another with the place values lined up, then add from the units column. When a column gives a two-digit answer, carry the tens to the next column. Always check by adding again or by estimating first."},
			{"Subtraction of Whole Numbers", 3, "Subtraction means taking away or finding the difference. Arrange the numbers with place values lined up and subtract from the units. If a digit is too small, borrow one ten from the next column: 5,000 - 2,346 needs careful borrowing at every step. Check by adding your answer to the number subtracted."},
			{"Multiplication", 4, "Multiplication is repeated addition: 4 x 3 means 3 + 3 + 3 + 3. Learn the times tables up to 12 by heart, because they make long multiplication fast. To multiply by a two-digit number, multiply by the units and then by the tens, and add the two partial answers."},
			{"Division", 5, "Division is sharing equally into groups: 20 divided by 4 means sharing 20 items into 4 equal groups of 5. Division is the opposite of multiplication, so knowing your tables helps. In long division, divide, multiply, subtract and bring down, and check your answer by multiplying the quotient by the divisor."},
			{"Equivalent Fractions", 6, "Equivalent fractions are different fractions that name the same amount: 1/2, 2/4, 3/6 are all one half. Multiply or divide both the numerator and the denominator by the same number to make an equivalent fraction. The simplest form of a fraction has no number that divides both parts except 1."},
		},
	},
	{
		Class: "Primary 4", Subject: "Basic Science & Technology", Term: 1,
		Topics: []SeedTopic{
			{"Living Things in the Environment", 1, "The environment is everything around us: air, water, soil, plants and animals. Living things in the environment depend on one another; plants give food and oxygen, animals spread seeds and enrich the soil. We must protect the environment by planting trees and keeping it clean."},
			{"The Soil", 2, "Soil is the loose top layer of the earth in which plants grow. There are three main types: sandy soil with large rough grains, clay soil with tiny sticky grains, and loamy soil, a rich mixture of the two with humus. Loamy soil is the best for farming because it holds water and plant food well."},
			{"Water", 3, "Water is essential for life; people, animals and plants all need it. We use water for drinking, cooking, bathing, washing and farming. Clean water is free of dirt and germs, so water can be made safe by boiling, filtering or adding approved chemicals. Always cover drinking water and store it in clean containers."},
			{"Air Around Us", 4, "Air is a mixture of gases that surrounds the earth: mainly nitrogen, oxygen and carbon dioxide. Living things breathe in oxygen from the air, and plants use carbon dioxide to make food. Air occupies space and can move things, which is how windmills and sailing boats work. Moving air is called wind."},
			{"Simple Machines", 5, "A machine is any device that makes work easier, faster or more convenient. Simple machines include the lever (see-saw, bottle opener), the inclined plane (ramp), the pulley (well rope), the wheel and axle (car wheel), the screw and the wedge (knife, axe). They reduce the effort we need to move a load."},
			{"Energy: Sources and Uses", 6, "Energy is the ability to do work. The sun is the greatest source of energy; other sources are food, fuel, wind, moving water, batteries and electricity. We use energy to cook, light our homes, move vehicles and power machines. We must use energy wisely to avoid waste and danger."},
		},
	},
}
