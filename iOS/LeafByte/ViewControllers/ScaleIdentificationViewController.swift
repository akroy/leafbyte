//
//  ScaleIdentificationViewController.swift
//  LeafByte
//
//  Created by Adam Campbell on 1/10/18.
//  Copyright © 2018 The Blue Folder Project. All rights reserved.
//

import CoreGraphics
import UIKit

class ScaleIdentificationViewController: UIViewController, UIScrollViewDelegate {
    // MARK: - Fields
    
    // These are passed from the previous view.
    var sourceType: UIImagePickerControllerSourceType!
    var image: UIImage!
    
    // The current mode can be scrolling or identifying.
    var inScrollingMode = true
    
    // MARK: - Outlets
    
    @IBOutlet weak var gestureRecognizingView: UIScrollView!
    @IBOutlet weak var scrollableView: UIView!
    @IBOutlet weak var baseImageView: UIImageView!
    @IBOutlet weak var scaleMarkingView: UIImageView!
    
    @IBOutlet weak var modeToggleButton: UIButton!
    @IBOutlet weak var clearScaleButton: UIButton!
    
    @IBOutlet weak var resultsText: UILabel!
    
    // MARK: - Actions
    
    @IBAction func toggleScrollingMode(crolling: Any) {
        setScrollingMode(!inScrollingMode)
    }
    @IBAction func clearScale(_ sender: Any) {
        
    }
    
    // MARK: - UIViewController overrides

    override func viewDidLoad(){
        super.viewDidLoad()

        setupGestureRecognizingView(gestureRecognizingView: gestureRecognizingView, self: self)

        baseImageView.contentMode = .scaleAspectFit
        baseImageView.image = image

        setScrollingMode(true)
    }
    
    // MARK: - UIScrollViewDelegate overrides

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollableView
    }

    // MARK: - UIResponder overrides

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // No drawing in scrolling mode.
        if inScrollingMode {
            return
        }

        let candidatePoint = (touches.first?.location(in: baseImageView))!
    }
    
    // MARK: - Helpers
    
    func setScrollingMode(_ inScrollingMode: Bool) {
        self.inScrollingMode = inScrollingMode

        gestureRecognizingView.isUserInteractionEnabled = inScrollingMode

        if inScrollingMode {
            modeToggleButton.setTitle("Switch to drawing", for: .normal)
        } else {
            modeToggleButton.setTitle("Switch to scrolling", for: .normal)
        }
    }
}
