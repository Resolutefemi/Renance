/// The AI Generator entry point: now the front door into Renance AI
/// Studio's quiz tab (founder directive, 2026-09-30 the studio took
/// over generation - quizzes, notes, notebooks and lesson notes).
library;

import 'package:flutter/material.dart';

import 'ai_screen.dart';

class AiGeneratorScreen extends StatelessWidget {
  const AiGeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AiScreen(initialTab: AiStudioTab.quiz);
  }
}
