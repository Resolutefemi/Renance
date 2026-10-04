package httpapi

import (
        "testing"
        "time"
)

// dailyMailBudget (quota armor, founder directive 2026-10-04): the global
// per-day cap on reset mails. A bot hammering /auth/forgot-password must
// not drain the Brevo free tier - once the day's budget is spent, take()
// reports false and the handler suppresses the mail behind the uniform
// sent:true response.
func TestDailyMailBudget(t *testing.T) {
        base := time.Date(2026, 10, 4, 9, 0, 0, 0, time.UTC)
        clock := base
        b := newDailyMailBudget(3)
        b.now = func() time.Time { return clock }

        for i := 1; i <= 3; i++ {
                if !b.take() {
                        t.Fatalf("take %d inside the cap should clear", i)
                }
        }
        if b.take() {
                t.Fatal("take past the cap must be refused")
        }
        if b.take() {
                t.Fatal("take past the cap must stay refused")
        }
        if got, want := b.String(), "budget(3/3)"; got != want {
                t.Fatalf("String() = %q, want %q", got, want)
        }

        // A new UTC day resets the budget.
        clock = base.Add(25 * time.Hour)
        if !b.take() {
                t.Fatal("first take of the next day should clear")
        }
        if got, want := b.String(), "budget(1/3)"; got != want {
                t.Fatalf("String() = %q, want %q", got, want)
        }
}

func TestDailyMailBudgetDisabled(t *testing.T) {
        b := newDailyMailBudget(0) // RESET_MAIL_DAILY_CAP=0 disables it
        for i := 0; i < 100; i++ {
                if !b.take() {
                        t.Fatal("a disabled budget must always clear")
                }
        }
        var nilBudget *dailyMailBudget
        if !nilBudget.take() {
                t.Fatal("a nil budget must always clear (tests, old builds)")
        }
        if got, want := nilBudget.String(), "budget(disabled)"; got != want {
                t.Fatalf("nil String() = %q, want %q", got, want)
        }
}

// Midnight rollover: a mail sent at 23:59 counts against the day it was
// spent on, and 00:01 of the next day opens a fresh budget.
func TestDailyMailBudgetMidnightRollover(t *testing.T) {
        clock := time.Date(2026, 10, 4, 23, 59, 0, 0, time.UTC)
        b := newDailyMailBudget(1)
        b.now = func() time.Time { return clock }
        if !b.take() {
                t.Fatal("first take of the day should clear")
        }
        if b.take() {
                t.Fatal("budget of 1 is spent for the day")
        }
        clock = clock.Add(2 * time.Minute) // 00:01 the next UTC day
        if !b.take() {
                t.Fatal("the new UTC day must open a fresh budget")
        }
}
