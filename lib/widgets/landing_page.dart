import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './reactive_refresh_indicator.dart';
import 'package:http/http.dart';
import './history.dart';

typedef void OnError(Exception exception);

enum PlayerState { stopped, playing, paused }

class LandingPageApp extends StatefulWidget {
  @override
  _LandingPageAppState createState() => new _LandingPageAppState();
}

class _LandingPageAppState extends State<LandingPageApp> {

  //variables
  var jobid, counter, time, displayemail, url="", data="", newtxt="", oldtxt="";

  //boolean variables for checking the tasks
  bool _btndisabled= true, _isRefreshing = true, _iscompleted = false;

  //text editing controller
  final TextEditingController _controller = new TextEditingController();

  //firebase initialisation
  FirebaseUser user;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Firestore _firestore = Firestore.instance;

  //AudioPlayer variables initialisation
  /// Flutter can only play audios on device folders, so first this class copies the files to a temporary folder, and then plays them.
  /// You can pre-cache your audio, or clear the cache, as desired.

  AudioCache audioCache = new AudioCache(); // calling the audiocache function from "audio_cache.dart".
  AudioPlayer advancedPlayer = new AudioPlayer(); //creating an instance for audioplayer
  bool isLocal;
  PlayerMode mode;
  AudioPlayerState _audioPlayerState;
  Duration _duration;
  Duration _position;
  PlayerState _playerState = PlayerState.stopped;
  StreamSubscription _durationSubscription;
  StreamSubscription _positionSubscription;
  StreamSubscription _playerCompleteSubscription;
  StreamSubscription _playerErrorSubscription;
  StreamSubscription _playerStateSubscription;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AudioPlayer _audioPlayer;
  get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState(){
    logUser().then((res) {
      super.initState();
      _initAudioPlayer();
    }).catchError((e){print(e);});
  }

