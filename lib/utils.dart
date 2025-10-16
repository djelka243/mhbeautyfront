import 'package:flutter/material.dart';

class Utils {
  static const String USER_KEY = 'USER_KEY';
  static const String TOKEN_KEY = 'TOKEN_KEY';
  static const String ApiBaseUrl = 'http://192.168.11.102:8000';


  static afficherSnack(BuildContext context, String msg,[Color color = Colors.red]) {
    ScaffoldMessenger.of(context).clearSnackBars();
    final scaffold = ScaffoldMessenger.of(context);
    var snackbar = SnackBar(
      backgroundColor: color,
      content: Text(msg),
    );
    scaffold.showSnackBar(snackbar);
  }
  static lancerChargementDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
            content: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Traitement en cours..."),
                SizedBox(height: 12.0),
                CircularProgressIndicator(),
              ],
            ));
      },
    );
  }
  static closeKeyboard(BuildContext context) {
    FocusScopeNode currentFocus = FocusScope.of(context);

    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }
  }

}