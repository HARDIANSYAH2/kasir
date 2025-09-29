import 'package:flutter/material.dart';
import 'package:kasir/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase
  await Supabase.initialize(
    url: 'https://htqbhxbnivsqwyruoxfq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh0cWJoeGJuaXZzcXd5cnVveGZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg4MDgyOTMsImV4cCI6MjA3NDM4NDI5M30.9QlYX89Hrh8HMlcg2mIEVLF8k3lOiNCLk040Jv2qd8s',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}


// cUFx7hY44RmVW354