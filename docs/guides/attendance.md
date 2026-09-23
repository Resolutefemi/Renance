# Attendance Desk Guide

The register lives at `/school/attendance` with two tabs: the daily
register and a summary that rolls any date range into per-student
rates.

## Taking the register

1. Pick the class and the day. The roster loads with the stored
   statuses pre-marked.
2. Mark each pupil present, absent, late or excused. Mark all present
   then flip the exceptions is the fast path on a full class.
3. Save register. Re-marking the same day overwrites safely, so the
   roster and the classroom kiosk never fight.

## The kiosk

Open kiosk projects a tap-in screen for a classroom device: pupils tap
their own name as they walk in. It writes to the same register with
the same upsert safety.

## The summary

Pick a from/to range and the summary tab shows each student's counts
and attendance rate. Export CSV downloads exactly what the screen
shows, ready for the office file.
