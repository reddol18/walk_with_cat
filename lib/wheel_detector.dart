import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video2images/video2images.dart';
import 'package:video2images/video2images_method_channel.dart';
import 'package:walker/utils/myKmeans.dart';

class SceneData {
  late int msec;
  late List<List<int>> buffer;

  SceneData(this.msec, this.buffer);
}

class WheelDetector extends StatefulWidget {
  final CameraDescription camera;

  const WheelDetector(this.camera);

  @override
  _WheelDetectorState createState() => _WheelDetectorState();
}

class _WheelDetectorState extends State<WheelDetector> {
  bool _onOverlay = false;
  int wheel_radius = 50;
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool cameraOn = false;
  bool markerOn = false;
  myKmeans km = myKmeans();
  late Timer _timer;
  late Color color1, color2;
  late DateTime startTime;
  late List<SceneData> sceneDatas;
  late Video2images v2i;
  late DetectInfo di;
  late DetectInfo wdi;
  bool hasFailedDetect = false;

  @override
  void initState() {
    super.initState();
    v2i = new Video2images();
    color1 = Color.fromRGBO(255, 255, 255, 1.0);
    color2 = Color.fromRGBO(255, 255, 255, 1.0);
    initCamera();
  }

  @override
  void dispose() {
    if (cameraOn) {
      _timer.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> initCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.low,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  void showSpeedDialog(BuildContext context, double speed) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('캣휠 속도'),
            content: Text("${speed} m/s"),
            actions: <Widget>[
              TextButton(
                child: Text("확인"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  Future<void> checkMarker() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      wdi = v2i.getMarkerDetectInfo(image.path);
      di = await v2i.getDetectInfoFromImage(image.path, true);
      di.center_x = di.center_x * (wdi.image_width / di.image_width);
      di.center_y = di.center_y * (wdi.image_height / di.image_height);
      di.width = di.width * (wdi.image_width / di.image_width);
      di.height = di.height * (wdi.image_height / di.image_height);
      print(
          "WImage Info: ${wdi.width} ${wdi.height} ${wdi.center_x} ${wdi.center_y} ${wdi.image_width} ${wdi.image_height}");
      print(
          "Image Info: ${di.width} ${di.height} ${di.center_x} ${di.center_y} ${di.image_width} ${di.image_height}");
      final double sdiff = wdi.size - di.size;
      final double wdiff = wdi.center_x - di.center_x;
      final double hdiff = wdi.center_y - di.center_y;

      if (sdiff.abs() <= 200.0 && wdiff.abs() <= 20.0 && hdiff.abs() <= 35.0) {
        setState(() {
          hasFailedDetect = false;
          markerOn = true;
        });
      } else {
        Fluttertoast.showToast(
            msg: "마커확인실패, 다시 시도해주세요",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0
        );
        setState(() {
          hasFailedDetect = true;
          markerOn = false;
        });
      }
      if (!mounted) return;
    } catch (e) {
      print(e);
    }
  }

  List<Widget> drawLayouts() {
    List<Widget> ret = [
      Flexible(
        flex: 1,
        child: SpinBox(
          min: 1,
          max: 200,
          value: 50,
          decoration: InputDecoration(
            labelText: '캣휠 지름을 입력하세요',
            suffix: const Text('cm'),
          ),
          onChanged: (value) {
            wheel_radius = value.toInt();
          },
        ),
      ),
      Flexible(
          flex: 9,
          child: FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                // If the Future is complete, display the preview.
                return Stack(fit: StackFit.expand, children: [
                  CameraPreview(_controller),
                  markerOn
                      ? Container(
                    alignment: FractionalOffset(
                        di.center_x / di.image_width,
                        di.center_y / di.image_height),
                    child: FractionallySizedBox(
                        widthFactor: di.width / di.image_width,
                        heightFactor: di.height / di.image_height,
                        child: Container(
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(0, 0, 0, 0),
                              border: Border.all(
                                width: 3,
                                color: Colors.redAccent,
                                style: BorderStyle.solid,
                              ),
                            ))),
                        )
                      : hasFailedDetect
                          ? Container(
                              alignment: FractionalOffset(
                                  di.center_x / di.image_width,
                                  di.center_y / di.image_height),
                              child: FractionallySizedBox(
                                  widthFactor: di.width / di.image_width,
                                  heightFactor: di.height / di.image_height,
                                  child: Container(
                                      decoration: BoxDecoration(
                                    color: const Color.fromARGB(0, 0, 0, 0),
                                    border: Border.all(
                                      width: 3,
                                      color: Colors.green,
                                      style: BorderStyle.solid,
                                    ),
                                  ))),
                            )
                          : Align(
                              alignment: Alignment.center,
                              child: FractionallySizedBox(
                                widthFactor: 0.083,
                                heightFactor: 0.1875,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(0, 0, 0, 0),
                                    border: Border.all(
                                      width: 3,
                                      color: Colors.blue,
                                      style: BorderStyle.solid,
                                    ),
                                  ))),
                            ),
                ]);
              } else {
                // Otherwise, display a loading indicator.
                return const Center(child: CircularProgressIndicator());
              }
            },
          )),
      Flexible(
        flex: 1,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () async {
                // 마커확인함
                if (hasFailedDetect) {
                  setState(() {
                    hasFailedDetect = false;
                  });
                } else {
                  await checkMarker();
                }
              },
              style: ElevatedButton.styleFrom(primary: Colors.black),
              icon: Icon(
                Icons.qr_code,
                size: 16,
              ),
              label: Text(hasFailedDetect ? "마커 다시확인" : "마커 확인"),
            ),
          ),
        ),
      )
    ];
    if (markerOn) {
      ret.add(Flexible(
        flex: 1,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () async {
                final Directory extDir =
                    await getApplicationDocumentsDirectory();
                final String path = extDir.path;
                final int frameRate = 60;
                String filename = await v2i.recordVideo(_controller, path);
                int frameCount =
                    await v2i.extractFrames(path, filename, frameRate);
                double speed = await v2i.getSpeed(
                    wheel_radius.toDouble(), frameRate, frameCount, path, di);
                setState(() {
                  _onOverlay = false;
                });
                showSpeedDialog(context, speed);
                /*sceneDatas = [];
                    startTime = DateTime.now();
                    await _controller.startImageStream((image) async {
                      DateTime nowTime = DateTime.now();
                      // 계속 저장합니다.
                      sceneDatas.add(new SceneData(
                          nowTime.difference(startTime).inMilliseconds,
                          [image.planes[0].bytes, image.planes[1].bytes, image.planes[2].bytes]));
                    });
                    setState(() {
                      cameraOn = true;
                    });
                    _timer = new Timer.periodic(const Duration(milliseconds: 5000),
                            (timer) async {
                      if (cameraOn) {
                        await _controller.stopImageStream();
                        setState(() {
                          cameraOn = false;
                          _onOverlay = true;
                        });
                        await takeVelocity();
                      }
                    });*/
              },
              style: ElevatedButton.styleFrom(primary: Colors.black),
              icon: Icon(
                Icons.speed,
                size: 16,
              ),
              label: Text("속도 측정"),
            ),
          ),
        ),
      ));
    }
    return ret;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: BackButton(color: Colors.black),
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text("캣휠 속도측정하기",
              style: TextStyle(color: Colors.black, fontSize: 21)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: LoadingOverlay(
          child: Center(
              child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: drawLayouts()),
          )),
          isLoading: _onOverlay,
        ));
  }
}
