package com.thebluefolderproject.leafbyte

import android.app.AlertDialog
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.*
import android.widget.Button
import android.widget.ImageView
import android.widget.SeekBar
import androidx.fragment.app.Fragment
import androidx.lifecycle.ViewModelProviders
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import java.util.*
import kotlin.math.roundToInt


// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [BackgroundRemovalFragment.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [BackgroundRemovalFragment.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class BackgroundRemovalFragment : Fragment() {
    // TODO: Rename and change types of parameters
    private var param1: String? = null
    private var param2: String? = null
    private var listener: OnFragmentInteractionListener? = null
    var model: WorkflowViewModel? = null

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        // Inflate the layout for this fragment
        val view = inflater.inflate(R.layout.fragment_background_removal, container, false)

        activity!!.let {
            model = ViewModelProviders.of(activity!!).get(WorkflowViewModel::class.java)
        }

        val uri = model!!.uri!!
        val bitmap = BitmapFactory.decodeStream(activity!!.contentResolver.openInputStream(uri), null, null)
        val imageView = view.findViewById<ImageView>(R.id.imageView)
        val histogramView = view.findViewById<ImageView>(R.id.histogram)
        view.findViewById<Button>(R.id.backgroundRemovalNext).setOnClickListener {
            listener!!.doneBackgroundRemoval()
        }

        val otsu = otsu(bitmap!!)

        val thresholdedImage = threshold(bitmap!!, otsu)
        imageView.setImageBitmap(thresholdedImage)

        val seekBar = view.findViewById<SeekBar>(R.id.seekBar)
        seekBar.progress = (otsu * 100 / 256).roundToInt()
        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onStartTrackingTouch(p0: SeekBar?) {

            }

            override fun onStopTrackingTouch(p0: SeekBar?) {

            }

            override fun onProgressChanged(p0: SeekBar?, p1: Int, p2: Boolean) {
                val bitmap = threshold(bitmap!!, (p1 * 256 / 100).toDouble())
                imageView.setImageBitmap(bitmap)
                model!!.thresholdedImage = bitmap
            }

        })

        val histogram = calculateHistogram(bitmap, histogramView)

        debug("labeling " + bitmap.width + " " + bitmap.height)
        val foo = labelConnectedComponents(LayeredIndexableImage(thresholdedImage.width, thresholdedImage.height, thresholdedImage), listOf())
        debug(foo.labelToSize)

        setHasOptionsMenu(true)

        return view
    }

    override fun onCreateOptionsMenu(menu: Menu, inflater: MenuInflater) {
        val homeButton = menu.add("Home")
        homeButton.setShowAsAction(MenuItem.SHOW_AS_ACTION_WITH_TEXT or MenuItem.SHOW_AS_ACTION_IF_ROOM)
        homeButton.setIcon(R.drawable.home)
        homeButton.setOnMenuItemClickListener { listener!!.goHome(); true }

        val helpButton = menu.add("Help")
        helpButton.setShowAsAction(MenuItem.SHOW_AS_ACTION_WITH_TEXT or MenuItem.SHOW_AS_ACTION_IF_ROOM)
        helpButton.setIcon(R.drawable.galleryicon)
        helpButton.setOnMenuItemClickListener {
            AlertDialog.Builder(activity)
                    .setMessage("First, we remove any background to leave just the leaf and scale. LeafByte looks at the brightness of different parts of the image to try to do this automatically, but you can move the slider to tweak.\n" +
                            "\n" +
                            "(Above the slider you'll see a histogram of brightnesses in the image; when you move the slider, you're actually choosing what brightnesses count as background vs foreground)")
                    .show()
            true
        }

        super.onCreateOptionsMenu(menu, inflater)
    }


    override fun onAttach(context: Context) {
        super.onAttach(context)
        if (context is OnFragmentInteractionListener) {
            listener = context
        } else {
            throw RuntimeException(context.toString() + " must implement OnFragmentInteractionListener")
        }
    }

    override fun onDetach() {
        super.onDetach()
        listener = null
    }

    /**
     * This interface must be implemented by activities that contain this
     * fragment to allow an interaction in this fragment to be communicated
     * to the activity and potentially other fragments contained in that
     * activity.
     *
     *
     * See the Android Training lesson [Communicating with Other Fragments]
     * (http://developer.android.com/training/basics/fragments/communicating.html)
     * for more information.
     */
    interface OnFragmentInteractionListener {
        // TODO: Update argument type and name
        fun goHome()
        fun doneBackgroundRemoval()
    }

    fun otsu(bitmap: Bitmap): Double {
        // first convert bitmap into OpenCV mat object
        val imageMat = Mat(
            bitmap.height, bitmap.width,
            CvType.CV_8U, Scalar(4.0)
        )
        val myBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true)
        Utils.bitmapToMat(myBitmap, imageMat)

        // now convert to gray
        val grayMat = Mat(
            bitmap.height, bitmap.width,
            CvType.CV_8U, Scalar(1.0)
        )
        Imgproc.cvtColor(imageMat, grayMat, Imgproc.COLOR_RGB2GRAY, 1)

        // get the thresholded image
        val thresholdMat = Mat(
            bitmap.height, bitmap.width,
            CvType.CV_8U, Scalar(1.0)
        )
        return Imgproc.threshold(grayMat, thresholdMat, -1.0, 255.0, Imgproc.THRESH_OTSU)
    }

    fun threshold(bitmap: Bitmap, threshold: Double): Bitmap {
        // first convert bitmap into OpenCV mat object
        val imageMat = Mat(
            bitmap.height, bitmap.width,
            CvType.CV_8U, Scalar(4.0)
        )
        val myBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true)
        Utils.bitmapToMat(myBitmap, imageMat)

        // now convert to gray
        val grayMat = Mat(
            bitmap.height, bitmap.width,
            CvType.CV_8U, Scalar(1.0)
        )
        Imgproc.cvtColor(imageMat, grayMat, Imgproc.COLOR_RGB2GRAY, 1)

        // get the thresholded image
        val thresholdMat = Mat(
            bitmap.height, bitmap.width,
            CvType.CV_8U, Scalar(1.0)
        )
        Imgproc.threshold(grayMat, thresholdMat, threshold.toDouble(), 255.0, Imgproc.THRESH_BINARY_INV)

        val maskedImageMat = Mat(
            bitmap.height, bitmap.width,
            CvType.CV_8U, Scalar(4.0)
        )
        imageMat.copyTo(maskedImageMat, thresholdMat)

        // convert back to bitmap for displaying
        val resultBitmap = Bitmap.createBitmap(
            bitmap.width, bitmap.height,
            Bitmap.Config.ARGB_8888
        )
        thresholdMat.convertTo(thresholdMat, CvType.CV_8UC1)
        Utils.matToBitmap(maskedImageMat, resultBitmap)

        return resultBitmap
    }

    fun calculateHistogram(bitmap: Bitmap, histogramView: ImageView) : List<Double> {
        // first convert bitmap into OpenCV mat object
        val imageMat = Mat(
            bitmap.height, bitmap.width,
            CvType.CV_8U, Scalar(4.0)
        )
        val myBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true)
        Utils.bitmapToMat(myBitmap, imageMat)

        // now convert to gray
        val grayMat = Mat(
            bitmap.height, bitmap.width,
            CvType.CV_8U, Scalar(1.0)
        )
        Imgproc.cvtColor(imageMat, grayMat, Imgproc.COLOR_RGB2GRAY, 1)

        val histogram = Mat()


        Imgproc.calcHist(Arrays.asList(grayMat), MatOfInt(0), Mat(), histogram, MatOfInt(256),   MatOfFloat(0f, 256f))
        val histogramList = (0..255).asIterable().map { bin -> histogram.get(bin, 0)[0] }
        val maxValue = (histogramList.max()!! + 1).toInt()

        // black
        val color = Scalar (0.0, 0.0, 0.0, 255.0)
        val graphHeight = 100
        val factor = graphHeight.toDouble() / maxValue
        // create transparent background
        val graphMat = Mat(graphHeight, 256, CvType.CV_8UC4, Scalar(0.0, 0.0, 0.0, 0.0))

        for(i in 0..255) {
            val bPoint1 = Point(i.toDouble(), graphHeight.toDouble());
            val bPoint2 = Point(i.toDouble(), graphHeight - histogram.get(i, 0)[0] * factor);
            Imgproc.line(graphMat, bPoint1, bPoint2, color, 1, 8, 0);
        }


        val graphBitmap = Bitmap.createBitmap(graphMat.cols(), graphMat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(graphMat, graphBitmap)

        // show histogram
        histogramView.setImageBitmap(graphBitmap)



        return histogramList
    }

    companion object {
        /**
         * Use this factory method to create a new instance of
         * this fragment using the provided parameters.
         *
         * @param param1 Parameter 1.
         * @param param2 Parameter 2.
         * @return A new instance of fragment BackgroundRemovalFragment.
         */
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
            BackgroundRemovalFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_PARAM1, param1)
                    putString(ARG_PARAM2, param2)
                }
            }
    }
}
