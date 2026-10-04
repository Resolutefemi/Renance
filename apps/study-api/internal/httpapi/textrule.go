// The Renance text rule: no double dashes anywhere in stored content.
// Titles, notes, reports, exam text all pass through this guard before
// they reach the database, so nothing typed with a "--" sneaks into a
// printed sheet.

package httpapi

import "strings"

// stripDoubleDashes collapses runs of two or more dashes to a single
// spaced dash and tidies the spacing around it.
func stripDoubleDashes(s string) string {
	for strings.Contains(s, "--") {
		s = strings.ReplaceAll(s, "--", "-")
	}
	return s
}
