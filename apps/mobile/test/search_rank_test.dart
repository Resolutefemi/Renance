// Tests for the search matcher (pure) and splash timing contract.
import 'package:flutter_test/flutter_test.dart';
import 'package:renance/ui/search_screen.dart';

void main() {
  group('rankSearch', () {
    test('blank queries match nothing', () {
      expect(rankSearch('', <String>['cells']), 0);
      expect(rankSearch('   ', <String>['cells']), 0);
    });

    test('single token hits a title', () {
      expect(rankSearch('cell', <String>['Cell Structure', 'Biology']),
          greaterThan(0));
    });

    test('prefix hits outrank mid-string hits', () {
      final int prefix =
          rankSearch('cell', <String>['Cell Structure', 'Bio']);
      final int mid = rankSearch('cell', <String>['Muscle cell', 'Bio']);
      expect(prefix, greaterThan(mid));
    });

    test('all tokens must match (AND semantics)', () {
      expect(rankSearch('cell wall', <String>['Cell Structure']), 0);
      expect(
        rankSearch('cell wall', <String>['Cell wall and membranes', 'Bio']),
        greaterThan(0),
      );
    });

    test('matching is case-insensitive and spans fields', () {
      expect(
        rankSearch('NEWTON', <String>['Motion', 'Newton\'s laws, JAMB']),
        greaterThan(0),
      );
      expect(
        rankSearch('jamb newton', <String>['Motion', 'Newton\'s laws, JAMB']),
        greaterThan(0),
      );
    });

    test('unrelated haystacks score zero', () {
      expect(rankSearch('essay', <String>['Cell Structure', 'Biology']), 0);
    });
  });
}
