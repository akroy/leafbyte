//
//  ThresholdingViewController.swift
//  LeafByte
//
//  Created by Adam Campbell on 12/23/17.
//  Copyright © 2017 The Blue Folder Project. All rights reserved.
//

import Accelerate
import UIKit

class ThresholdingViewController: UIViewController, UIScrollViewDelegate {
    // MARK: - Fields
    
    // Both of these are passed from the main menu view.
    var sourceType: UIImagePickerControllerSourceType!
    var image: UIImage!
    
    let filter = ThresholdingFilter()
    
    // MARK: - Outlets
    
    @IBOutlet weak var gestureRecognizingView: UIScrollView!
    @IBOutlet weak var scrollableView: UIView!
    @IBOutlet weak var baseImageView: UIImageView!
    @IBOutlet weak var scaleMarkingView: UIImageView!
    @IBOutlet weak var thresholdSlider: UISlider!
    
    // MARK: - Actions
    
    // This is called from the back button in the navigation bar.
    @IBAction func backFromThreshold(_ sender: Any) {
        self.performSegue(withIdentifier: "backToMainMenu", sender: self)
    }
    
    @IBAction func sliderMoved(_ sender: UISlider) {
        setThreshold(1 - sender.value)
    }
    
    // MARK: - UIViewController overrides
    
    override func viewDidLoad(){
        super.viewDidLoad()
        
        setupGestureRecognizingView(gestureRecognizingView: gestureRecognizingView, self: self)
        
        filter.setInputImage(image!)
        
        baseImageView.contentMode = .scaleAspectFit
        scaleMarkingView.contentMode = .scaleAspectFit
        
        // Guess a good threshold to start at; the user can adjust with the slider later.
        let suggestedThreshold = getSuggestedThreshold(image: uiToCgImage(image!))
        thresholdSlider.value = 1 - suggestedThreshold
        setThreshold(suggestedThreshold)
    }

    // This is called before transitioning from this view to another view.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // If the segue is thresholdingComplete, we're transitioning forward in the main flow, and we need to pass our data forward.
        if segue.identifier == "thresholdingComplete"
        {
            guard let destination = segue.destination as? ScaleIdentificationViewController else {
                fatalError("Expected the next view to be the scale identification view but is \(segue.destination)")
            }
            
            destination.sourceType = sourceType
            destination.image = baseImageView.image
            
            setBackButton(self: self)
        }
    }
    
    // MARK: - UIScrollViewDelegate overrides
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollableView
    }
    
    // MARK: - Helpers
    
    private func setThreshold(_ threshold: Float) {
        filter.threshold = threshold
        baseImageView.image = ciToUiImage(filter.outputImage)
    }
}
