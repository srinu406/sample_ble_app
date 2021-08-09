import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_svprogresshud/flutter_svprogresshud.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slide_popup_dialog/slide_popup_dialog.dart';
import 'dart:io';

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

  //bool isConnected = true;
  bool isDisconnecting = false;

  List<List<int>> chunks = <List<int>>[];
  int contentLength = 0;
  Uint8List _bytes;

  Timer _timer;
  RecordState _recordState = RecordState.stopped;
  DateFormat dateFormat = DateFormat("yyyy-MM-dd_HH_mm_ss");

  int recordingstop = 0;
  List<FileSystemEntity> files = List<FileSystemEntity>();
  String selectedFilePath;
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
  void initState() {
    super.initState();

    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (resettimer == false) {
        _completeByte();
      }
      resettimer = false;
    });

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
                    shotButton(),
                    Expanded(
                      child: ListView(
                        children: files
                            .map((_file) => FileEntityListTile(
                                  filePath: _file.path,
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

  int power_btn_tick = 0, reset = 1;
  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;

    if (data != null && data.length > 0 && (recording == true)) {
      chunks.add(data);
      contentLength += data.length;
      reset = 1;
      Fluttertoast.showToast(msg: "msg rec");
      resettimer = true;
    }
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
          if (recording == false) {
            //  _sendMessage("START");
            recording = true;
            _showRecordingDialog();
          } else {
            recording = false;
            _sendMessage("STOP");
          }
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

  void _showRecordingDialog() {
    showSlideDialog(
        barrierDismissible: false,
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
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
                _sendMessage("STOP");
                //     SVProgressHUD.showInfo("Stopping...");
                Navigator.of(context).pop();
                setState(() {
                  recording = false;
                  recordingstop = 1;
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
    String newFileName = dateFormat.format(DateTime.now());
    return File('$path/$newFileName.wav');
  }

  void _listofFiles() async {
    try {
      int index = 0;
      final path = await _localPath;
      var fileList = Directory(path).list();
      files.clear();
      index = 0;
      fileList.forEach((element) {
        if (element.path.contains("wav")) {
          files.insert(index, element);
          index++;

          print("PATH: ${element.path} Size: ${element.statSync().size}");
        }
      });

      setState(() {});
    } catch (e) {}
  }
}
