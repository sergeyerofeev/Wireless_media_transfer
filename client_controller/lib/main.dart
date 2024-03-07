import 'package:flutter/material.dart';
import 'views/client_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: const MaterialStatePropertyAll<Color>(Colors.black),
            foregroundColor: const MaterialStatePropertyAll<Color>(Colors.white),
            surfaceTintColor: const MaterialStatePropertyAll<Color>(Colors.black),
            padding: MaterialStateProperty.all(const EdgeInsets.all(15.0)),
            side: MaterialStateProperty.all(
              const BorderSide(color: Colors.white, width: 2),
            ),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3.0),
              ),
            ),
            overlayColor: MaterialStateProperty.resolveWith(
              (states) {
                return states.contains(MaterialState.pressed) ? Colors.grey : Colors.black;
              },
            ),
          ),
        ),
      ),
      home: const ClientView(),
    );
  }
}
