/// Study, the PDF & resources shelf — the Flutter port of the web's
/// /study page, 1:1. Free, legal, downloadable study material for
/// secondary and university students: official syllabi, open textbooks,
/// past-question archives and curated open collections. Every link is
/// external and opens out of the app; Renance stays the practice layer.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

class _Resource {
  const _Resource(this.name, this.desc, this.url, this.tag);
  final String name;
  final String desc;
  final String url;
  final String tag; // PDF | Web | Repo
}

class _Category {
  const _Category(this.title, this.icon, this.items);
  final String title;
  final IconData icon;
  final List<_Resource> items;
}

const List<_Category> _studyCategories = <_Category>[
  _Category('Official syllabi & exam bodies', Icons.gavel, <_Resource>[
    _Resource(
      'JAMB IBASS',
      'The official UTME brochure and subject syllabus, straight from the exam body.',
      'https://ibass.jamb.gov.ng',
      'Web',
    ),
    _Resource(
      'WAEC e-learning portal',
      'Free WASSCE past questions and Chief Examiner reports for every subject, by year.',
      'https://waeconline.org.ng/e-learning/',
      'PDF',
    ),
    _Resource(
      'WAEC Nigeria',
      'Official timetables, regulations and exam notices for WASSCE candidates.',
      'https://www.waecnigeria.org',
      'Web',
    ),
    _Resource(
      'NECO',
      'Official NECO timetables, syllabuses and candidate information.',
      'https://www.neco.gov.ng',
      'Web',
    ),
  ]),
  _Category('Free textbooks (PDF)', Icons.picture_as_pdf, <_Resource>[
    _Resource(
      'OpenStax, Biology 2e',
      'Full university-standard biology textbook, free PDF, covers every WAEC/NECO bio topic.',
      'https://openstax.org/details/books/biology-2e',
      'PDF',
    ),
    _Resource(
      'OpenStax, Chemistry 2e',
      'Complete chemistry text with worked examples and end-of-chapter drills.',
      'https://openstax.org/details/books/chemistry-2e',
      'PDF',
    ),
    _Resource(
      'OpenStax, College Physics',
      'Algebra-based physics that maps cleanly onto the SS1-SS3 syllabus.',
      'https://openstax.org/details/books/college-physics',
      'PDF',
    ),
    _Resource(
      'OpenStax, Precalculus',
      'Numbers, algebra, trigonometry and functions, the engine room of UTME maths.',
      'https://openstax.org/details/books/precalculus',
      'PDF',
    ),
    _Resource(
      'LibreTexts',
      'A giant open library of course texts and problem sets across all science subjects.',
      'https://libretexts.org',
      'Web',
    ),
    _Resource(
      'Open Textbook Library',
      'Hundreds of openly licensed textbooks, searchable by subject, downloadable as PDF.',
      'https://open.umn.edu/opentextbooks',
      'PDF',
    ),
    _Resource(
      'Directory of Open Access Books',
      'Academic-grade open books, strong for economics, government and literature.',
      'https://doabooks.org',
      'PDF',
    ),
  ]),
  _Category('Reading & set texts', Icons.auto_stories, <_Resource>[
    _Resource(
      'Project Gutenberg',
      '70,000+ free classics, most literature set texts live here as free eBooks.',
      'https://www.gutenberg.org',
      'PDF',
    ),
    _Resource(
      'African Storybook',
      'Open African stories and readers in dozens of languages, printable as PDFs.',
      'https://africanstorybook.org',
      'PDF',
    ),
  ]),
  _Category('Computer studies & coding', Icons.code, <_Resource>[
    _Resource(
      'freeCodeCamp',
      'Free full curriculum for web development, data analysis and more, with certificates.',
      'https://www.freecodecamp.org',
      'Web',
    ),
    _Resource(
      'free-programming-books',
      'The legendary GitHub list of free programming books and notes in many languages.',
      'https://github.com/EbookFoundation/free-programming-books',
      'Repo',
    ),
    _Resource(
      'OSSU Computer Science',
      'A complete free CS degree, course by course, with a community to keep you honest.',
      'https://github.com/ossu/computer-science',
      'Repo',
    ),
    _Resource(
      'Teach Yourself CS',
      'Nine subjects that make a computer scientist, with the exact free book for each.',
      'https://teachyourselfcs.com',
      'Web',
    ),
  ]),
  _Category('Curated collections', Icons.collections_bookmark, <_Resource>[
    _Resource(
      'All-Resources by Resolute Femi',
      '300 hand-picked open educational repositories from across the globe, textbooks, notes, past questions.',
      'https://github.com/Resolutefemi/All-Resources',
      'Repo',
    ),
  ]),
];

/// Study resources, the Stitch study_light screen on real links.
class StudyResourcesScreen extends StatefulWidget {
  const StudyResourcesScreen({super.key});

  @override
  State<StudyResourcesScreen> createState() => _StudyResourcesScreenState();
}

class _StudyResourcesScreenState extends State<StudyResourcesScreen> {
  String? _open = _studyCategories.first.title;

  Future<void> _launch(String url) async {
    final Uri uri = Uri.parse(url);
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      // Sticky back bar, the same header language as the Arena lobby.
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: context.pageBg,
                border: Border(
                  bottom: BorderSide(
                    color: context.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              padding: const EdgeInsets.only(left: 8, right: 16),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: context.ink,
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                    const Text('Study', style: RenanceText.sectionTitle),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: <Widget>[
                  Text('Study resources', style: RenanceText.displayLg),
                  const SizedBox(height: 4),
                  Text(
                    'Free PDFs, textbooks and archives for your exam, all legal, all open, all free.',
                    style: RenanceText.bodySecondary
                        .copyWith(color: context.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  for (final _Category cat in _studyCategories) ...<Widget>[
                    _CategoryCard(
                      category: cat,
                      open: _open == cat.title,
                      onToggle: () => setState(() {
                        _open = _open == cat.title ? null : cat.title;
                      }),
                      onOpenResource: _launch,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One expandable category with its resource rows.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.open,
    required this.onToggle,
    required this.onOpenResource,
  });

  final _Category category;
  final bool open;
  final VoidCallback onToggle;
  final void Function(String url) onOpenResource;

  Color _tagBg(BuildContext context, String tag) => switch (tag) {
        'PDF' => context.errorContainer,
        'Web' => context.selectionBlue,
        _ => context.cardHigh,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x0F141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.cardHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(category.icon,
                        size: 22, color: context.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(category.title, style: RenanceText.bodyMedium),
                        const SizedBox(height: 2),
                        Text('${category.items.length} resources',
                            style: RenanceText.labelMono
                                .copyWith(fontSize: 12, color: context.textSecondary)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more,
                        size: 20, color: context.textMuted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOut,
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: <Widget>[
                for (final _Resource r in category.items)
                  InkWell(
                    onTap: () => onOpenResource(r.url),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(r.name, style: RenanceText.bodyMedium),
                                const SizedBox(height: 2),
                                Text(
                                  r.desc,
                                  style: RenanceText.caption.copyWith(
                                      color: context.textSecondary,
                                      height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _tagBg(context, r.tag),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(r.tag,
                                style: RenanceText.labelMono
                                    .copyWith(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
