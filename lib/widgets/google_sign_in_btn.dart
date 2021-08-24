import 'package:flutter/material.dart';


// Reference: "https://developers.google.com/identity/branding-guidelines"

class GoogleSignInButton extends StatelessWidget {

  // onPressed function is written in auth.dart
  final Function onPressed;

  //Keys preserve state when widgets move around in your widget tree.
  // In practice, this means they can be useful to preserve the user’s scroll location or keep state when modifying a collection.
  GoogleSignInButton({
    Key key,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      onPressed: () => this.onPressed(),
      color: Colors.white,
      elevation: 0.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset( // image for google sign in
            "assets/images/glogo.png",
            height: 18.0,
            width: 18.0,
          ),
          SizedBox(width: 16.0), // size of box
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text( // text to be displayed
              "Sign in with Google",
              style: TextStyle( // styling
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
