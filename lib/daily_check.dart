import 'dart:convert';
import 'dart:io';

import 'package:daily_checker/daily_checker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:walker/utils/db_helper.dart';

class DailyCheckPage extends StatefulWidget {
  final DbHelper dbHelper;

  const DailyCheckPage(this.dbHelper);

  @override
  _DailyCheckPageState createState() => _DailyCheckPageState();
}

class _DailyCheckPageState extends State<DailyCheckPage> {
  late Future<List<CheckItem>> items;
  Future<List<CheckItem>> getDatas() async {
    int lastDay = DateUtils.getDaysInMonth(year, month);
    List<LogItem> logs = await widget.dbHelper.getLogItems(year, month);
    List<CheckItem> checkList = <CheckItem>[];
    List<int> walksByDay = List<int>.filled(lastDay, 0);
    List<int> secondsByDay = List<int>.filled(lastDay, 0);
    List<int> comboByDay = List<int>.filled(lastDay, 0);
    for (int i = 0; i < lastDay; i++) {
      checkList.add(CheckItem(
        year: year,
        month: month,
        day: i + 1,
        hasIt: false,
        isSuccess: false,
        isSoSo: false,
      ));
    }
    for (LogItem item in logs) {
      walksByDay[item.day - 1] += item.walks;
      secondsByDay[item.day - 1] += item.seconds;
      comboByDay[item.day - 1] += item.combo;
    }
    for (LogItem item in logs) {
      checkList[item.day - 1].hasIt = true;
      checkList[item.day - 1].isSuccess = walksByDay[item.day - 1] >= 1500 &&
          secondsByDay[item.day - 1] >= 1800 &&
          comboByDay[item.day - 1] >= 50;
      checkList[item.day - 1].isSoSo = walksByDay[item.day - 1] >= 1000 &&
          secondsByDay[item.day - 1] >= 1200 &&
          comboByDay[item.day - 1] >= 30;
      //checkList[item.day-1].logs.walks = item.walks;
      //checkList[item.day-1].logs.seconds = item.seconds;
    }

    return checkList;
  }

  int year = 0, month = 0, day = 0;
  bool _onOverlay = false;

  GoMonth(int diff) {
    DateTime now = new DateTime.now();
    if (diff == 0) {
      setState(() {
        year = now.year;
        month = now.month;
        items = getDatas();
      });
    } else if (diff == 1) {
      if (month < 12) {
        setState(() {
          month++;
          items = getDatas();
        });
      } else {
        setState(() {
          year++;
          month = 1;
          items = getDatas();
        });
      }
    } else if (diff == -1) {
      if (month > 1) {
        setState(() {
          month--;
          items = getDatas();
        });
      } else {
        setState(() {
          year--;
          month = 12;
          items = getDatas();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    DateTime now = new DateTime.now();
    year = now.year;
    month = now.month;
    day = now.day;
    loadDatas();
  }

  Future<void> loadDatas() async {
    items = getDatas();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> loadLog() async {
    setState(() {
      _onOverlay = true;
    });
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('기록 가져오기'),
            content: Text("기록을 가져오면 기존의 기록은 모두 지워집니다. 그래도 하시겠습니까?"),
            actions: <Widget>[
              TextButton(
                child: Text("예"),
                onPressed: () async {
                  final params = OpenFileDialogParams(
                    dialogType: OpenFileDialogType.document,
                    sourceType: SourceType.photoLibrary,
                  );
                  final String? filePath = await FlutterFileDialog.pickFile(params: params);
                  if (filePath != null) {
                    final String jsonString = await File(filePath!)
                        .readAsString();
                    Map<String, dynamic> jsonRead = jsonDecode(jsonString);
                    LogItem? lastLog = LogItem.fromJson(jsonRead['last_log']);
                    await widget.dbHelper.setLastLog(lastLog);
                    await widget.dbHelper.setTitle(jsonRead['title']);
                    await widget.dbHelper.clear();
                    for (int i = 0; i < jsonRead['total_logs'].length; i++) {
                      await widget.dbHelper.insert(
                          (LogItem.fromJson(jsonRead['total_logs'][i])));
                    }
                    setState(() {
                      items = getDatas();
                    });
                  } else {
                    Fluttertoast.showToast(
                        msg: "선택된 파일이 없습니다",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.CENTER,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.green,
                        textColor: Colors.white,
                        fontSize: 16.0
                    );
                  }
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("아니오"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        }
    );
    setState(() {
      _onOverlay = false;
    });
  }

  Future<void> backupLog() async {
    setState(() {
      _onOverlay = true;
    });

    List<LogItem> totalLogs = await widget.dbHelper.getTotalLogs();
    LogItem? lastLog = await widget.dbHelper.getLastLog();
    var jsonTotalLogs = [];
    for(LogItem item in totalLogs) {
      jsonTotalLogs.add(item.toJson());
    }

    String? appTitle = await widget.dbHelper.getAppInfo();

    var jsonOutput = {
      'total_logs': jsonTotalLogs,
      'last_log': lastLog?.toJson(),
      'title': appTitle,
    };

    String jsonString = jsonEncode(jsonOutput);

    Directory _extDir = await getApplicationDocumentsDirectory();
    final String filename = _extDir.path +
        "/walker_logs.json";
    await File(filename).writeAsString(jsonString);
    final params =
      SaveFileDialogParams(sourceFilePath: filename);
    await FlutterFileDialog.saveFile(params: params);
    setState(() {
      _onOverlay = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.black),
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title:
            Text("월별결과", style: TextStyle(color: Colors.black, fontSize: 21)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: LoadingOverlay(child: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
                padding: const EdgeInsets.all(30.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    OutlinedButton(
                        onPressed: () {
                          GoMonth(-1);
                        },
                        child: Icon(
                          Icons.arrow_left,
                          color: Colors.black87,
                          size: 24.0,
                        )),
                    OutlinedButton(
                        onPressed: () {
                          GoMonth(0);
                        },
                        child: Text(
                          "$year-$month",
                          style: TextStyle(color: Colors.black87),
                        )),
                    OutlinedButton(
                        onPressed: () {
                          GoMonth(1);
                        },
                        child: Icon(
                          Icons.arrow_right,
                          color: Colors.black87,
                          size: 24.0,
                        ))
                  ],
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
              child: FutureBuilder(
                  future: items,
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    if (!snapshot.hasData) {
                      return CircularProgressIndicator();
                    } else if (snapshot.hasError) {
                      return CircularProgressIndicator();
                    } else {
                      return DailyChecker(year, month, snapshot.data);
                    }
                  }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
              child: ElevatedButton.icon(
                onPressed: backupLog,
                style: ElevatedButton.styleFrom(primary: Colors.black),
                icon: Icon(
                  Icons.file_download,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text("기록 내보내기", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
              child: ElevatedButton.icon(
                onPressed: loadLog,
                style: ElevatedButton.styleFrom(primary: Colors.black),
                icon: Icon(
                  Icons.file_upload,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text("기록 가져오기", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            )
          ],
        ),
      )
      ),isLoading: _onOverlay,),
    );
  }
}
