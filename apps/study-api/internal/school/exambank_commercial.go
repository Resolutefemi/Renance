// Commerce and Financial Accounting starter questions (senior band,
// commercial track). Original content written for Renance.

package school

var examBankCommerce = []SeedExamQuestion{
        // First Term
        {SubjectCode: "COM", Band: "senior", Term: 1,
                Question:    "Commerce is divided into trade and:",
                Options:     [4]string{"Banking", "Aids to trade", "Insurance", "Advertising"},
                AnswerIndex: 1,
                Explanation: "Aids to trade include banking, insurance, transport and warehousing."},
        {SubjectCode: "COM", Band: "senior", Term: 1,
                Question:    "Buying and selling of goods and services within a country is:",
                Options:     [4]string{"Foreign trade", "Home trade", "Import trade", "Entrepot trade"},
                AnswerIndex: 1,
                Explanation: "Home (internal) trade happens within national borders."},
        {SubjectCode: "COM", Band: "senior", Term: 1,
                Question:    "The middleman that buys in bulk from producers and sells to retailers is the:",
                Options:     [4]string{"Consumer", "Wholesaler", "Broker", "Hawker"},
                AnswerIndex: 1,
                Explanation: "Wholesalers bridge production and retail distribution."},
}

var examBankAccounting = []SeedExamQuestion{
        // First Term
        {SubjectCode: "FAC", Band: "senior", Term: 1,
                Question:    "The accounting equation states that assets equal:",
                Options:     [4]string{"Income minus expenses", "Liabilities plus capital", "Capital minus liabilities", "Sales plus purchases"},
                AnswerIndex: 1,
                Explanation: "Assets = liabilities + owner's equity, the balance sheet backbone."},
        {SubjectCode: "FAC", Band: "senior", Term: 1,
                Question:    "Every accounting transaction affects at least:",
                Options:     [4]string{"One account", "Two accounts", "Three accounts", "Four accounts"},
                AnswerIndex: 1,
                Explanation: "Double entry records a debit and a matching credit."},
        {SubjectCode: "FAC", Band: "senior", Term: 1,
                Question:    "Which book of original entry records credit purchases?",
                Options:     [4]string{"Sales day book", "Purchases day book", "Cash book", "Journal proper"},
                AnswerIndex: 1,
                Explanation: "The purchases day book collects invoices for goods bought on credit."},
}
