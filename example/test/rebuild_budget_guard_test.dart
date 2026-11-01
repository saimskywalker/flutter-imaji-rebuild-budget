// Fails if imaji_rebuild_budget moves to dependencies or is imported from
// lib/, so test code can never reach a release build of this app.
import 'package:flutter_test/flutter_test.dart';
import 'package:imaji_rebuild_budget/guard.dart';

void main() =>
    test('rebuild budgets stay out of the app', expectRebuildBudgetIsTestOnly);
