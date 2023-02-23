import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:kmeans/kmeans.dart';
import 'package:image/image.dart' as img;

class myKmeans {
  double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  Future<Uint8List> convertBytes2(List<List<int>> temp) async {
    Uint8List ret = Uint8List(temp.length * 3);
    for (int i = 0; i < temp.length; i++) {
      int Y = temp[i][0];
      int U = temp[i][1];
      int V = temp[i][2];
      double r = 1.164 * (Y - 16) + 1.596 * (V - 128);
      double g = 1.164 * (Y - 16) - 0.813 * (V - 128) - 0.391 * (U - 128);
      double b = 1.164 * (Y-16) + 2.018 * (U-128);

      ret.add(clamp(r, 0.0, 256.0).toInt());
      ret.add(clamp(g, 0.0, 256.0).toInt());
      ret.add(clamp(b, 0.0, 256.0).toInt());
    }
    return ret;
  }

  Future<List<List<double>>> convertBytes(List<int> temp) async {
    img.Image? img2 = img.decodeImage(temp);

    List<List<double>> ret = [];
    if (img2 != null) {
      for (int y = 0; y < img2.height; y++) {
        for (int x = 0; x < img2.width; x++) {
          int abgr = img2.getPixel(x, y);
          int r = abgr % 256;
          int b = (abgr / 256).toInt() % 256;
          int g = (abgr / (256 * 256)).toInt() % 256;
          ret.add([r.toDouble(), g.toDouble(), b.toDouble()]);
        }
      }
    }
    return ret;
  }

  Future<List<List<double>>> convert(XFile image) async {
    List<int> temp = await image.readAsBytes();
    return convertBytes(temp);
  }

  Future<List<Color>> compute(XFile image) async {
    List<List<double>> datas = await convert(image);
    var kmeans = KMeans(datas);
    var k = 2;
    var clusters = kmeans.bestFit(maxK: k, minK: k);
    List<Color> ret = [];
    for (int i = 0; i < k; i++) {
      ret.add(Color.fromRGBO(clusters.means[i][0].toInt(),
          clusters.means[i][1].toInt(), clusters.means[i][2].toInt(), 1.0));
    }
    return ret;
  }


}
