import 'package:flutter/material.dart';
import './routes/auth.dart';

void main() => runApp(MyApp());

// Starting with main.dart which is just setting the title and home as the AuthScreen at routes/auth.dart.
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthScreen(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light()
    );
  }
}