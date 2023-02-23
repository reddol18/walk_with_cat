import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:mi_band/mi_band.dart';

class WatchSelector extends StatefulWidget {
  final String selectedDevice;
  final bool useWatch;
  final MiBand miBand;
  final Function connectedDevice;
  final Function useWatchChange;

  const WatchSelector(this.selectedDevice, this.useWatch, this.miBand,
      this.connectedDevice, this.useWatchChange);

  @override
  _WatchSelectorState createState() => _WatchSelectorState();
}

class _WatchSelectorState extends State<WatchSelector> {
  bool useWatch = false;
  int connectedDeviceCount = 0;
  int scannedDeviceCount = 0;
  bool _onOverlay = false;

  @override
  void initState() {
    super.initState();
    useWatch = widget.useWatch;
  }

  void showFailDialog(BuildContext context) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('연결실패'),
            content: Text("기기가 미밴드4가 아니거나, 연결이 불가능한 상태입니다."),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: BackButton(color: Colors.black),
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text("스마트와치 연결",
              style: TextStyle(color: Colors.black, fontSize: 21)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
            child: LoadingOverlay(
          child: Center(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(30.0, 5, 30, 0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SwitchListTile(
                        value: useWatch,
                        onChanged: (v) {
                          setState(() {
                            useWatch = v;
                          });
                          widget.useWatchChange(v);
                        },
                        title: Text("스마트와치 사용")),
                  Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 5),
                      child: Text("연결된 디바이스(${connectedDeviceCount})",
                          style: TextStyle(
                              color: useWatch ? Colors.black : Colors.black26)),
                    ),
                  Container(
                    height: MediaQuery.of(context).size.height * 0.3,
                    child: ConnectedDeviceList(
                        widget.selectedDevice, widget.miBand, useWatch,
                        (count) {
                      setState(() {
                        connectedDeviceCount = count;
                      });
                    }, (device, ok) {
                      if (ok) {
                        widget.connectedDevice(device);
                      } else {
                        showFailDialog(context);
                      }
                    }, (value) {
                      setState(() {
                        _onOverlay = value;
                      });
                    }),
                  ),
                  Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.black12,
                    ),
                  Padding(
                      padding: EdgeInsets.fromLTRB(20, 5, 20, 5),
                      child: Text("탐색된 디바이스(${scannedDeviceCount})",
                          style: TextStyle(
                              color: useWatch ? Colors.black : Colors.black26)),
                    ),
                  Container(
                    height: MediaQuery.of(context).size.height * 0.3,
                    child: ScannableDeviceList(
                        widget.selectedDevice, widget.miBand, useWatch,
                        (count) {
                      setState(() {
                        scannedDeviceCount = count;
                      });
                    }, (device, ok) {
                      if (ok) {
                        widget.connectedDevice(device);
                      } else {
                        showFailDialog(context);
                      }
                    }, (value) {
                      setState(() {
                        _onOverlay = value;
                      });
                    }),
                  )
                ]),
          )),
          isLoading: _onOverlay,
        )));
  }
}
