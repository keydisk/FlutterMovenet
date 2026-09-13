import 'package:flutter/material.dart';
import 'package:movenet_core/movenet_core.dart';

import 'router.dart';

class MovenetApp extends StatelessWidget {
  const MovenetApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'MoveNet Coach',
    theme: MovenetTheme.dark,
    routerConfig: appRouter,
  );
}
