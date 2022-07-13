import 'dart:async';
import 'dart:developer';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:daily_checker/daily_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pedometer/pedometer.dart';
import 'package:walker/daily_check.dart';
import 'package:walker/utils/db_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp],
  ); // To turn off landscape mode
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: '호박아 놀자~'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Icon actionButtonIcon1 = const Icon(Icons.play_circle);
  Icon actionButtonIcon2 = const Icon(Icons.pause_circle);
  Text stateTitle1 = const Text("만보기 작동중지 상태");
  Text stateTitle2 = const Text("만보기 작동중");
  Text stateTitle3 = const Text("만보기 켜는중");
  int stepCounter = 0;
  int beforeStepCount = 0;
  int fullStepCount = 0;
  int comboCount = 0;
  bool actionState = false;
  bool firstStepDone = false;
  bool hasLastLog = false;
  late Timer timer;
  int timeValue = 0;
  int tempTimeValue = 0;
  late Stream<StepCount> stepCountStream;
  final DbHelper dbHelper = DbHelper();
  late LogItem lastLog;
  AudioPlayer player = AudioPlayer();
  List<String> btnTitles = ["새소리", "쥐소리", "호랑이소리"];
  String appTitle = "호박아 놀자~";
  String titleValue = "";

  @override
  void initState() {
    super.initState();
    // 가장 최근 기록을 가져온다
    getLastLog();
  }

  Future getLastLog() async {
    await dbHelper.openDb();
    var tempLog = await dbHelper.getLastLog();
    if (tempLog != null) {
      lastLog = tempLog;
      hasLastLog = true;
      if (!passDay()) {
        stepCounter = lastLog.walks;
        beforeStepCount = stepCounter;
        timeValue = lastLog.seconds;
        comboCount = lastLog.combo;
      }
    }
    var info = await dbHelper.getAppInfo();
    if (info != null) {
      appTitle = info;
    } else {
      await dbHelper.setTitle(appTitle);
    }
    startPedometer();
  }

  Future saveCurrentLog() async {
    DateTime now = new DateTime.now();
    LogItem? log = await dbHelper.getLogItem(now.year, now.month, now.day);
    LogItem newLog = LogItem(
        id: 0,
        walks: stepCounter,
        seconds: timeValue,
        year: now.year,
        month: now.month,
        day: now.day,
        combo: comboCount,
    );
    print(
        "Save Log: ${newLog.walks}, ${newLog.seconds}, ${newLog.combo}, ${newLog.year}, ${newLog.month}, ${newLog.day}");
    if (log != null) {
      newLog.id = log.id;
      await dbHelper.update(newLog);
    } else {
      await dbHelper.add(newLog);
    }
    newLog.id = 1;
    await dbHelper.setLastLog(newLog);
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      bool isPassDay = passDay();
      setState(() {
        if (isPassDay) {
          stepCounter = 0;
          timeValue = 0;
          comboCount = 0;
          beforeStepCount = 0;
          DateTime now = new DateTime.now();
          lastLog.year = now.year;
          lastLog.month = now.month;
          lastLog.day = now.day;
        } else {
          timeValue++;
          tempTimeValue++;
          if (tempTimeValue == 10) {
            tempTimeValue = 0;
            if (stepCounter - beforeStepCount >= 20) {
              comboCount++;
            }
            beforeStepCount = stepCounter;
          }
        }
      });
      saveCurrentLog();
    });
  }

  void pauseTimer() {
    timer?.cancel();
  }

  void startPedometer() {
    stepCountStream = Pedometer.stepCountStream;
    stepCountStream.listen(onData).onError(onError);
  }

  bool passDay() {
    if (hasLastLog == false) {
      return true;
    }
    DateTime now = new DateTime.now();
    return lastLog.year != now.year ||
        lastLog.month != now.month ||
        lastLog.day != now.day;
  }

  void onData(StepCount event) {
    bool isPassDay = passDay();
    setState(() {
      if (!firstStepDone) {
        fullStepCount = event.steps;
        firstStepDone = true;
      }
      int diff = event.steps - fullStepCount;
      // 직전 시각과 현재 시각을 비교해서 날짜가 지났으면 초기화
      if (isPassDay) {
        stepCounter = 0;
        timeValue = 0;
        comboCount = 0;
        beforeStepCount = 0;
        DateTime now = new DateTime.now();
        lastLog.year = now.year;
        lastLog.month = now.month;
        lastLog.day = now.day;
      }
      if (actionState) {
        stepCounter += diff;
      }
      fullStepCount = event.steps;
    });
    // 현재 시각을 알아내서 보행수를 저장한다
    if (actionState) {
      saveCurrentLog();
    }
  }

  void onError(err) {
    log("Step Error: $err");
  }

  void changeState() {
    setState(() {
      actionState = !actionState;
      if (actionState) {
        startTimer();
      } else {
        pauseTimer();
      }
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
    });
  }

  @override
  void dispose() {
    saveCurrentLog();
    dbHelper.close();
    timer?.cancel();
    super.dispose();
  }

  Widget timerDisplay() {
    String val1 = (timeValue ~/ 60).toString();
    String val2 = (timeValue % 60).toString().padLeft(2, '0');
    String text = "$val1:$val2";
    return Text(
      text,
      style: Theme.of(context).textTheme.headline4,
    );
  }

  Future PlayBird() async {
    await player.play(AssetSource("bird.mp3"));
  }

  Future PlayMice() async {
    await player.play(AssetSource("mice.mp3"));
  }

  Future PlayTiger() async {
    await player.play(AssetSource("tiger.mp3"));
  }

  Future<void> asyncInputDialog(BuildContext context) async {
    titleValue = appTitle;
    return showDialog(
      context: context,
      barrierDismissible: false, // dialog is dismissible with a tap on the barrier
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('수정할 타이틀을 입력하세요'),
          content: new Row(
            children: [
              new Expanded(
                  child: new TextField(
                    controller: TextEditingController(text: titleValue),
                    autofocus: true,
                    decoration: new InputDecoration(
                        labelText: '타이틀', hintText: '냥이야 놀자'),
                    onChanged: (value) {
                      setState(() {
                        titleValue = value;
                      });
                    },
                  ))
            ],
          ),
          actions: [
            FlatButton(
              child: Text('확인'),
              onPressed: () {
                setState(() {
                  Navigator.pop(context);
                });
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Row(
          children: <Widget>[
            Text(appTitle),
            IconButton(
                onPressed: () async {
                  await asyncInputDialog(context);
                  setState(() {
                    appTitle = titleValue;
                  });
                  await dbHelper.setTitle(appTitle);
                },
                icon: Icon(
                  Icons.edit,
                  size: 16,
                ),)
          ],
        ),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            firstStepDone
                ? actionState
                    ? stateTitle2
                    : stateTitle1
                : stateTitle3,
            Text(
              '$stepCounter',
              style: Theme.of(context).textTheme.headline4,
            ),
            timerDisplay(),
            Text(
              '$comboCount 콤보',
              style: Theme.of(context).textTheme.headline4,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                    onPressed: () {
                      // 재생중이면 포즈
                      if (player.state == PlayerState.playing) {
                        player.pause();
                      }
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => DailyCheckPage(dbHelper)));
                    },
                    icon: Icon(
                      Icons.calendar_month,
                      size: 16,
                    ),
                    label: Text("참잘했어요 도장확인")),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return
                    Padding(
                        padding: const EdgeInsets.all(4.0),
                        child:
                        ElevatedButton.icon(
                            onPressed: () {
                              if (index == 0) {
                                PlayBird();
                              } else if (index == 1) {
                                PlayMice();
                              } else if (index == 2) {
                                PlayTiger();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              primary: Colors.white,
                              onPrimary: Colors.blue,
                            ),
                            icon: Icon(
                              Icons.play_circle_outline,
                              size: 16,
                            ),
                            label: Text(btnTitles[index]))
                    );
                }),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Visibility(
        visible: firstStepDone,
        child: FloatingActionButton(
          onPressed: changeState,
          tooltip: '',
          child: actionState ? actionButtonIcon2 : actionButtonIcon1,
        ), // This trailing comma makes a
      ), // uto-formatting nicer for build methods.
    );
  }
}
