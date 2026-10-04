// Renance AI Studio prompt builders. Every generator shares the same
// doctrine: exam-accurate Nigerian phrasing, plain-English teaching,
// structured JSON only, and - when the bridge found real past
// questions - imitate the corpus's exact style and difficulty.
package httpapi

import (
	"fmt"
	"strings"
)

// quizSystemPrompt grounds the quiz writer on real past questions.
func quizSystemPrompt(topics []string, difficulty string, count int, body, bridging string) string {
	var b strings.Builder
	b.WriteString("You are Renance's exam-paper writer for Nigerian students (JAMB, WAEC, NECO, Post-UTME and university courses). ")
	if body != "" {
		b.WriteString("Target exam body: " + body + ". ")
	}
	b.WriteString("Write exam-standard multiple-choice questions in the style of real Nigerian past questions.\n\n")
	b.WriteString("OUTPUT FORMAT - return ONLY a JSON array, no prose, no code fences:\n")
	b.WriteString(`[{"stem":"...","options":{"A":"...","B":"...","C":"...","D":"..."},"answer":"B","explanation":"one or two sentences why"}, ...]` + "\n\n")
	b.WriteString("RULES:\n")
	b.WriteString("- Exactly 4 options lettered A-D; exactly one is correct.\n")
	b.WriteString("- Distractors must be plausible (common misconceptions, near-misses).\n")
	b.WriteString("- Stems are self-contained: no references to figures, passages or prior questions.\n")
	b.WriteString("- Explanation teaches the shortest correct path, under 40 words, plain English.\n")
	fmt.Fprintf(&b, "- Produce exactly %d question(s), %s difficulty, on: %s.\n",
		count, strings.ToLower(difficulty), strings.Join(topics, "; "))
	if bridging != "" {
		b.WriteString("\nSTYLE GROUNDING - match the phrasing, register and difficulty distribution of these REAL past questions from the corpus:\n")
		b.WriteString(bridging)
	}
	return b.String()
}

// noteSystemPrompt builds the study-note prompt. The template IS the
// house arrangement; the model fills it, never re-invents it.
func noteSystemPrompt(topic, subject, classLevel, template, bridging string) string {
	var b strings.Builder
	b.WriteString("You are Renance's study-note writer for Nigerian students. ")
	b.WriteString("Write a complete, exam-ready study note that a Nigerian teacher would hand out.\n\n")
	if subject != "" {
		b.WriteString("SUBJECT: " + subject + "\n")
	}
	if classLevel != "" {
		b.WriteString("CLASS LEVEL: " + classLevel + "\n")
	}
	b.WriteString("TOPIC: " + topic + "\n")
	switch template {
	case "simple":
		b.WriteString("TEMPLATE: simple (3 sections max, short paragraphs, for a first pass at the topic).\n")
	case "revision":
		b.WriteString("TEMPLATE: revision (exam-focus: condensed sections, dense key points, common traps in examTips, 2 practice questions).\n")
	default:
		b.WriteString("TEMPLATE: detailed (4-5 sections, full explanations with worked examples, 2 practice questions).\n")
	}
	b.WriteString("\nOUTPUT - return ONLY this JSON object, no prose, no fences:\n")
	b.WriteString(`{
  "title": "...",
  "summary": "two-sentence overview of the topic",
  "sections": [{"heading": "...", "body": "one to three short paragraphs, plain English, local examples (naira, market, school farm) where they help"}],
  "keyPoints": ["..."],
  "examTips": ["how examiners actually test this, traps to avoid"],
  "practiceQuestions": [{"stem":"...","options":{"A":"...","B":"...","C":"...","D":"..."},"answer":"B","explanation":"..."}]
}` + "\n")
	b.WriteString("RULES: under 550 words of body total; no markdown symbols inside strings; practiceQuestions are 1-2 items; never reference figures.\n")
	if bridging != "" {
		b.WriteString("\nSTYLE GROUNDING - real past questions on this topic; mirror their phrasing and cover what they actually test:\n")
		b.WriteString(bridging)
	}
	return b.String()
}

// lessonSystemPrompt builds the Nigerian school lesson-note prompt in
// the standard format schools submit for inspection.
func lessonSystemPrompt(subject, classLevel, topic, term string, duration int) string {
	var b strings.Builder
	b.WriteString("You are Renance's lesson-note writer for Nigerian schools (primary and secondary, NERDC curriculum). ")
	fmt.Fprintf(&b, "Write a complete lesson note for: SUBJECT %s, CLASS %s, TOPIC %s, %s, %d minutes double period.\n\n",
		subject, classLevel, topic, term, duration)
	b.WriteString("OUTPUT - return ONLY this JSON object, no prose, no fences:\n")
	b.WriteString(`{
  "ageGroup": "e.g. 10-12 years",
  "objectives": ["by the end of the lesson students should be able to ..."],
  "materials": ["chalkboard/whiteboard", "..."],
  "entryBehaviour": "what students already bring to this lesson",
  "previousKnowledge": "the prior lesson this builds on",
  "content": [{"heading": "STEP 1: INTRODUCTION", "body": "..."}, {"heading": "STEP 2: ...", "body": "..."}, {"heading": "STEP 3: ...", "body": "..."}],
  "evaluation": ["questions the teacher asks to check understanding"],
  "summary": "the teacher wraps up by restating ...",
  "assignment": "take-home work"
}` + "\n")
	b.WriteString("RULES: 4-5 content steps (introduction, presentation, demonstration or guided practice, evaluation, summary and closure); plain English; local, low-cost materials; under 500 words total; no markdown symbols inside strings.\n")
	return b.String()
}

// notebookSystemPrompt builds the NotebookLM-style notebook prompt with
// the fixed pre-built arrangement: overview, one deep note per topic,
// glossary, exam focus, day-by-day study plan.
func notebookSystemPrompt(subject, classLevel string, topics []string, bridging string) string {
	var b strings.Builder
	b.WriteString("You are Renance's notebook builder for Nigerian students, building a NotebookLM-style study notebook. ")
	b.WriteString("The notebook's arrangement is FIXED: overview, one deep-dive note per topic, a glossary, exam focus points and a study plan.\n\n")
	b.WriteString("SUBJECT: " + subject + "\n")
	if classLevel != "" {
		b.WriteString("CLASS LEVEL: " + classLevel + "\n")
	}
	b.WriteString("TOPICS (one topicNote each, same order): " + strings.Join(topics, "; ") + "\n\n")
	b.WriteString("OUTPUT - return ONLY this JSON object, no prose, no fences:\n")
	b.WriteString(`{
  "title": "...",
  "overview": "what this notebook covers and why it matters for the exam, 3-4 sentences",
  "topicNotes": [{
    "topic": "...",
    "summary": "two sentences",
    "deepDive": "the full explanation: definition, mechanism, worked example, common misconception - short paragraphs separated by \n",
    "keyTerms": [{"term": "...", "meaning": "..."}],
    "examples": ["worked example or real-life application"]
  }],
  "glossary": [{"term": "...", "meaning": "one sentence"}],
  "examFocus": ["what examiners repeatedly test across these topics"],
  "studyPlan": ["Day 1: ...", "Day 2: ...", "Day 3: ..."]
}` + "\n")
	b.WriteString("RULES: every topic in the list gets exactly one topicNote; deepDive under 150 words each; studyPlan is 3-5 days; no markdown symbols inside strings.\n")
	if bridging != "" {
		b.WriteString("\nSTYLE GROUNDING - real past questions touching these topics; cover what they actually test:\n")
		b.WriteString(bridging)
	}
	return b.String()
}
