import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:Bluetooth_stethoscope/home_modal.dart';
import 'package:Bluetooth_stethoscope/horizontal_list.dart';
import 'package:Bluetooth_stethoscope/vertical_list.dart';
import 'package:path_provider/path_provider.dart';

class SlidableScreen extends StatefulWidget {
  @override
  _SlidableScreenState createState() => _SlidableScreenState();
}

class _SlidableScreenState extends State<SlidableScreen> {
  List<FileSystemEntity> files = List<FileSystemEntity>();
  SlidableController _slidableController;
  final List<HomeModal> items = List.generate(
    11,
    (i) => HomeModal(
      i,
      _position(i),
      _subtitle(i),
      _avatarColor(i),
    ),
  );

  static Color _avatarColor(int index) {
    switch (index % 4) {
      case 0:
        return Colors.cyan[200];
      case 1:
        return Colors.teal;
      case 2:
        return Colors.red;
      case 3:
        return Colors.orange;
      default:
        return null;
    }
  }

  static String _subtitle(int index) {
    switch (index % 4) {
      case 0:
        return 'SlidableScrollActionPane';
      case 1:
        return 'SlidableDrawerActionPane';
      case 2:
        return 'SlidableStrechActionPane';
      case 3:
        return 'SlidableBehindActionPane';
      default:
        return null;
    }
  }

  static String _position(int index) {
    switch (index % 2) {
      case 0:
        return 'Lung';
      case 1:
        return 'Heart';
      default:
        return null;
    }
  }

  @override
  void initState() {
    _slidableController = SlidableController(
      onSlideAnimationChanged: slideAnimationChanged,
      onSlideIsOpenChanged: slideIsOpenChanged,
    );
    super.initState();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  void _listofFiles() async {
    try {
      int index = 0;
      final path = await _localPath;
      var fileList = Directory(path).list();
      files.clear();
      index = 0;
      fileList.forEach((element) {
        if (element.path.contains("wav") && !(element.path.contains("temp"))) {
          files.insert(index, element);
          index++;

          print("PATH: ${element.path} Size: ${element.statSync().size}");
        }
      });

      setState(() {});
    } catch (e) {}
  }

  Animation<double> _rotationAnimation;
  Color _fabColor = Colors.redAccent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white24,
      appBar: AppBar(
        title: Text('History'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            child: Center(
              child: OrientationBuilder(
                builder: (context, orientation) =>
                    _buildList(context, Axis.vertical),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, Axis direction) {
    return ListView.builder(
      scrollDirection: direction,
      itemBuilder: (context, index) {
        final Axis slidableDirection =
            direction == Axis.horizontal ? Axis.vertical : Axis.horizontal;
        var item = items[index];
        //if (item.index < 5) {
        return _slidableWithLists(context, index, slidableDirection);
        //} else {
        //return _slidableWithDelegates(context, index, slidableDirection);
        //}
      },
      itemCount: items.length,
    );
  }

  Widget _slidableWithLists(BuildContext context, int index, Axis direction) {
    final HomeModal item = items[index];
    return Slidable(
      key: Key(item.titles),
      controller: _slidableController,
      direction: direction,
      dismissal: SlidableDismissal(
        child: SlidableDrawerDismissal(),
        onDismissed: (actionType) {
          _showSnackBar(
              context,
              actionType == SlideActionType.primary
                  ? 'Dismiss Archive'
                  : 'Dimiss Delete');
          setState(() {
            items.removeAt(index);
          });
        },
      ),
      actionPane: _actionPane(item.index),
      actionExtentRatio: 0.20,
      child: direction == Axis.horizontal
          ? VerticalList(items[index])
          : HorizontalList(items[index]),
      actions: <Widget>[
        IconSlideAction(
          caption: 'Share',
          color: Colors.indigo,
          icon: Icons.share,
          onTap: () => _showSnackBar(context, 'Share'),
        ),
      ],
      secondaryActions: <Widget>[
        IconSlideAction(
          caption: 'Delete',
          color: Colors.red,
          icon: Icons.delete,
          onTap: () => _showSnackBar(context, 'Delete'),
        ),
      ],
    );
  }

  static Widget _actionPane(int index) {
    switch (index % 4) {
      case 0:
        return SlidableScrollActionPane();
      case 1:
        return SlidableDrawerActionPane();
      case 2:
        return SlidableStrechActionPane();
      case 3:
        return SlidableBehindActionPane();

      default:
        return null;
    }
  }

  void _showSnackBar(BuildContext context, String text) {
    Scaffold.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void slideAnimationChanged(Animation<double> slideAnimation) {
    setState(() {
      _rotationAnimation = slideAnimation;
    });
  }

  void slideIsOpenChanged(bool isOpen) {
    setState(() {
      _fabColor = isOpen ? Colors.orange : Colors.redAccent;
    });
  }
}
