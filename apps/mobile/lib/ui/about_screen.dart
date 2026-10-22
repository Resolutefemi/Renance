/// About Renance (founder directive 2026-10-22): the profile-page card
/// that tells the Renance story - what the platform is, who builds it
/// (Resolute Femi) and the facts that renance.app/about carries, so the
/// answers live inside the app too, not only on the web.
library;

import 'package:flutter/material.dart';

import 'msymbols.dart';
import 'renance_logo.dart';
import 'tactile.dart';
import 'theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: <Widget>[
                    TactileBackKey(
                      onTap: () => Navigator.of(context).pop(),
                      size: 42,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                'About Renance',
                style: RenanceText.displayMd.copyWith(
                  fontSize: 26,
                  color: context.ink,
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Brand block: the R monogram, the slogan, one-line pitch.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.cardLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const RenanceMark(size: 44),
                    const SizedBox(height: 12),
                    Text(
                      'Your Guide to Academic Success',
                      style: RenanceText.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Renance is an educational app in Nigeria built for '
                      'JAMB, WAEC, NECO and tertiary institution success. '
                      'Students sit CBT mocks the server marks with sealed '
                      'answer keys, drill 90,000+ past questions from 1978 '
                      'to 2026, work through 200,000+ Post-UTME and course '
                      'questions topic by topic - and whatever they miss '
                      'enters a spaced-repetition review queue. The only '
                      'official website is renance.app.',
                      style: RenanceText.bodySecondary.copyWith(
                        color: context.textSecondary,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Founder block - the human behind the platform.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                'Who built Renance',
                style: RenanceText.sectionTitle,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.cardLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: RenanceColors.macaw,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            'RF',
                            style: RenanceText.labelMono.copyWith(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Resolute Femi',
                                style: RenanceText.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Founder & Engineer - Ariyo Oluwafemi Stephen',
                                style: RenanceText.caption.copyWith(
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Renance is founded and built by Resolute Femi, the '
                      'software engineering alias of Ariyo Oluwafemi '
                      'Stephen, a Nigerian software engineering '
                      'undergraduate - he is in 200 level of Software '
                      'Engineering at the Federal University of '
                      'Technology, Akure (FUTA). He builds in TypeScript, '
                      'Go, Rust and Python and ships developer and '
                      'education tools for Nigerians - Renance, the '
                      'Renance DevTools CLI and FUTA CBT practice '
                      'platforms among them. The '
                      'platform is intentionally Nigerian: the curriculum '
                      'is NERDC, the mock exams mirror the real JAMB CBT '
                      'interface, and the question archive grows from the '
                      'actual papers Nigerian students sit, with some '
                      'going back to 1978.',
                      style: RenanceText.bodySecondary.copyWith(
                        color: context.textSecondary,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Facts block - the "at a glance" rows.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                'Renance at a glance',
                style: RenanceText.sectionTitle,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: context.cardLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.outlineVariant),
                ),
                child: Column(
                  children: <Widget>[
                    _FactRow(
                      icon: 'school',
                      label: 'Exams covered',
                      value: 'JAMB UTME, WAEC WASSCE, NECO SSCE, Post-UTME '
                          'and tertiary institution exams',
                    ),
                    _divider(context),
                    _FactRow(
                      icon: 'quiz',
                      label: 'Question archive',
                      value: '90,000+ JAMB, NECO and WAEC past questions '
                          '(1978-2026) plus 200,000+ Post-UTME and course '
                          'questions - worked explanations on every one',
                    ),
                    _divider(context),
                    _FactRow(
                      icon: 'menu_book',
                      label: 'Curriculum',
                      value: 'The complete NERDC national curriculum, '
                          'Primary 1 to SSS 3, with syllabuses and lesson '
                          'notes',
                    ),
                    _divider(context),
                    _FactRow(
                      icon: 'account_balance',
                      label: 'Learn system',
                      value: '10,000+ tertiary courses with unit-by-unit '
                          'notes, end-of-unit revision exams, streaks, '
                          'gems and reward chests',
                    ),
                    _divider(context),
                    _FactRow(
                      icon: 'domain',
                      label: 'For schools',
                      value: 'A full school portal: syllabuses, lecture '
                          'notes, attendance, results with positions, ID '
                          'cards and fee receipts',
                    ),
                    _divider(context),
                    _FactRow(
                      icon: 'devices',
                      label: 'Platforms',
                      value: 'Android, iOS, Windows, macOS and the web '
                          '(renance.app) - free to start',
                    ),
                    _divider(context),
                    _FactRow(
                      icon: 'public',
                      label: 'Country',
                      value: 'Nigeria - built in Nigeria by Resolute Femi '
                          'for Nigerian students, candidates and schools',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            // The name block - Renance is a coined brand, not renaissance.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.cardLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'About the name',
                      style: RenanceText.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Renance is a coined brand name. It is not the word '
                      'renaissance, not the word resonance, and not a '
                      'variant of either. The educational platform Renance '
                      'exists only at renance.app - anywhere else is a '
                      'different, unrelated entity.',
                      style: RenanceText.bodySecondary.copyWith(
                        color: context.textSecondary,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Renance · Learn. Practice. Rise.',
                style: RenanceText.caption.copyWith(
                  color: context.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(height: 1, color: context.outlineVariant),
      );
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.label, required this.value});

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MsIcon(icon, size: 19, color: context.primaryInk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: RenanceText.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: RenanceText.bodySecondary.copyWith(
                    color: context.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
