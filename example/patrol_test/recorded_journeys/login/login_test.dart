import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:patrol_recorder_example/app.dart' as app;

import 'login_data.dart';

void main() {
  final data = loadProfile();
  patrolTest("Sign in with demonstration profile"
      ' [${data.name}]', ($) async {
    final semantics = $.tester.ensureSemantics();
    try {
      await $.pumpWidgetAndSettle(app.createApp());
      await $.enterText(
        find.byKey(const ValueKey<String>("email")),
        data.value("email"),
        enablePatrolLog: false,
      );
      await $.enterText(
        find.byKey(const ValueKey<String>("note")),
        data.value("note"),
        enablePatrolLog: false,
      );
      await $(find.bySemanticsIdentifier("demo.login")).tap();
    } finally {
      semantics.dispose();
    }
  }, tags: ["recorder_login_sign_in"]);
}
