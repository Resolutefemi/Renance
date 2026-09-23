// Fees HTTP surface: pricing terms, recording receipts and reading
// balances. Management owns the desk end to end; teachers get read
// access so a form teacher can see who still owes what.
package httpapi

import (
	"net/http"
	"strings"

	"renance.dev/study-api/internal/store"
)

// nairaToKobo converts "15000" or "15000.50" to kobo without float
// rounding surprises (the ledger is integer all the way down).
// Signatures are rejected: a fee is never negative.
func nairaToKobo(s string) (int64, bool) {
	s = strings.TrimSpace(s)
	if s == "" || strings.HasPrefix(s, "-") {
		return 0, false
	}
	whole, frac := s, ""
	if i := strings.IndexByte(s, '.'); i >= 0 {
		whole, frac = s[:i], s[i+1:]
	}
	if whole == "" {
		whole = "0"
	}
	var n int64
	for _, c := range whole {
		if c < '0' || c > '9' {
			return 0, false
		}
		n = n*10 + int64(c-'0')
		if n > 1<<52 {
			return 0, false
		}
	}
	n *= 100
	// up to two fraction digits count as kobo
	if len(frac) > 2 {
		frac = frac[:2]
	}
	f := int64(0)
	for i, c := range frac {
		if c < '0' || c > '9' {
			return 0, false
		}
		f += int64(c-'0') * []int64{10, 1}[i]
	}
	return n + f, true
}

// GET /school/fees?schoolId&term&session - the priced charge list.
func (s *Server) handleSchoolFees(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	term, _ := queryInt(r, "term")
	session := strings.TrimSpace(r.URL.Query().Get("session"))
	if term == 0 {
		term = 1
	}
	fees, err := s.store.ListFees(r.Context(), m.SchoolID, term, session)
	if err != nil {
		s.log.Error("list fees", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load the fees")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"fees": fees})
}

// PUT /school/fee?schoolId - management prices (or re-prices) one
// charge. classId empty means the charge lands on every class.
func (s *Server) handleSchoolSaveFee(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	var req struct {
		ClassID     string `json:"classId"`
		Title       string `json:"title"`
		Description string `json:"description"`
		AmountNaira string `json:"amountNaira"`
		Term        int    `json:"term"`
		Session     string `json:"session"`
		Seq         int    `json:"seq"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	req.Title = strings.TrimSpace(req.Title)
	req.Session = strings.TrimSpace(req.Session)
	if req.Title == "" || len(req.Title) > 120 {
		fail(w, http.StatusBadRequest, "invalid_title", "a fee title is required")
		return
	}
	kobo, ok := nairaToKobo(req.AmountNaira)
	if !ok {
		fail(w, http.StatusBadRequest, "invalid_amount", "amount must be a naira figure like 15000 or 2500.50")
		return
	}
	if req.Term < 1 || req.Term > 3 {
		fail(w, http.StatusBadRequest, "invalid_term", "term must be 1, 2 or 3")
		return
	}
	req.Session = strings.TrimSpace(req.Session)
	if req.Session == "" {
		fail(w, http.StatusBadRequest, "invalid_session", "session is required (for example 2025/2026)")
		return
	}
	fee := &store.SchoolFee{
		SchoolID:    m.SchoolID,
		ClassID:     req.ClassID,
		Title:       req.Title,
		Description: strings.TrimSpace(req.Description),
		AmountKobo:  kobo,
		Term:        req.Term,
		Session:     req.Session,
		Seq:         req.Seq,
	}
	saved, err := s.store.SaveFee(r.Context(), fee)
	if err != nil {
		s.log.Error("save fee", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not save the fee")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"fee": saved})
}

// DELETE /school/fee?schoolId&id - management removes a charge that
// has no receipts yet; paid fees stay for the ledger's sake.
func (s *Server) handleSchoolDeleteFee(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	id := strings.TrimSpace(r.URL.Query().Get("id"))
	if id == "" {
		fail(w, http.StatusBadRequest, "invalid_id", "which fee?")
		return
	}
	deleted, err := s.store.DeleteFee(r.Context(), m.SchoolID, id)
	if err != nil {
		s.log.Error("delete fee", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not delete the fee")
		return
	}
	if !deleted {
		fail(w, http.StatusConflict, "has_payments",
			"this fee already has payments recorded, so it stays on the ledger")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// POST /school/fee-payment?schoolId - management records one receipt.
func (s *Server) handleSchoolRecordPayment(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	var req struct {
		FeeID       string `json:"feeId"`
		StudentID   string `json:"studentId"`
		AmountNaira string `json:"amountNaira"`
		Method      string `json:"method"`
		Reference   string `json:"reference"`
		PaidOn      string `json:"paidOn"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	req.FeeID = strings.TrimSpace(req.FeeID)
	req.StudentID = strings.TrimSpace(req.StudentID)
	if req.FeeID == "" || req.StudentID == "" {
		fail(w, http.StatusBadRequest, "invalid_body", "fee and student are required")
		return
	}
	kobo, ok := nairaToKobo(req.AmountNaira)
	if !ok || kobo <= 0 {
		fail(w, http.StatusBadRequest, "invalid_amount", "amount must be a positive naira figure")
		return
	}
	method := strings.ToLower(strings.TrimSpace(req.Method))
	switch method {
	case "", "cash":
		method = "cash"
	case "transfer", "pos", "other":
		// allowed as-is
	default:
		fail(w, http.StatusBadRequest, "invalid_method", "method must be cash, transfer, pos or other")
		return
	}
	p := &store.SchoolFeePayment{
		SchoolID:   m.SchoolID,
		FeeID:      req.FeeID,
		StudentID:  req.StudentID,
		AmountKobo: kobo,
		Method:     method,
		Reference:  strings.TrimSpace(req.Reference),
		PaidOn:     strings.TrimSpace(req.PaidOn),
	}
	saved, err := s.store.RecordPayment(r.Context(), p)
	if err != nil {
		s.log.Error("record payment", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not record the payment")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"payment": saved})
}

// GET /school/fee-payments?schoolId&studentId&term&session - receipts
// for one student, newest first.
func (s *Server) handleSchoolPayments(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	studentID := strings.TrimSpace(r.URL.Query().Get("studentId"))
	if studentID == "" {
		fail(w, http.StatusBadRequest, "invalid_student", "studentId is required")
		return
	}
	term, _ := queryInt(r, "term")
	session := strings.TrimSpace(r.URL.Query().Get("session"))
	if term == 0 {
		term = 1
	}
	payments, err := s.store.ListPayments(r.Context(), m.SchoolID, studentID, term, session)
	if err != nil {
		s.log.Error("list payments", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load the receipts")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"payments": payments})
}

// GET /school/fee-balances?schoolId&classId&term&session - the money
// position of every active student (scoped to a class when classId is
// given). Management only: it is the debtors' list.
func (s *Server) handleSchoolFeeBalances(w http.ResponseWriter, r *http.Request) {
	m, _, ok := s.memberAndSchool(w, r, r.URL.Query().Get("schoolId"))
	if !ok {
		return
	}
	if !s.requireManagement(w, m) {
		return
	}
	classID := strings.TrimSpace(r.URL.Query().Get("classId"))
	term, _ := queryInt(r, "term")
	session := strings.TrimSpace(r.URL.Query().Get("session"))
	if term == 0 {
		term = 1
	}
	balances, err := s.store.FeeBalances(r.Context(), m.SchoolID, classID, term, session)
	if err != nil {
		s.log.Error("fee balances", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load the balances")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"balances": balances})
}
