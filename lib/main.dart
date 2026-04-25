import 'package:flutter/material.dart';
import 'home_page.dart';
import 'package:provider/provider.dart';
import 'expGPS.dart';
import 'movementeanalizer.dart';
import 'package:permission_handler/permission_handler.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 

  await Permission.notification.request();

  runApp(
    // O teu MultiProvider continua igual...
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GPSController()),
        ChangeNotifierProvider(create: (_) => ImprovedMovementAnalyzer()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rowing tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Rowing tracker Home Page'),
    );
  }
}