import 'dart:async';
import 'dart:developer';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:daily_checker/daily_checker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:grid_icons/grid_icons.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:mi_band/mi_band.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walker/daily_check.dart';
import 'package:walker/utils/db_helper.dart';
import 'package:walker/watch_selector.dart';
import 'package:walker/wheel_detector.dart';

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
  Icon actionButtonIcon1 = const Icon(
    Icons.play_circle,
    color: Colors.white,
  );
  Icon actionButtonIcon2 = const Icon(Icons.pause_circle, color: Colors.white);
  Text stateTitle1 = const Text("만보기 작동중지 상태");
  Text stateTitle2 = const Text("만보기 작동중");
  Text stateTitle3 = const Text("만보기 켜는중");
  int stepCounter = 0;
  int beforeStepCount = 0;
  int fullStepCount = 0;
  int comboCount = 0;
  String selectedMeDevice = "";
  bool useWatch = false;
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
  MiBand miBand = MiBand();
  String currentSoundTitle = "새소리";
  Duration currentSoundDuration = Duration(seconds: 0);
  bool _onOverlay = false;
  late List gyroscope;
  List<IconItem> iconButtons = [];

  late dynamic prefs;

  @override
  void initState() {
    super.initState();
    checkPermission();
    // 가장 최근 기록을 가져온다
    getLastLog();
    initIconButtons();
  }

  Future<void> checkPermission() async {
    if (!await Permission.activityRecognition.isGranted) {
      await Permission.activityRecognition.request();
    }
  }

  void initIconButtons() {
    iconButtons.add(IconItem(icon: Icons.calendar_month, text: "참잘했어요 도장확인",
        color1: Colors.black, color2: Colors.white, enabled: true, name: "check"));
    iconButtons.add(IconItem(icon: Icons.watch, text: "스마트와치 연결" + (useWatch ? "(사용중)" : "(미사용)"),
        color1: Colors.black, color2: Colors.white, enabled: !actionState, name: "watch"));
    iconButtons.add(IconItem(icon: Icons.speed, text: "캣휠 속도계(준비중)",
        color1: Colors.black, color2: Colors.white, enabled: false, name: "speed"));
    iconButtons.add(IconItem(icon: Icons.play_circle_outline, text: "새소리",
        color1: Colors.white, color2: Colors.black, enabled: true, name: "bird"));
    iconButtons.add(IconItem(icon: Icons.play_circle_outline, text: "쥐소리",
        color1: Colors.white, color2: Colors.black, enabled: true, name: "mice"));
    iconButtons.add(IconItem(icon: Icons.play_circle_outline, text: "호랑이소리",
        color1: Colors.white, color2: Colors.black, enabled: true, name: "tiger"));
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
    prefs = await SharedPreferences.getInstance();
    selectedMeDevice = prefs.getString("walker_selected_me_device") ?? "";
    useWatch = prefs.getBool("walker_use_watch") ?? false;
    if (useWatch) {
      if (selectedMeDevice.isNotEmpty) {
        // 기존에 연결했던 미밴드가 있으므로 바로 연결시도한다
        startMiBand();
      }
    } else {
      startPedometer();
    }
    //startMiBand();
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
          tempTimeValue = 0;
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
            if (stepCounter - beforeStepCount >= 10) {
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

  void showFailDialog(BuildContext context) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('연결실패'),
            content: Text("연결시도하는 기기가 미밴드4가 아니거나, 연결이 불가능한 상태입니다. 스마트폰에 내장된 만보기를 이용하겠습니다."),
            actions: <Widget>[
              TextButton(
                child: Text("확인"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        }
    );
  }

  Future<void> startMiBandWithDevice(BluetoothDevice device) async {
    print("startMiBandWithDevice");
    setState(() {
      _onOverlay = true;
    });
    try {
      await miBand.connect(device);
      await miBand.getServices();
      await miBand.musicNotify((msg) async {
        if (msg == "focusIn") {
          await setSoundByTitle(currentSoundTitle, 0);
          await miBand.sendSoundInfo(currentSoundTitle, currentSoundDuration);
        } else if (msg == "focusOut") {
          // 소리재생을 멈춘다
          if (player.state == PlayerState.playing) {
            player.stop();
          }
        } else if (msg == "play") {
          if (player.state == PlayerState.paused) {
            player.resume();
          } else {
            await playByTitle(currentSoundTitle);
          }
        } else if (msg == "pause") {
          if (player.state == PlayerState.playing) {
            player.pause();
          }
        } else if (msg == "next") {
          await setSoundByTitle(currentSoundTitle, 1);
          await miBand.sendSoundInfo(currentSoundTitle, currentSoundDuration);
        } else if (msg == "before") {
          await setSoundByTitle(currentSoundTitle, -1);
          await miBand.sendSoundInfo(currentSoundTitle, currentSoundDuration);
        }
      });
    } catch(e) {
      showFailDialog(context);
      setState(() {
        useWatch = false;
      });
      await prefs.setBool(
          "walker_use_watch",
          useWatch);
    } finally {
      setState(() {
        _onOverlay = false;
      });
      startPedometer();
    }
  }

  void startMiBand() {
    setState(() {
      _onOverlay = true;
    });
    miBand.takeDevice((hasResult) async {
      bool wantBlt = true;
      if (hasResult) {
        if (miBand.miDevice != null) {
          bool oneMore = true;
          while (oneMore) {
            print("\x1B[31mconnect device try\x1B[0m");
            try {
              await miBand.connect(miBand.miDevice!);
              oneMore = false;
            } catch (e) {
              print("\x1B[31mconnect device fail\x1B[0m");
              print(e.toString());
              setState(() {
                _onOverlay = false;
              });
              oneMore = await showOneMore(context);
              setState(() {
                _onOverlay = true;
              });
              wantBlt = oneMore;
            }
          }
          if (wantBlt) {
            await miBand.getServices();
            await miBand.musicNotify((msg) async {
              if (msg == "focusIn") {
                await setSoundByTitle(currentSoundTitle, 0);
                await miBand.sendSoundInfo(currentSoundTitle, currentSoundDuration);
              } else if (msg == "focusOut") {
                // 소리재생을 멈춘다
                if (player.state == PlayerState.playing) {
                  player.stop();
                }
              } else if (msg == "play") {
                if (player.state == PlayerState.paused) {
                  player.resume();
                } else {
                  await playByTitle(currentSoundTitle);
                }
              } else if (msg == "pause") {
                if (player.state == PlayerState.playing) {
                  player.pause();
                }
              } else if (msg == "next") {
                await setSoundByTitle(currentSoundTitle, 1);
                await miBand.sendSoundInfo(currentSoundTitle, currentSoundDuration);
              } else if (msg == "before") {
                await setSoundByTitle(currentSoundTitle, -1);
                await miBand.sendSoundInfo(currentSoundTitle, currentSoundDuration);
              }
            });
            startPedometer();
            return;
          }
        }
        setState(() {
          _onOverlay = false;
        });
        showFailDialog(context);
        setState(() {
          _onOverlay = true;
          useWatch = false;
        });
        await prefs.setBool(
            "walker_use_watch",
            useWatch);
        startPedometer();
      } else {
        print("has not miband result");
        setState(() {
          _onOverlay = false;
        });
      }
    }, selectedMeDevice);
  }

  Future<void> startPedometer() async {
    if (useWatch) {
      await miBand.getCurrentStep((step) async {
        if (useWatch) {
          onData(step);
        }
      });
    } else {
      stepCountStream = Pedometer.stepCountStream;
      stepCountStream.listen(onDataByPedometer).onError(onError);
    }
    setState(() {
      _onOverlay = false;
    });
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

  void onData(int steps) {
    print("Step Count: " + steps.toString());
    bool isPassDay = passDay();
    setState(() {
      if (!firstStepDone) {
        fullStepCount = steps;
        firstStepDone = true;
      }
      int diff = steps - fullStepCount;
      if (diff > 100) {
        diff = 10;
      }
      // 직전 시각과 현재 시각을 비교해서 날짜가 지났으면 초기화
      if (isPassDay) {
        fullStepCount = steps;
        diff = 0;
        stepCounter = 0;
        timeValue = 0;
        tempTimeValue = 0;
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
      fullStepCount = steps;
    });
    // 현재 시각을 알아내서 보행수를 저장한다
    if (actionState) {
      saveCurrentLog();
    }
  }

  void onDataByPedometer(StepCount event) {
    if (!useWatch) {
      onData(event.steps);
    }
  }

  void onError(err) {
    log("Step Error: $err");
  }

  void changeState() {
    setState(() {
      actionState = !actionState;
      iconButtons[1].enabled = !actionState;
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
    miBand?.disconnect();
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

  Future<void> setSoundByTitle(String title, int index) async {
    int currentIndex = btnTitles.indexOf(title) + index;
    if (currentIndex < 0) {
      currentIndex = btnTitles.length - 1;
    } else if (currentIndex >= btnTitles.length) {
      currentIndex = 0;
    }
    currentSoundTitle = btnTitles[currentIndex];
    if (currentIndex == 0) {
      await player.setSourceAsset("bird.mp3");
    } else if (currentIndex == 1) {
      await player.setSourceAsset("mice.mp3");
    } else if (currentIndex == 2) {
      await player.setSourceAsset("tiger.mp3");
    }
    currentSoundDuration = (await player.getDuration())!;
  }

  Future<void> playByTitle(String title) async {
    int currentIndex = btnTitles.indexOf(title);
    if (currentIndex < 0) {
      currentIndex = btnTitles.length - 1;
    } else if (currentIndex >= btnTitles.length) {
      currentIndex = 0;
    }
    currentSoundTitle = btnTitles[currentIndex];
    if (currentIndex == 0) {
      await PlayBird();
    } else if (currentIndex == 1) {
      await PlayMice();
    } else if (currentIndex == 2) {
      await PlayTiger();
    }
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

  Future<bool> showOneMore(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      // dialog is dismissible with a tap on the barrier
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('블루투스 장치 연결에 실패했습니다. 다시 시도하시겠습니까?'),
          content: Text('시도하지 않으면 스마트폰의 만보기를 사용합니다.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(primary: Colors.black),
              child: Text('예'),
              onPressed: () {
                setState(() {
                  Navigator.pop(context, true);
                });
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(primary: Colors.black),
              child: Text('아니오'),
              onPressed: () {
                setState(() {
                  Navigator.pop(context, false);
                });
              },
            ),
          ],
        );
      },
    ).then((val) {
      return val;
    });
  }

  Future<void> asyncInputDialog(BuildContext context) async {
    titleValue = appTitle;
    return showDialog(
      context: context,
      barrierDismissible: false,
      // dialog is dismissible with a tap on the barrier
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('수정할 타이틀을 입력하세요'),
          content: new Row(
            children: [
              new Expanded(
                  child: new TextField(
                controller: TextEditingController(text: titleValue),
                autofocus: true,
                decoration:
                    new InputDecoration(labelText: '타이틀', hintText: '냥이야 놀자'),
                onChanged: (value) {
                  setState(() {
                    titleValue = value;
                  });
                },
              ))
            ],
          ),
          actions: [
            ElevatedButton(
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
      resizeToAvoidBottomInset : false,
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Row(
          children: <Widget>[
            Text(appTitle, style: TextStyle(color: Colors.black, fontSize: 21)),
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
                color: Colors.black,
              ),
            )
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView( child: LoadingOverlay(child: Center(
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
            SizedBox(height: 20),
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
                child: GridIcons(3, 2.0, 8, 4, 16, 11, iconButtons, (index, name) async {
                  if (name == "check") {
                    // 참잘했어요로 가기
                    // 재생중이면 포즈
                    if (player.state == PlayerState.playing) {
                      player.pause();
                    }
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => DailyCheckPage(dbHelper))).then(
                        (object) async {
                          await getLastLog();
                        }
                    );
                  } else if (name == "bird") {
                    PlayBird();
                  } else if (name == "mice") {
                    PlayMice();
                  } else if (name == "tiger") {
                    PlayTiger();
                  } else if (name == "watch") {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                WatchSelector(
                                    selectedMeDevice, useWatch, miBand,
                                        (device) async {
                                      firstStepDone = false;
                                      await prefs.setString(
                                          "walker_selected_me_device",
                                          device.name);
                                      startMiBandWithDevice(device);
                                    }, (value) async {
                                  firstStepDone = false;
                                  await prefs.setBool(
                                      "walker_use_watch",
                                      value);
                                  useWatch = value;
                                  if (!value) {
                                    miBand.disconnect();
                                    await startPedometer();
                                  }
                                })));
                  } else if (name == "speed") {
                    final cameras = await availableCameras();
                    final firstCamera = cameras.first;
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                WheelDetector(firstCamera)));
                  }

                }),
            ),
          ],
        ),
        ),
        isLoading: _onOverlay,
      )),
      floatingActionButton: Visibility(
        visible: firstStepDone,
        child: FloatingActionButton(
          onPressed: changeState,
          tooltip: '',
          child: actionState ? actionButtonIcon2 : actionButtonIcon1,
          backgroundColor: Colors.black,
        ), // This trailing comma makes a
      ), // uto-formatting nicer for build methods.
    );
  }
}
