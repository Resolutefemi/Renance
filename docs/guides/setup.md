# School Setup Desk Guide

The setup desk at `/school/setup` is the identity room: who the school
is, what it offers, and the groundwork every other desk builds on.

## Identity

Set the school name, address and logo. The logo is a small image that
stamps every report card, the portal chrome and the ID card sheet.
Data URLs from the picker work; keep it square for the cleanest crop.

## Curriculum

One tap installs the Nigerian ladder: Primary 1 to 6, JSS 1 to 3 and
SSS 1 to 3, with the NERDC subject catalog. Senior subjects carry
their track (art, science, commercial) and the core flag. The install
is idempotent; run it again and nothing doubles.

## Class subjects

For each class, pick what it actually offers from the catalog. This
wiring feeds the timetable picker, the syllabus desk, the students'
subject tracks and the results grid. JSS classes usually take the
broad junior set; SSS classes compose from core plus their tracks.

## The order that saves rework

Identity, curriculum, class subjects, then students, then teachers
and assignments. Results come last: finalize only after the logo and
subjects are settled, because the report card stamps what setup holds.
