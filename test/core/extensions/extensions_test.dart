import 'package:flutter_test/flutter_test.dart';

import 'package:my_flutter_app/core/extensions/extensions.dart';

void main() {
  group('StringExtension', () {
    test('capitalize capitalizes first letter', () {
      expect('hello'.capitalize, 'Hello');
      expect(''.capitalize, '');
    });

    test('isValidEmail returns true for valid email', () {
      expect('test@example.com'.isValidEmail, true);
      expect('invalid-email'.isValidEmail, false);
    });

    test('truncate truncates long strings', () {
      expect('Hello World'.truncate(8), 'Hello...');
      expect('Short'.truncate(10), 'Short');
    });
  });

  group('DateTimeExtension', () {
    test('isToday returns true for today', () {
      expect(DateTime.now().isToday, true);
    });

    test('isYesterday returns true for yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(yesterday.isYesterday, true);
    });
  });
}
