package reddol.com.walker

import android.content.Context
import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.Method
import org.opencv.android.OpenCVLoader;
import org.opencv.core.*
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import org.opencv.imgproc.Imgproc.LINE_8
import android.os.FileUtils
import android.util.Log
import org.opencv.android.Utils
import org.opencv.core.Point
import org.opencv.core.Rect
import org.opencv.core.MatOfPoint
import org.opencv.core.MatOfPoint2f
import org.opencv.objdetect.CascadeClassifier
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.smk.voice_background/cvedge";

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        OpenCVLoader.initDebug();
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler{call, result ->
            var filepath: String? = call.argument("filepath")
            var frameCount: Int? = call.argument("frame_count") as Int?
            if (call.method == "findEdge" && frameCount != null) {
                Log.d("FilePath", filepath.toString())
                Log.d("FrameCount", frameCount.toString())

                var kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(4.0, 4.0))

                for (i in 1 until frameCount) {
                    val src1: Mat = Imgcodecs.imread(filepath + "/frames-" + i + ".jpg")
                    val src2: Mat = Imgcodecs.imread(filepath + "/frames-" + (i+1) + ".jpg")

                    val gray1 = Mat()
                    val gray2 = Mat()
                    Imgproc.cvtColor(src1, gray1, Imgproc.COLOR_BGR2GRAY)
                    Imgproc.cvtColor(src2, gray2, Imgproc.COLOR_BGR2GRAY)

                    val diff = Mat()
                    Core.absdiff(gray2, gray1, diff)

                    val tres = Mat()
                    Imgproc.threshold(diff, tres, 30.0, 255.0, Imgproc.THRESH_BINARY)

                    val dires = Mat()
                    Imgproc.dilate(tres, dires, kernel)

                    val contours = ArrayList<MatOfPoint>()
                    val hierarchy = Mat()
                    Imgproc.findContours(dires, contours, hierarchy, Imgproc.RETR_TREE, Imgproc.CHAIN_APPROX_NONE)

                    // 특정 높이 이상의 경우에만 디텍션 해야 하는 경우
                    for (contour in contours) {
                        val p2f = MatOfPoint2f(*contour.toArray())
                        val rect:RotatedRect = Imgproc.minAreaRect(p2f)
                        val vts = arrayOfNulls<Point>(4)
                        rect.points(vts)
                        for(k in 0 until 4) {
                            Imgproc.line(src1, vts[k], vts[(k+1)%4], Scalar(81.0, 190.0, 0.0), 4)
                        }
                    }
                    Imgcodecs.imwrite(filepath + "/frames-" + i + ".jpg", src1)
                }
                /*
                val srcMat: Mat = Imgcodecs.imread(filepath)
                Log.d("srcMat Size", srcMat.size().width.toString())
                //var mat: Mat = Imgcodecs.imdecode(srcMat, Imgcodecs.IMREAD_UNCHANGED)

                val graySrc = Mat()
                Imgproc.cvtColor(srcMat, graySrc, Imgproc.COLOR_BGR2GRAY)
                val gausSrc = Mat()
                Imgproc.GaussianBlur(graySrc, gausSrc, Size(5.0, 5.0), 0.0)
                val diSrc = Mat()
                val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(3.0, 3.0))
                Imgproc.dilate(gausSrc, diSrc, kernel)
                val morSrc = Mat()
                val kernel2 = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(2.0,2.0))
                Imgproc.morphologyEx(diSrc, morSrc, Imgproc.MORPH_CLOSE, kernel2)
                val rects = MatOfRect()
                val assetManager = resources.assets
                val inputStream = assetManager.open("car.xml")
                val cdir = getDir("cascade", Context.MODE_PRIVATE)
                val mfile = File(cdir, "car.xml")
                mfile.writeBytes(inputStream.readBytes())
                inputStream.close()
                val car = CascadeClassifier(mfile.getAbsolutePath())
                car.detectMultiScale(morSrc, rects, 1.1, 1)
                var ret: String = ""
                val pts:Array<Rect> = rects.toArray()
                for (j in 0 until pts.size) {
                    ret = ret + pts[j].x.toString() + "," +
                            pts[j].y.toString() + "," + pts[j].width.toString() + "," + pts[j].height.toString() + "\n"
                    Log.d("Contour", pts[j].x.toString() +
                            "," + pts[j].y.toString() + "," + pts[j].width.toString() + "," + pts[j].height.toString())
                }*/
                result.success(true)
            }
        }
    }
}
