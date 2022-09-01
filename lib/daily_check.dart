import 'package:daily_checker/daily_checker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:walker/utils/db_helper.dart';

class DailyCheckPage extends StatefulWidget {
  final DbHelper dbHelper;

  const DailyCheckPage(this.dbHelper);

  @override
  _DailyCheckPageState createState() => _DailyCheckPageState();
}

class _DailyCheckPageState extends State<DailyCheckPage> {
  Future<List<CheckItem>> getDatas() async {
    int lastDay = DateUtils.getDaysInMonth(year, month);
    List<LogItem> logs = await widget.dbHelper.getLogItems(year, month);
    List<CheckItem> checkList = <CheckItem>[];
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
      checkList[item.day - 1].hasIt = true;
      checkList[item.day - 1].isSuccess =
          item.walks >= 1500 && item.seconds >= 1800 && item.combo >= 50;
      checkList[item.day - 1].isSoSo =
          item.walks >= 1000 && item.seconds >= 1200 && item.combo >= 30;
      //checkList[item.day-1].logs.walks = item.walks;
      //checkList[item.day-1].logs.seconds = item.seconds;
    }

    return checkList;
  }

  int year = 0, month = 0, day = 0;

  GoMonth(int diff) {
    DateTime now = new DateTime.now();
    if (diff == 0) {
      setState(() {
        year = now.year;
        month = now.month;
      });
    } else if (diff == 1) {
      if (month < 12) {
        setState(() {
          month++;
        });
      } else {
        setState(() {
          year++;
          month = 1;
        });
      }
    } else if (diff == -1) {
      if (month > 1) {
        setState(() {
          month--;
        });
      } else {
        setState(() {
          year--;
          month = 12;
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
  }

  @override
  void dispose() {
    super.dispose();
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
      body: Center(
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
                      future: getDatas(),
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
              ],
            ),
      )),
    );
  }
}
