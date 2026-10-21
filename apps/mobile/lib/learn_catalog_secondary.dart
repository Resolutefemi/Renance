/// HARDCODED secondary catalog - the web's
/// apps/web/lib/learn-catalog-secondary.ts ported 1:1 (founder directive
/// 2026-10-14: "make sure the courses list are hard coded and make sure
/// it's working just like supreme"; the ids match the backend seed byte
/// for byte, so a tap opens the real path).
///
/// Founder report 2026-10-21 ("the jamb desk courses is not showing jamb
/// subjects it's showing tertiary institution desk courses"): the
/// server's /learn/catalog only serves the TERTIARY desk - asking it for
/// body=jamb returned university modules. The web never does: the
/// secondary desks render THIS shelf, the server catalog is reserved
/// for the tertiary institution desk.
///
/// Founder directive 2026-10-21 ("remove those Agriculture (WASSCE) and
/// other waec and neco subjects - on the courses page for waec, neco and
/// post UTME desk courses should be the jamb own 300 topics subject"):
/// every secondary desk (JAMB, WAEC, NECO, Post-UTME on the web) lists
/// the SAME JAMB subjects. The old WASSCE/NECO-specific shelves are
/// gone.
class HardCatalogItem {
  const HardCatalogItem(this.id, this.title, this.n);

  final String id;
  final String title;

  /// Topic count, shown on the row.
  final int n;
}

/// Founder directive 2026-10-21 ("the topics under the jamb courses is
/// 300 - change the number on the selection list to 300 Topics"): every
/// JAMB subject carries 300 topics / 15 units in the product, so the
/// picker rows read 300 for all 16 subjects (the count is display
/// copy - the roadmap ids still open the real server paths).
const List<HardCatalogItem> kJambCatalog = <HardCatalogItem>[
  HardCatalogItem('SEC-JAMB-AGRICULTURAL-SCIENCE', 'Agricultural Science', 300),
  HardCatalogItem('SEC-JAMB-BIOLOGY', 'Biology', 300),
  HardCatalogItem('SEC-JAMB-CHEMISTRY', 'Chemistry', 300),
  HardCatalogItem('SEC-JAMB-CRS', 'Christian Religious Studies', 300),
  HardCatalogItem('SEC-JAMB-CIVIC-EDUCATION', 'Civic Education', 300),
  HardCatalogItem('SEC-JAMB-COMMERCE', 'Commerce', 300),
  HardCatalogItem('SEC-JAMB-COMPUTER-STUDIES', 'Computer Studies', 300),
  HardCatalogItem('SEC-JAMB-ECONOMICS', 'Economics', 300),
  HardCatalogItem('SEC-JAMB-ENGLISH', 'English Language', 300),
  HardCatalogItem('SEC-JAMB-GEOGRAPHY', 'Geography', 300),
  HardCatalogItem('SEC-JAMB-GOVERNMENT', 'Government', 300),
  HardCatalogItem('SEC-JAMB-HISTORY', 'History', 300),
  HardCatalogItem('SEC-JAMB-LITERATURE', 'Literature in English', 300),
  HardCatalogItem('SEC-JAMB-MATHEMATICS', 'Mathematics', 300),
  HardCatalogItem('SEC-JAMB-PHYSICS', 'Physics', 300),
  HardCatalogItem('SEC-JAMB-ACCOUNTING', 'Principles of Accounts', 300),
];

/// The secondary desk's hardcoded shelf - the JAMB 300-topic subjects
/// on EVERY secondary desk (founder directive 2026-10-21, see the file
/// header). The [body] argument stays for call-site compatibility.
List<HardCatalogItem> secondaryCatalog(String body) => kJambCatalog;

/// True when the desk body carries a hardcoded shelf (the secondary
/// desks) - false for the tertiary desk, whose catalog lives on the
/// server.
bool bodyHasHardcodedShelf(String body) {
  final String b = body.toLowerCase();
  return b == 'jamb' || b == 'waec' || b == 'neco';
}
