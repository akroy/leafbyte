package com.thebluefolderproject.leafbyte

import android.net.Uri
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import androidx.lifecycle.ViewModelProviders
import androidx.navigation.findNavController
import org.opencv.android.OpenCVLoader
import android.content.ContentResolver
import androidx.navigation.NavOptions


class LeafByteActivity : AppCompatActivity(),
        MainMenuFragment.OnFragmentInteractionListener, BackgroundRemovalFragment.OnFragmentInteractionListener,
        ScaleIdentificationFragment.OnFragmentInteractionListener, ResultsFragment.OnFragmentInteractionListener, TutorialFragment.OnFragmentInteractionListener {
    override fun goHome() {
        findNavController(R.id.nav_host_fragment).navigate(R.id.mainMenuFragment)
    }

    override fun goToSettings() {
        findNavController(R.id.nav_host_fragment).navigate(R.id.settingsFragment)
    }

    override fun startTutorial() {
        findNavController(R.id.nav_host_fragment).navigate(R.id.tutorialFragment)
    }

    lateinit var model: WorkflowViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_leaf_byte)

        if (!OpenCVLoader.initDebug()) {
            throw RuntimeException("Failed to initialize OpenCV")
        }

        model = ViewModelProviders.of(this).get(WorkflowViewModel::class.java)
    }

    override fun onImageSelection(imageUri: Uri) {
        // TODO: hide and show properly
        supportActionBar!!.show()
        model.uri = imageUri
        findNavController(R.id.nav_host_fragment).navigate(R.id.backgroundRemovalFragment)
    }

    override fun doneBackgroundRemoval() {
        findNavController(R.id.nav_host_fragment).navigate(R.id.scaleIdentificationFragment)
    }

    override fun doneScaleIdentification() {
        findNavController(R.id.nav_host_fragment).navigate(R.id.resultsFragment)
    }

    override fun doneResults() {
        findNavController(R.id.nav_host_fragment).navigate(R.id.backgroundRemovalFragment, null, NavOptions.Builder().setPopUpTo(R.id.mainMenuFragment, false).build())
    }

    override fun doneTutorial() {
        // TODO: resize here and elsewhere
        model.uri = resourceToUri(R.drawable.example_leaf)
        findNavController(R.id.nav_host_fragment).navigate(R.id.backgroundRemovalFragment)
    }

     fun resourceToUri(resID:Int):Uri {
        return Uri.parse(
            ContentResolver.SCHEME_ANDROID_RESOURCE + "://" +
            getResources().getResourcePackageName(resID) + '/'.toString() +
            getResources().getResourceTypeName(resID) + '/'.toString() +
            getResources().getResourceEntryName(resID)
        )
    }
}
