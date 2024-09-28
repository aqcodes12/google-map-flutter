import 'package:flutter/material.dart';
import 'package:google_maps/map_screen.dart';
import 'package:google_maps/map_screen_with_navigate.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MapScreenWithNavigate());
  }
}
