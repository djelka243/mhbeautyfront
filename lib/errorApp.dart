import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ErrorApp extends StatelessWidget {
  final FlutterErrorDetails details;

  const ErrorApp({Key? key, required this.details}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Erreur d\'application', style: TextStyle(color: Colors.white),),
          backgroundColor: Color(0xFF003366),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 60),
                  SizedBox(height: 16),
                  Text(
                    'L\'application a rencontré une erreur',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    details.exceptionAsString(),
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}