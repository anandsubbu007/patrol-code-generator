import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'recorder_panel.dart';
import 'src/devtools_backend.dart';

void main() => runApp(
  DevToolsExtension(child: RecorderPanel(backend: DevToolsRecorderBackend())),
);
