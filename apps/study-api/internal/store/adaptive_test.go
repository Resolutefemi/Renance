package store

import (
	"reflect"
	"testing"
	"time"
)

var today = time.Date(2026, 9, 4, 10, 0, 0, 0, time.UTC)

func state(ease float64, lapses, correct, total int, due time.Time) TopicState {
	return TopicState{SM2: SM2Item{Ease: ease, IntervalDays: 6, Repetitions: 2, Lapses: lapses},
		LastCorrect: correct, LastTotal: total, DueOn: due}
}

func items(ids ...string) []OrderItem {
	out := make([]OrderItem, 0, len(ids))
	for _, id := range ids {
		out = append(out, OrderItem{QuestionID: id, Topic: "T-" + id, Difficulty: "easy"})
	}
	return out
}

func TestWeaknessOrdersStruggleAboveEverything(t *testing.T) {
	struggling := state(1.3, 3, 1, 5, today)                    // floor ease, 3 lapses, 20% acc, due
	strong := state(2.5, 0, 10, 10, today.Add(30*24*time.Hour)) // mastered
	ws, wg := Weakness(struggling, today), Weakness(strong, today)
	if ws <= wg {
		t.Fatalf("struggling(%f) must outweigh strong(%f)", ws, wg)
	}
	if ws < 4.0 {
		t.Fatalf("struggling weakness %f below expected band", ws)
	}
	if wg != 0 {
		t.Fatalf("mastered weakness %f, want 0", wg)
	}
}

func TestWeaknessDueBonus(t *testing.T) {
	due := state(2.5, 0, 5, 5, today)
	future := state(2.5, 0, 5, 5, today.Add(24*time.Hour))
	if Weakness(due, today) <= Weakness(future, today) {
		t.Fatal("due topic must outweigh not-yet-due")
	}
	overdue := state(2.5, 0, 5, 5, today.Add(-72*time.Hour))
	if Weakness(overdue, today) != Weakness(due, today) {
		t.Fatal("overdue and due-today carry the same urgency bonus")
	}
}

func TestAdaptiveOrderUnseenBetweenStrugglingAndMastered(t *testing.T) {
	st := map[string]TopicState{
		"struggling": state(1.3, 2, 1, 5, today),
		"mastered":   state(2.5, 0, 10, 10, today.Add(30*24*time.Hour)),
	}
	got := AdaptiveOrder([]OrderItem{
		{QuestionID: "m1", Topic: "mastered", Difficulty: "easy"},
		{QuestionID: "n1", Topic: "unseen", Difficulty: "easy"},
		{QuestionID: "s1", Topic: "struggling", Difficulty: "easy"},
	}, st, today)
	want := []string{"s1", "n1", "m1"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("order = %v, want %v", got, want)
	}
}

func TestAdaptiveOrderEasyBeforeMediumBeforeHard(t *testing.T) {
	got := AdaptiveOrder([]OrderItem{
		{QuestionID: "h", Topic: "Algebra", Difficulty: "hard"},
		{QuestionID: "m", Topic: "Algebra", Difficulty: "medium"},
		{QuestionID: "e", Topic: "Algebra", Difficulty: "easy"},
	}, map[string]TopicState{"Algebra": state(2.0, 0, 3, 5, today)}, today)
	if !reflect.DeepEqual(got, []string{"e", "m", "h"}) {
		t.Fatalf("difficulty ladder broken: %v", got)
	}
}

func TestAdaptiveOrderDeterministicTie(t *testing.T) {
	in := []OrderItem{
		{QuestionID: "z", Topic: "Zeta", Difficulty: "easy"},
		{QuestionID: "a", Topic: "Alpha", Difficulty: "easy"},
		{QuestionID: "z2", Topic: "Zeta", Difficulty: "medium"},
	}
	first := AdaptiveOrder(in, map[string]TopicState{}, today)
	second := AdaptiveOrder(in, map[string]TopicState{}, today)
	if !reflect.DeepEqual(first, second) {
		t.Fatalf("not deterministic: %v vs %v", first, second)
	}
	// Equal (unseen) weakness: alphabetical topics, easy before medium.
	if !reflect.DeepEqual(first, []string{"a", "z", "z2"}) {
		t.Fatalf("tie order = %v", first)
	}
}

func TestAdaptiveOrderGeneralBucketAndStableIndex(t *testing.T) {
	// Empty topics all land in "General"; original PACK order breaks ties
	// (q3 is first in the pack here, so it comes first).
	got := AdaptiveOrder([]OrderItem{
		{QuestionID: "q3"},
		{QuestionID: "q1"},
		{QuestionID: "q2"},
	}, map[string]TopicState{}, today)
	if !reflect.DeepEqual(got, []string{"q3", "q1", "q2"}) {
		t.Fatalf("general bucket order = %v", got)
	}
}

func TestAdaptiveOrderKeepsEveryQuestion(t *testing.T) {
	in := items("a", "b", "c", "d", "e")
	got := AdaptiveOrder(in, map[string]TopicState{
		"T-a": state(1.3, 0, 0, 5, today),
		"T-c": state(2.5, 0, 5, 5, today.Add(48*time.Hour)),
	}, today)
	if len(got) != len(in) {
		t.Fatalf("lost questions: %v", got)
	}
	seen := map[string]bool{}
	for _, id := range got {
		if seen[id] {
			t.Fatalf("duplicate %s", id)
		}
		seen[id] = true
	}
	if got[0] != "a" || got[len(got)-1] != "c" {
		t.Fatalf("weak-first violated: %v", got)
	}
}

func TestAdaptiveOrderNilStateIsPureUnseen(t *testing.T) {
	in := items("x", "y")
	got := AdaptiveOrder(in, nil, today)
	if !reflect.DeepEqual(got, []string{"x", "y"}) {
		t.Fatalf("nil state order = %v", got)
	}
}