  // player() widget represents the audio player  i.e., play and skip
  Widget player() {
    return new Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        new Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Play icon - used to play the audio fragment.
            new IconButton(
                onPressed: _isPlaying ? null : () => _play(),
                iconSize: 64.0,
                icon: new Icon(Icons.play_arrow),
                color: Colors.cyan),

            //Skip Icon- used to skip the job
            new IconButton(
                iconSize: 64.0,
                icon: new Icon(Icons.last_page),
                color: Colors.blueAccent),
          ],
        ),

        //This row indicates the  CircularProgressIndicator icon and its progress based on the application state.
        new Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            new Padding(
              padding: new EdgeInsets.all(12.0),
              child: new Stack(
                children: [
                  new CircularProgressIndicator( //This is used not playing i.e, initial state and end state.
                    value: 1.0,
                    valueColor: new AlwaysStoppedAnimation(Colors.grey[300]),
                  ),
                  new CircularProgressIndicator( //this is used when the audio is playing.
                    value: (_position != null &&
                        _duration != null &&
                        _position.inMilliseconds > 0 &&
                        _position.inMilliseconds < _duration.inMilliseconds)
                        ? _position.inMilliseconds / _duration.inMilliseconds
                        : 0.0,
                    valueColor: new AlwaysStoppedAnimation(Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // _updateCount() is used to update the count of the number of jobs done by the user for each instance.
  Future<void> _updateCount() async{
    var query = _firestore.collection('jobs').where('user', isEqualTo:  '/users/'+ user.uid).where('status', isEqualTo: 'done');
    var qs = await query.getDocuments();
    print(qs.documents.length);
    setState(() {
      counter = qs.documents.length;
  });
}

  // _assignJob() is used to assign a job for the user by sending a post request to the cloud function
  Future<void> _assignJob() async {
    setState(() {
      this._isRefreshing = true; //Updating the boolean value to false if the job is not assigned to the user.
    });

    // uri is the link for the assignJob cloud function.
    final uri = 'https://us-central1-audiotranslation-f775a.cloudfunctions.net/assignJob';

    // headers is the type in which the content is sent to the cloud fucntion.
    final headers = {'Content-Type': 'application/json'};

    // storing the email id of the user in the body of the json data.
    Map<String, dynamic> body = {'email': user.email};

    // jsonBody is the encoded version of the email id
    String jsonBody = json.encode(body);

    // the format in which the json data is encoded.
    final encoding = Encoding.getByName('utf-8');

    //send a post request and waiting for the response and storing it in "response" variable.
    Response response = await post(
      uri,
      headers: headers,
      body: jsonBody,
      encoding: encoding,
    );

    // getting the jobid from the json body.
    jobid = jsonDecode(response.body)["jobid"]; // condition might not work for few situations.

    //checking the status code
    if(response.statusCode==200){ // if success
      var query = _firestore.collection('jobs').document(jobid); // query to get the documents of "jobs" collection using "jobid" from firestore.
      var doc = await query.get(); // getting the documents in the collection "jobs" using the query.
      var job = doc.data; // getting the data from the documents.
      // query to get the "fragment" field from "fragments" collection using "fragment id" in the current job from firestore.
      query =  _firestore.collection('fragments').document(job['fragment'].split('/')[2]);
      doc = await query.get(); //executing the query
      setState(() {
        // updating the url for each instance which we get from the fragments collection.
        this.url = doc.data['url'];
        this._isRefreshing = false; // updating the "_isRefreshing" to false i.e., the refreshing is done.
        _initAudioPlayer(); //calling the "_initAudioPlayer" function.
      });
    }
    else if(response.statusCode == 404){ //if not success i.e., there are no jobs left.
      if(response.body == 'No fragments to assign a job.'){
        setState(() {
          _iscompleted = true; //updating the boolean "_iscompleted" to true.
        });
      }
      return;
    }
    else{ //If there is another status code other than 200 or 404 then
      return; // return null
    }
  }

  // logUser() function is implemented to check whether the user is logged in and once signed in then storing the email in users collection, assign a job to that user and also update the count of jobs.
  Future<void> logUser() async {
    user = await _auth.currentUser(); // wait till we get the current user.
    await _firestore.collection('users').document(user.uid).setData({"email": user.email}, merge: true) ; // store the email in the users collection.
    await _assignJob(); // assign a job
    await _updateCount(); //updating the count
    displayemail = user.email; //Storing the user email to display in side menu bar
  }

  // _text() is used to get the fragment id i.e., mkbid
  Widget _text() {
    var t = this.url.split("/"); // split the url using '/'
    var s = t[t.length - 1].split(".")[0]; //getting the mkbid from the url.
    return Text(s);
  }

  // tracking the difference between old and new texts
  _chardifference(String str1, String str2){
//    print(str1+" : "+ str2);
    time = new DateTime.now().millisecondsSinceEpoch; // Unix time (also known as POSIX time or UNIX Epoch time) is a system for describing a point in time. It is the number of seconds that have elapsed since 00:00:00 Thursday, 1 January 1970, Coordinated Universal Time (UTC), minus leap seconds.
    var i = 0;
    var j = str1.length - 1;
    var k = str2.length - 1;

    while(i < str1.length && i < str2.length && str1[i] == str2[i]) {
      i++;
    }

    while(j >= 0 && k >= 0 && str1[j] == str2[k]) {
      j --;
      k --;
    }

    if(str1.length < str2.length){
      if(str2.substring(i, k+1) == " "){
        data += "INSERT|SP"+"|$time"+"|$str2"+"\n";  // If space then updating it to the "data" string.
        var t = str2.substring(i, k+1);
      }

      else{data +="INSERT|" + str2.substring(i, k + 1) + "|$time" +"|$str2"+ "\n";}
    }
    else{
      if(str1.substring(i, j+1) == " "){
        data += "DELETE|SP"+"|$time"+"|$str2"+"\n";  // If space then updating it to the "data" string.
      }
      else{
        data +="DELETE|" + str1.substring(i, j+1) + "|$time" +"|$str2"+"\n"; //If not then updating the character to the "data" string.
      }
    }
  }
  Widget remoteUrl() {
    return SingleChildScrollView( // Scroll view the whole page
      child: !_iscompleted ? Column( // Only if there are jobs left for a user this displays.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:<Widget>[

            // Display the mkbid.
            new Card(
              child: _text(),
            ),

            //Display the audio player which includes the play button and skip button
            new Card(
              child: player(),
            ),

            // Display the text field where user can type the input and submit.
            new Card(
              child: Row(
                children: <Widget>[
                  new Flexible(
                    child:  new TextField( // A TextField widget allows collection of information from the user.
                          //Since TextFields do not have an ID like in Android, text cannot be retrieved upon demand and must instead be stored in a variable on change or use a controller.
                          controller: _controller,
                          // I have used the onChanged method and store the current value in a simple variable.
                          //on changed text
                          onChanged: (text){
                            if(text==""){
                              setState(() {
                                _btndisabled = true;
                              });
                            }
                            else{
                              setState(() {
                                _btndisabled = false;
                              });
                            }
                            newtxt=text; //The letter or data typed for this instance.
                            _chardifference(oldtxt, newtxt);
                            oldtxt = newtxt;
                          },
                          keyboardType: TextInputType.multiline,
                          maxLines: null, // Number of lines in the text field.
                          autofocus: true,
                          decoration: new InputDecoration.collapsed(
                              hintText: 'Start typing here...'
                          ),
                          style: new TextStyle(fontSize: 16.0), //Font size for the text field to write the text.
                        ),
                  ),

                  //Submit button
                  new IconButton(icon: new Icon(Icons.check_circle),
                    onPressed: _btndisabled ? null : (){
                      setState(() {
                        next();// Calling the next method.
                      });
                    },
                  ),
                ],
              ),
            ),
          ]
      ) : Text("All jobs are completed."), // Displayed when all the jobs are done for the user.
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        drawer: Drawer(
            child: new ListView(
              children: <Widget> [

                // Displays the email id of the respective user.
                new ListTile(
                  title: new Text(displayemail.toString()),
                ),

                //Displays the performance of the user.
                new ListTile(
                  title: new Text('Performance'),
                  onTap: () {},
                ),

                // Displays the history i.e., the deliverables for a user.
                new ListTile(
                  title: new Text('History'),
                  onTap: () {
                    Navigator.of(context) .push(MaterialPageRoute<Null>(builder: (BuildContext context) { return new HistoryWidget();}));                  },
                ),

                //About is used to display the text about the app i.e., versions, updates etc.
                new ListTile(
                  title: new Text('About'),
                  onTap: () {},
                ),
                new Divider(),
              ],
            )
        ),
        appBar: AppBar(
          title: Text("Transcription"),
          actions: <Widget>[
            // Chips are compact elements that represent an attribute, text, entity, or action.
            //Chip here is used to display the count of jobs done.
            Chip(
              label: Text('$counter Jobs done'),
            ),
          ],
        ),

        body:
          ReactiveRefreshIndicator(
            onRefresh: _onRefresh, // Checking if the refresh is done or not.
            isRefreshing: _isRefreshing, // updating the "_isRefreshing" based on the applicaition status.
            child: Container(child: remoteUrl()), // Calling the remoteUrl() widget which has the whole process.
          ),
    );
  }

  // This function is used to update the values in "jobs" collection for respective "jobid".
  submit() async{
    await Firestore.instance.collection('jobs').document(jobid).updateData({
      'submission_ts': Timestamp.now(),
      'log_data': data,
      'deliverable': oldtxt,
      'status': 'done'
    });
  }

  // this function is asynchronous and used to update the count of jobs done and assign a job for the user which is not submitted.
  next() async{
    setState(() {
      _btndisabled = true;
    });
    await submit(); // submission is done.
    await _updateCount(); // count of jobs is updated.
    _controller.clear(); // clear the text in text field.
    data=""; // make the string null.
    oldtxt = "";
    newtxt= "";
    _initAudioPlayer(); // initiate the audio player.
    await _assignJob(); // assign a job.
  }

  // Checking if the refreshing is happening or not  #debug
  Future<Null> _onRefresh() async{
    print('refreshing ;)');
  }

  // Function to represent the audio player.
  void _initAudioPlayer() {
    this.isLocal = false;
    this.mode = PlayerMode.MEDIA_PLAYER;
    _audioPlayer = new AudioPlayer(mode: mode);

    // States to represent audio playback.

    // checking the duration of the audio clip.
    _durationSubscription =
        _audioPlayer.onDurationChanged.listen((duration) => setState(() {
          _duration = duration;
        }));

    //Status and current position
    //The dart part of the plugin listen for platform calls
    _positionSubscription =
        _audioPlayer.onAudioPositionChanged.listen((p) => setState(() {
          _position = p;
        }));

    // if the audio play is completed.
    _playerCompleteSubscription =
        _audioPlayer.onPlayerCompletion.listen((event) {
          _onComplete();
          setState(() {
            _position = _duration;
          });
        });

    //when the player stops
    _playerErrorSubscription = _audioPlayer.onPlayerError.listen((msg) {
      setState(() {
        _playerState = PlayerState.stopped;
        _duration = new Duration(seconds: 0);
        _position = new Duration(seconds: 0);
      });
    });

    // Do not forget to cancel all the subscriptions when the widget is disposed.
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _audioPlayerState = state; //checking the state of the player whether it is stopped or playing.
      });
    });
  }

  // Player Controls
  Future<int> _play() async {
    // start the audio play only when the position and duration are null.
    final playPosition = (_position != null &&
        _duration != null &&
        _position.inMilliseconds > 0 &&
        _position.inMilliseconds < _duration.inMilliseconds)
        ? _position // if it is null then return position
        : null; //else return null
    final result = await _audioPlayer.play(url, isLocal: isLocal, position: playPosition); //waiting for the audio to play.
    if (result == 1) setState(() => _playerState = PlayerState.playing); // audio plays when it loads to local path.
    return result;
  }

  //Checking if the audio play is completed or not.
  void _onComplete() {
    setState(() => _playerState = PlayerState.stopped); //set the player state to null
  }
}
