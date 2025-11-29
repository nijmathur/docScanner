/// Test suite runner for all unit tests
///
/// Run with: flutter test test/all_tests.dart

import 'core/services/encryption_service_test.dart' as encryption_test;
import 'core/services/database_service_test.dart' as database_test;
import 'core/services/ocr_service_test.dart' as ocr_test;
import 'core/services/audit_service_test.dart' as audit_test;

void main() {
  encryption_test.main();
  database_test.main();
  ocr_test.main();
  audit_test.main();
}
