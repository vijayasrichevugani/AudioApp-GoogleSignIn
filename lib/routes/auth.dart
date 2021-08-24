import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:audiotranslation/widgets/logger.dart';
import '../widgets/google_sign_in_btn.dart';
import '../widgets/reactive_refresh_indicator.dart';
import 'package:audiotranslation/widgets/landing_page.dart';

// Each item on AuthStatus represents quite literally the status of the UI.
// On SOCIAL_AUTH only the GoogleSignInButton will be visible.
enum AuthStatus { SOCIAL_AUTH}

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

// On _AuthScreenState we start by defining the tag that will be used for our logger, then the default status as SOCIAL_AUTH, which means we need to do Google's sign in and the GoogleSignInButton will be visible and interactive.
class _AuthScreenState extends State<AuthScreen> {
  static const String TAG = "AUTH";
  AuthStatus status = AuthStatus.SOCIAL_AUTH;

  // a GlobalKey for our Scaffold so we can display a SnackBar whenever an error occurs.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  //_isRefreshing controls whether the "spinning wheel" of RefreshIndicator is visible.
  bool _isRefreshing = false;

  // _auth is the instance for FirebaseAuth.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //_googleSignIn is the instance for GoogleSignIn.
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  //_googleUser is the instance of GoogleSignInAccount that will be filled later.
  GoogleSignInAccount _googleUser;

  // Styling
  final decorationStyle = TextStyle(color: Colors.grey[50], fontSize: 16.0);
  final hintStyle = TextStyle(color: Colors.white24);

  // All the methods here are asynchronous so we can wait for their result before going on with anything.

  // _updateRefreshing, controls our ReactiveRefreshIndicator's state, making sure it is not displaying any animations before we start it.
  Future<Null> _updateRefreshing(bool isRefreshing) async {
    Logger.log(TAG, message: "Setting _isRefreshing ($_isRefreshing) to $isRefreshing");
    if (_isRefreshing) {
      setState(() {
        this._isRefreshing = false;
        // When the user is signed in, we move to landingpage.
        Navigator.of(context).push(MaterialPageRoute<Null>(builder: (BuildContext context) { return new LandingPageApp();}));
      });
    }
    setState(() {
      this._isRefreshing = isRefreshing;
    });
  }

  // _showErrorSnackbar makes sure we aren’t showing our refresh indicator before showing an SnackBar with an error.v
  _showErrorSnackbar(String message) {
    _updateRefreshing(false);
    _scaffoldKey.currentState.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // _signIn will call GoogleSignIn's own signIn method and then the user will select their Google account (on Android) or log in it (on iOS).
  Future<Null> _signIn() async {
    GoogleSignInAccount user = _googleSignIn.currentUser;
    Logger.log(TAG, message: "Just got user as: $user");

    final onError = (exception, stacktrace) {
      Logger.log(TAG, message: "Error from _signIn: $exception");
      _showErrorSnackbar(
          "Couldn't log in with your Google account, please try again!");
      user = null;
    };

    // Checking if the user is not logged in.
    if (user == null) {
      user = await _googleSignIn.signIn().catchError(onError);
      Logger.log(TAG, message: "Received $user");
      final GoogleSignInAuthentication googleAuth = await user.authentication;
      Logger.log(TAG, message: "Added googleAuth: $googleAuth");
      await _auth
          .signInWithCredential(GoogleAuthProvider.getCredential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          ))
          .catchError(onError);
    }

    // If the user is logged in then store the current user details.
    if (user != null) {
      _updateRefreshing(false);
      this._googleUser = user;
      return null;
    }
    return null;
  }

  // Widgets
  Widget _buildSocialLoginBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Styling
        crossAxisAlignment: CrossAxisAlignment.center, // Styling
        children: <Widget>[
          SizedBox(height: 24.0), // Styling
          GoogleSignInButton( //On press of google sign in btn
            onPressed: () => _updateRefreshing(true), // starting the refreshing when onpressed function.
          ),
        ],
      ),
    );
  }

  //  _buildBody and _onRefresh which are methods based on the state of the application.
  Widget _buildBody() {
    Widget body;
    switch (this.status) {
      case AuthStatus.SOCIAL_AUTH: // checking if the login is using google
        body = _buildSocialLoginBody(); // calling the widget _buildSocialLoginBody
        break;
      default:  break; // if not google sign in - do nothing
    }
    return body;
  }

  Future<Null> _onRefresh() async {
    switch (this.status) { //checking the status
      case AuthStatus.SOCIAL_AUTH: // if google sign in
        return await _signIn(); //wait till the sign in is done.
        break;
      default: break; // if not - do nothing
    }
  }

  // build method which initiates the login and refresh based on state of application as mentioned above.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(elevation: 0.0),
      backgroundColor: Theme.of(context).primaryColor,
      body: Container(
        child: ReactiveRefreshIndicator( // building the ReactiveRefreshIndicator widget.
          onRefresh: _onRefresh, // calling the onrefresh function.
          isRefreshing: _isRefreshing, // checking the _isrefreshing variable which is changed based on application status.
          child: Container(child: _buildBody()),
        ),
      ),
    );
  }
}
