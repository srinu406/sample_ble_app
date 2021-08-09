import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_svprogresshud/flutter_svprogresshud.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:path/path.dart' as Path;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:io';

import 'file_entity_list_tile.dart';
import 'wav_header.dart';
import 'package:async/async.dart';
import 'package:fileaudioplayer/fileaudioplayer.dart';
import 'package:flutter/material.dart';

class RecordingPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _RecordPage();
}

class _RecordPage extends State<RecordingPage> {
  AudioCache audioCache = AudioCache();
  AudioPlayer advancedPlayer = AudioPlayer();

  File _image;
  String _uploadedFileURL;
  DateFormat dateFormat = DateFormat("yyyy-MM-dd_HH_mm_ss");
  int recordingstop = 0;
  List<FileSystemEntity> files = List<FileSystemEntity>();

  List<FileSystemEntity> prevfiles = List<FileSystemEntity>();
  String selectedFilePath;
  FileAudioPlayer player = FileAudioPlayer();
  bool recording = false;

  int rightswipe = 0;
  int leftswipe = 0;
  @override
  void initState() {
    super.initState();

    Timer.periodic(Duration(seconds: 1), (timer) {
      _listofFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    double heigth = MediaQuery.of(context).size.height;
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: Text('History')),
        body: Column(
          children: [
            Column(
              children: <Widget>[
                Container(
                  child: Row(
                    children: [
                      SizedBox(
                        height: 5,
                      )
                    ],
                  ),
                ),
                Container(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            child: SizedBox(
                              width: 3,
                            ),
                          ),
                          Container(
                            color: Colors.blue,
                            height: heigth / 30,
                            width: width / 4.11,
                            child: Center(
                              child: Text(
                                "Time",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Container(
                            child: SizedBox(
                              width: 3,
                            ),
                          ),
                          Container(
                            color: Colors.blue,
                            width: width / 4.11,
                            height: heigth / 30,
                            child: Center(
                              child: Text(
                                "H/L",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Container(
                            child: SizedBox(
                              width: 3,
                            ),
                          ),
                          Container(
                            color: Colors.blue,
                            width: width / 4.11,
                            height: heigth / 30,
                            child: Center(
                              child: Text(
                                "Position",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Container(
                            child: SizedBox(
                              width: 3,
                            ),
                          ),
                          Container(
                            color: Colors.blue,
                            width: width / 4.11,
                            height: heigth / 30,
                            child: Center(
                              child: Text(
                                "Duration",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                Container(
                  width: width * 0.8,
                  child: Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: files
                          .map(
                            (_file) => GestureDetector(
                              onPanUpdate: (details) {
                                // Swiping in right direction.
                                if (details.delta.dx > 0) {
                                  setState(() {
                                    leftswipe += 1;
                                    rightswipe = 0;
                                  });
                                }

                                // Swiping in left direction.
                                if (details.delta.dx < 0) {
                                  setState(() {
                                    leftswipe = 0;
                                    rightswipe += 1;
                                  });
                                }
                              },
                              child: ListTile(
                                title: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                        child: Text(
                                      FileStat.statSync(_file.path)
                                          .changed
                                          .toString()
                                          .substring(
                                              0,
                                              FileStat.statSync(_file.path)
                                                  .changed
                                                  .toString()
                                                  .lastIndexOf("000")),
                                      style: TextStyle(
                                          color: Colors.black, fontSize: 12),
                                      textAlign: TextAlign.start,
                                    )),
                                    Container(
                                      child: Icon(Icons.delete),
                                    ),
                                    Container(
                                        width: width * 0.2,
                                        child: Icon(Icons.delete)),
                                    InkWell(
                                      onTap: () {},
                                      child: Container(
                                        child: Text("0 sec",
                                            style:
                                                TextStyle(color: Colors.black)),
                                      ),
                                    ),
                                  ],
                                ),
                                onLongPress: () async {
                                  print("onLongPress item");
                                  if (await File(_file.path).exists()) {
                                    File(_file.path).deleteSync();

                                    files.remove(_file);

                                    setState(() {});
                                  }
                                },
                                onTap: () async {},
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                /*
                Container(
                    color: Colors.blue,
                    height: 50,
                    width: width,
                    child: Row(
                      children: [
                        leftswipe >= 2
                            ? Container(
                                width: width * 0.1,
                                child: InkWell(
                                  child: Icon(Icons.delete),
                                  onTap: () {},
                                ),
                              )
                            : Container(),
                        Container(
                          width: width * 0.9,
                          child: SizedBox(
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                // Swiping in right direction.
                                if (details.delta.dx > 0) {
                                  Fluttertoast.showToast(
                                      msg: "left swipe" + leftswipe.toString());
                                  setState(() {
                                    leftswipe += 1;
                                    rightswipe = 0;
                                  });
                                }

                                // Swiping in left direction.
                                if (details.delta.dx < 0) {
                                  setState(() {
                                    leftswipe = 0;
                                    rightswipe += 1;
                                  });

                                  Fluttertoast.showToast(
                                      msg: "righy swipe    " +
                                          details.delta.dx.toString());
                                }
                              },
                              child: Text("Hello", textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                        rightswipe >= 2
                            ? Container(
                                width: width * 0.1,
                                child: InkWell(
                                  child: Icon(Icons.share),
                                  onTap: () {},
                                ),
                              )
                            : Container(),
                      ],
                    )),*/
              ],
            ),
          ],
        ));
  }

  Future<int> _getDuration(path) async {
    final uri = await audioCache.load(path);
    await advancedPlayer.setUrl(uri.toString());
    return Future.delayed(
      const Duration(seconds: 2),
      () => advancedPlayer.getDuration(),
    );
  }

  void _listofFiles() async {
    try {
      int index = 0;
      final path = await _localPath;
      index = 0;
      files.clear();
      var fileList = Directory(path)
          .list(recursive: true)
          .listen((FileSystemEntity element) {
        files.insert(index, element);
      });

      index = 0;

      /*setState(() {
        fileList.forEach((element) {
          if (element.path.contains("wav") &&
              !(element.path.contains("temp"))) {
            files.insert(index, element);
            index++;
          }
        });

        setState(() {});
      });*/
    } catch (e) {}
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
}
