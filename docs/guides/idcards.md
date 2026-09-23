# ID Cards Desk Guide

Student ID cards live at `/school/idcards`. One card belongs to one
student for one session, carries a school-unique serial of the shape
REN-2026-000001, and prints black on white with the school logo.

## Issuing cards

- Issue missing cards cards every active student in the current pick
  who does not hold one yet for the session. Run it once for the
  whole school or once per class; it only fills gaps.
- Re-issuing a student who already has a card flips their card back
  to issued and never mints a second serial.

## The card sheet

The grid under Card sheet renders each card at true face size. Tap
Print sheet to open the browser print dialog; the portal chrome, the
notice bar and the status buttons drop out of the print automatically.
Three cards fit across on A4.

## Lost cards

Revoke a card when it is lost or when a student leaves. A revoked
serial stays in the history with its status printed on the face, and
Re-activate brings it back if the card turns up.

## Details that print well

The card face shows the school logo and name, the student photo,
name, admission number, class, sex, date of birth and guardian phone.
Fill these on the Students desk first; cards read whatever the
enrollment record holds, and a missing photo falls back to a clean
placeholder.
