import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audio_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_svprogresshud/flutter_svprogresshud.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slide_popup_dialog/slide_popup_dialog.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';

import 'file_entity_list_tile.dart';
import 'wav_header.dart';
import 'package:async/async.dart';
import 'package:fileaudioplayer/fileaudioplayer.dart';
import 'package:flutter/material.dart';

enum RecordState { stopped, recording }

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({this.server});

  @override
  _ChatPage createState() => new _ChatPage();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _ChatPage extends State<ChatPage> {
  bool resettimer = false;
  static final clientID = 0;
  BluetoothConnection connection;
  AudioCache audioCache = AudioCache();
  AudioPlayer advancedPlayer = AudioPlayer();
  //bool isConnected = true;
  bool isDisconnecting = false;

  List<List<int>> chunks = <List<int>>[];
  List<List<int>> chunksave = <List<int>>[];
  int contentLength = 0;
  int saveLength = 0;
  Uint8List _bytes;
  Uint8List _bytes1;

  Timer _timer;
  RecordState _recordState = RecordState.stopped;
  DateFormat dateFormat = DateFormat("yyyy-MM-dd_HH_mm_ss");

  int recordingstop = 0;
  List<FileSystemEntity> files = List<FileSystemEntity>();
  List<FileSystemEntity> prevfiles = List<FileSystemEntity>();
  String selectedFilePath;
  final AudioPlayer _player = AudioPlayer();
  FileAudioPlayer player = FileAudioPlayer();
  bool recording = false;

  List<_Message> messages = List<_Message>();
  String _messageBuffer = '';

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => connection != null && connection.isConnected;

  @override
  Future<void> initState() {
    super.initState();

    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (resettimer == false) {
        _completeByte();
      }
      resettimer = false;
    });

    /*Timer.periodic(Duration(seconds: 1), (timer) async {
      playByte();
    });*/
    Timer.periodic(Duration(seconds: 10), (timer) {
      _listofFiles();
    });
    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection.input.listen(_onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }

    super.dispose();
  }

  int i = 0;
  bool play = true;
  bool startsent = false;
  int recordstate = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting to') // ${widget.server.name} ...')
              : isConnected
                  ? Text('Connected with ${widget.server.name}')
                  : Text('Disconnected with ${widget.server.name}')),
        ),
        body: SafeArea(
          child: isConnected
              ? Column(
                  children: <Widget>[
                    Row(
                      children: [
                        Container(
                          width: 50,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: play == true
                                  ? Colors.yellow
                                  : Color(0xFFF7b3c2),
                            ),
                            width: 100,
                            height: 50,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (play == true) {
                                    play = false;
                                    if (startsent == false)
                                      _sendMessage("START");
                                    recordstate = 1;
                                    startsent = true;
                                  } else {
                                    play = true;
                                    setState(() {
                                      stopplay();
                                      if (startsent == true)
                                        _sendMessage("STOP");
                                      startsent = false;
                                      recordstate = 0;
                                    });
                                  }
                                });
                              },
                              child: Icon(
                                play == true ? Icons.play_arrow : Icons.cancel,
                                color: play == true
                                    ? Colors.lightGreen
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 20,
                        ),
                        play == false ? shotButton() : SizedBox(),
                      ],
                    ),
                    Divider(
                      height: 10,
                    ),
                    Container(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Center(
                              child: Text("Previous recored files",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: files
                            .map((_file) => FileEntityListTile(
                                  filePath: "Recording " +
                                      files.indexOf(_file).toString() +
                                      "\n" +
                                      FileStat.statSync(_file.path)
                                          .changed
                                          .toString()
                                          .substring(
                                              0,
                                              FileStat.statSync(_file.path)
                                                  .changed
                                                  .toString()
                                                  .lastIndexOf("000")),
                                  fileSize: _file.statSync().size,
                                  onLongPress: () async {
                                    print("onLongPress item");
                                    if (await File(_file.path).exists()) {
                                      File(_file.path).deleteSync();

                                      files.remove(_file);

                                      setState(() {});
                                    }
                                  },
                                  onTap: () async {
                                    if (play == true) {
                                      print("onTap item");
                                      if (_file.path == selectedFilePath) {
                                        await player.stop();
                                        selectedFilePath = '';
                                        return;
                                      }

                                      if (await File(_file.path).exists()) {
                                        selectedFilePath = _file.path;
                                        await player.start(_file.path);
                                      } else {
                                        selectedFilePath = '';
                                      }

                                      setState(() {});
                                    }
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Text(
                    "Connecting...",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
        ));
  }

  stopplay() async {
    await player.stop();
  }

  int power_btn_tick = 0, reset = 1;
  void _onDataReceived(Uint8List data) async {
    if (startsent == false) return;
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    chunksave.add(data);
    saveLength += data.length;

    if (data != null && data.length > 0 && (recording == true)) {
      if (recordstate == 3) {
        chunks.add(data);
        contentLength += data.length;
      }
      reset = 1;
      Fluttertoast.showToast(msg: "msg rec");
      resettimer = true;
    }
  }

  playByte() async {
    try {
      if (chunksave.length == 0 || saveLength == 0) return;

      Fluttertoast.showToast(msg: "msg len $saveLength");
      _bytes1 = Uint8List(saveLength);
      int offset = 0;
      for (final List<int> chunk in chunksave) {
        _bytes1.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      final path = await _localPath;
      final file = File('$path/temp.wav');
      var headerList = WavHeader.createWavHeader(saveLength);
      file.writeAsBytesSync(headerList, mode: FileMode.write);
      file.writeAsBytesSync(_bytes1, mode: FileMode.append);

      player.start(file.path);

      chunksave.clear();
      saveLength = 0;
    } catch (e) {}
  }

  _completeByte() async {
    try {
      if (chunks.length == 0 || contentLength == 0) return;
      //if ((DateTime.now().millisecondsSinceEpoch - power_btn_tick) < 1000) return;
      //SVProgressHUD.dismiss();
      Fluttertoast.showToast(msg: "msg len $contentLength");
      _bytes = Uint8List(contentLength);
      int offset = 0;
      for (final List<int> chunk in chunks) {
        _bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      final file = await _makeNewFile;
      var headerList = WavHeader.createWavHeader(contentLength);
      file.writeAsBytesSync(headerList, mode: FileMode.write);
      file.writeAsBytesSync(_bytes, mode: FileMode.append);

      print(await file.length());

      contentLength = 0;
      chunks.clear();
    } catch (e) {}
  }

  void _sendMessage(String text) async {
    text = text.trim();
    textEditingController.clear();

    if (text.length > 0) {
      try {
        connection.output.add(utf8.encode(text + "\r\n"));
        await connection.output.allSent;

        setState(() {
          messages.add(_Message(clientID, text));
        });

        Future.delayed(Duration(milliseconds: 333)).then((_) {
          listScrollController.animateTo(
              listScrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 333),
              curve: Curves.easeOut);
        });
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }

  Widget shotButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: RaisedButton(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.red)),
        onPressed: () {
          setState(() {
            _showRecordingDialog();
            recording = true;
            recordstate = 3;
          });
        },
        color: Colors.red,
        textColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            _recordState == RecordState.stopped ? "RECORD" : "STOP",
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }

  String _selectedPosition = '1';
  String _LorH = 'L';
  List<String> _position = ['1', '2'];
  List<String> _lung_Heart = ['L', 'H'];
  void _showRecordingDialog() {
    showSlideDialog(
        barrierDismissible: false,
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 300,
                  child: DropdownButton(
                    value: _LorH,
                    iconSize: 50,
                    isExpanded: false,
                    items: _lung_Heart.map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: new Text(val),
                      );
                    }).toList(),
                    onChanged: (String newvalue) {
                      setState(() {
                        _LorH = newvalue;
                      });
                    },
                  ),
                ),
                Container(
                  child: DropdownButton(
                    value: _selectedPosition,
                    iconSize: 50,
                    isExpanded: false,
                    items: _position.map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: new Text(val),
                      );
                    }).toList(),
                    onChanged: (String newvalue) {
                      setState(() {
                        _selectedPosition = newvalue;
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 50,
            ),
            Text(
              "Recording",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 100,
            ),
            Container(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                strokeWidth: 10,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            ),
            SizedBox(
              height: 100,
            ),
            RaisedButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.red),
              ),
              onPressed: () {
                // _sendMessage("STOP");
                //startsent = false;
                SVProgressHUD.showInfo(status: "Stopping...");
                Navigator.of(context).pop();
                setState(() {
                  recording = false;
                  recordstate = 4;
                });
              },
              color: Colors.red,
              textColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  "STOP",
                  style: TextStyle(fontSize: 24),
                ),
              ),
            )
          ],
        ));
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _makeNewFile async {
    final path = await _localPath;
    String newFileName =
        dateFormat.format(DateTime.now()) + _selectedPosition + _LorH;
    return File('$path/$newFileName.wav');
  }

  void _listofFiles() async {
    try {
      int index = 0;
      final path = await _localPath;
      var fileList = Directory(path).list();
      prevfiles.clear();
      index = 0;
      fileList.forEach((element) {
        if (element.path.contains("wav") && !(element.path.contains("temp"))) {
          prevfiles.insert(index, element);
          index++;

          print("PATH: ${element.path} Size: ${element.statSync().size}");
        }
      });

      setState(() {
        if (files != prevfiles) files = prevfiles;
      });
    } catch (e) {}
  }
}
