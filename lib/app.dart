// lib/app.dart
import 'package:flutter/material.dart';
import 'package:word_app/features/word_card/view/word_card_screen.dart';

class WordApp extends StatelessWidget {
  const WordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word App',
      debugShowCheckedModeBanner: false, // Hides the debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        // For better Japanese font rendering
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'NotoSansJP',
        ),
      ),
      home: const WordCardScreen(),
    );
  }
}