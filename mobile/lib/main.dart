import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'app/kirenz_app.dart';

Future<void> main() async {
  final container = await bootstrap();

  runApp(
    UncontrolledProviderScope(container: container, child: const KirenzApp()),
  );
}
