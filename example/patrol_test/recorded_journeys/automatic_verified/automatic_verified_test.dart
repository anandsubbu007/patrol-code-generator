import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:patrol_recorder_example/app.dart' as app;

import 'automatic_verified_data.dart';

void main() {
  final data = loadProfile();
  patrolTest("Sign in with demonstration profile"
      ' [${data.name}]', ($) async {
    await $.pumpWidgetAndSettle(app.createApp());
    final target1 = find.byKey(const ValueKey<String>("email"));
    await $(target1).waitUntilExists();
    expect(
      target1,
      findsOneWidget,
      reason: "step_0001: selector must match exactly one widget",
    );
    await $.enterText(target1, data.value("email"), enablePatrolLog: false);

    final target2 = find.byKey(const ValueKey<String>("note"));
    await $(target2).waitUntilExists();
    expect(
      target2,
      findsOneWidget,
      reason: "step_0002: selector must match exactly one widget",
    );
    await $.enterText(target2, data.value("note"), enablePatrolLog: false);

    final target3 = find.byKey(const ValueKey<String>("login"));
    await $(target3).waitUntilExists();
    expect(
      target3,
      findsOneWidget,
      reason: "step_0003: selector must match exactly one widget",
    );
    await $(target3).tap();
  }, tags: ["recorder_automatic_verified_sign_in"]);
}
