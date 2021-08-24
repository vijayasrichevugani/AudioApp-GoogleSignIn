import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryWidget extends StatefulWidget {
  @override
  _historyAppState createState() => new _historyAppState();
}

class _historyAppState extends State<HistoryWidget> {

  //List of deliverables to be added from firebase in a list "docs"
  List<String> docs;

  // Firebase instance initialisation
  FirebaseUser user;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Firestore _firestore = Firestore.instance;

  //logUser is used to check whether the user signin is done or not. #debug
  Future<void> logUser() async {
    print(user.uid);
  }

  // On click of history the list of deliverables are added to "docs" list using the function "getdeliverables()".
  @override
  void initState(){
      docs = new List<String>();
      getdeliverables().then((d){
        super.initState();
      }).catchError((e){print(e);});
  }

  //Build method which initiates the process of getting deliverables field and displaying them using a Listview builder.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("History"),
      ),
      body: Container(
        // ListView.builder is a way of constructing the list where children’s (Widgets) are built on demand. However, instead of returning a static widget, it calls a function which can be called multiple times (based on itemCount ) and it’s possible to return different widget at each call.
        child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: docs.length,
            itemBuilder: (BuildContext context, int index) {
              return Container(
                height: 50,
                child: Center(child: Text('${docs[index]}')),
              );
            }
        ),
      ),
    );
  }

  // getting the deliverables field from firebase.
  Future<void> getdeliverables() async{
    user = await _auth.currentUser();
    var query = _firestore.collection('jobs').orderBy("submission_ts",  descending: true).where('user', isEqualTo:  '/users/'+ user.uid).where('status', isEqualTo: 'done');
    var qs = await query.getDocuments();
    setState(() {
      docs = List<String>.from(qs.documents.map((d) => d.data['deliverable']));
    });
  }
}