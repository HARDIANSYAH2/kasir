import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:kasir/firebase_options.dart';
import 'package:kasir/login_page.dart';
import 'package:kasir/kelola_pesanan.dart';


void main() async {
  runApp(const MyApp());
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}