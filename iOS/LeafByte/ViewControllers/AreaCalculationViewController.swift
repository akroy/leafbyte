//
//  AreaCalculationViewController.swift
//  LeafByte
//
//  Created by Adam Campbell on 12/24/17.
//  Copyright © 2017 The Blue Folder Project. All rights reserved.
//

import CoreGraphics
import UIKit

class AreaCalculationViewController: UIViewController, UIScrollViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - Fields
    
    // These are passed from the thresholding view.
    var sourceType: UIImagePickerControllerSourceType!
    var image: UIImage!
    var scaleMarkPixelLength: Int?
    
    // Tracks whether the last gesture (including any ongoing one) was a swipe.
    var swiped = false
    // The last touched point, to enable drawing lines while swiping.
    var lastTouchedPoint = CGPoint.zero
    // Projection from the drawing space back to the base image, so we can check if the drawing is in bounds.
    var userDrawingToBaseImage: Projection!
    var baseImageRect: CGRect!
    
    // The current mode can be scrolling or drawing.
    var inScrollingMode = true
    
    let imagePicker = UIImagePickerController()
    // This is set while choosing the next image and is passed to the next thresholding view.
    var selectedImage: UIImage?
    
    // MARK: - Outlets
    
    @IBOutlet weak var gestureRecognizingView: UIScrollView!
    @IBOutlet weak var scrollableView: UIView!
    @IBOutlet weak var baseImageView: UIImageView!
    @IBOutlet weak var userDrawingView: UIImageView!
    @IBOutlet weak var leafHolesView: UIImageView!
    
    @IBOutlet weak var modeToggleButton: UIButton!
    @IBOutlet weak var calculateButton: UIButton!
    @IBOutlet weak var resultsText: UILabel!
    
    // MARK: - Actions
    
    @IBAction func toggleScrollingMode(_ sender: Any) {
        setScrollingMode(!inScrollingMode)
    }
    
    @IBAction func calculate(_ sender: Any) {
        // Don't allow recalculation until there's a possibility of a different result.
        calculateButton.isEnabled = false
        
        resultsText.text = "Loading"
        // The label won't update until this action returns, so put this calculation on the queue, and it'll be executed right after this function ends.
        DispatchQueue.main.async {
            self.findSizes()
        }
    }
    
    @IBAction func nextImage(_ sender: Any) {
        imagePicker.sourceType = sourceType
        
        if sourceType == .camera {
            requestCameraAccess(self: self, onSuccess: { self.present(self.imagePicker, animated: true, completion: nil) })
        } else {
            present(imagePicker, animated: true, completion: nil)
        }
    }
    
    // MARK: - UIViewController overrides
    
    override func viewDidLoad(){
        super.viewDidLoad()
        
        setupGestureRecognizingView(gestureRecognizingView: gestureRecognizingView, self: self)
        setupImagePicker(imagePicker: imagePicker, self: self)
        
        baseImageView.contentMode = .scaleAspectFit
        baseImageView.image = image
        
        userDrawingToBaseImage = Projection(invertProjection: Projection(fromImageInView: baseImageView.image!, toView: baseImageView))
        baseImageRect = CGRect(origin: CGPoint.zero, size: baseImageView.image!.size)
        
        setScrollingMode(true)
        
        // TODO: is there a less stupid way to initialize the image?? maybe won't need
        UIGraphicsBeginImageContext(userDrawingView.frame.size)
        userDrawingView.image?.draw(in: CGRect(x: 0, y: 0, width: userDrawingView.frame.size.width, height: userDrawingView.frame.size.height))
        userDrawingView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    // This is called before transitioning from this view to another view.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // If the segue is imageChosen, we're transitioning forward in the main flow, and we need to pass the selection forward.
        if segue.identifier == "imageChosen"
        {
            guard let destination = segue.destination as? ThresholdingViewController else {
                fatalError("Expected the next view to be the thresholding view but is \(segue.destination)")
            }
            
            destination.sourceType = sourceType
            destination.image = selectedImage
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // See finishWithImagePicker for why animations may be disabled; make sure they're enabled before leaving.
        UIView.setAnimationsEnabled(true)
    }
    
    // MARK: - UIScrollViewDelegate overrides
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollableView
    }
    
    // MARK: - UIResponder overrides
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        swiped = false
        lastTouchedPoint = (touches.first?.location(in: userDrawingView))!
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        swiped = true
        let currentPoint = (touches.first?.location(in: userDrawingView))!
        drawLine(fromPoint: lastTouchedPoint, toPoint: currentPoint)
        
        lastTouchedPoint = currentPoint
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !swiped {
            // If it's not a swipe, no line has been drawn.
            drawLine(fromPoint: lastTouchedPoint, toPoint: lastTouchedPoint)
        }
    }
    
    // MARK: - UIImagePickerControllerDelegate overrides
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        finishWithImagePicker(self: self, info: info, selectImage: { selectedImage = $0 })
    }
    
    // If the image picker is canceled, dismiss it.
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Helpers
    
    func drawLine(fromPoint: CGPoint, toPoint: CGPoint) {
        // Do not draw in scrolling mode.
        if (inScrollingMode) {
            return
        }
        
        // Allow recalculation now that there's a possibility of a different result.
        calculateButton.isEnabled = true
        
        let drawingManager = DrawingManager(withCanvasSize: userDrawingView.frame.size)
        
        // TODO: make sure this makes sense later
        // Drawing with width two means that the line will always be connected by 4 connectivity, simplifying the connected components code.
        drawingManager.getContext().setLineWidth(2)
        
        
        // Only draw if the points are within the base image.
        // Otherwise, since connected components and flood filling are calculated within the base image, other operations will seem broken.
        let fromPointInBaseImage = userDrawingToBaseImage.project(point: fromPoint)
        let toPointInBaseImage = userDrawingToBaseImage.project(point: toPoint)
        if baseImageRect.contains(fromPointInBaseImage) && baseImageRect.contains(toPointInBaseImage) {
            drawingManager.drawLine(from: fromPoint, to: toPoint)
        }
        
        drawingManager.finish(imageView: userDrawingView, addToPreviousImage: true)
    }
    
    func setScrollingMode(_ inScrollingMode: Bool) {
        self.inScrollingMode = inScrollingMode
        
        gestureRecognizingView.isUserInteractionEnabled = inScrollingMode
        
        if (inScrollingMode) {
            modeToggleButton.setTitle("Switch to drawing", for: .normal)
        } else {
            modeToggleButton.setTitle("Switch to scrolling", for: .normal)
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    func findSizes() {
        let baseImage = IndexableImage(uiToCgImage(image!))
        let combinedImage = BooleanIndexableImage(width: baseImage.width, height: baseImage.height)
        combinedImage.addImage(baseImage, withPixelToBoolConversion: { $0.isNonWhite() })
        
        let userDrawingProjection = Projection(fromImageInView: baseImageView.image!, toView: baseImageView)
        let userDrawing = IndexableImage(uiToCgImage(userDrawingView.image!), withProjection: userDrawingProjection)
        combinedImage.addImage(userDrawing, withPixelToBoolConversion: { $0.isVisible() })
        
        let width = combinedImage.width
        let height = combinedImage.height
        
        var labelToStartingPoint = [Int: (Int, Int)]()
        var emptyLabelToNeighboringOccupiedLabel = [Int: Int]()
        var labelledImage = Array(repeating: Array(repeating: 0, count: width), count: height)
        var nextOccupiedLabel = 1
        var nextEmptyLabel = -2
        
        var labelToSize = [Int: Int]()
        
        let equivalenceClasses = UnionFind()
        equivalenceClasses.createSubsetWith(-1) //outside of leaf
        labelToSize[-1] = 0
        
        for y in 0...height - 1 {
            for x in 0...width - 1 {
                let occupied = combinedImage.getPixel(x: x, y: y)
                
                // using 4-connectvity for speed
                let westGroup = x > 0 && occupied == combinedImage.getPixel(x: x - 1, y: y)
                    ? labelledImage[y][x - 1]
                    : nil
                let northGroup = y > 0 && occupied == combinedImage.getPixel(x: x, y: y - 1)
                    ? labelledImage[y - 1][x]
                    : nil
                
                if westGroup != nil {
                    if northGroup != nil {
                        if westGroup != northGroup {
                            //merge groups
                            
                            equivalenceClasses.combineClassesContaining(westGroup!, and: northGroup!)
                        }
                        labelToSize[northGroup!]! += 1
                        labelledImage[y][x] = northGroup!
                    } else {
                        labelToSize[westGroup!]! += 1
                        labelledImage[y][x] = westGroup!
                    }
                } else if northGroup != nil {
                    labelToSize[northGroup!]! += 1
                    labelledImage[y][x] = northGroup!
                } else {
                    //NEW GROUP
                    var newGroup: Int
                    if (occupied) {
                        newGroup = nextOccupiedLabel
                        nextOccupiedLabel += 1
                    } else {
                        newGroup = nextEmptyLabel
                        nextEmptyLabel -= 1
                        
                        if x > 0 {
                            emptyLabelToNeighboringOccupiedLabel[newGroup] = labelledImage[y][x  - 1]
                        } else if y > 0 {
                            emptyLabelToNeighboringOccupiedLabel[newGroup] = labelledImage[y - 1][x]
                        }
                    }
                    equivalenceClasses.createSubsetWith(newGroup)
                    labelledImage[y][x] = newGroup
                    labelToSize[newGroup] = 1
                    labelToStartingPoint[newGroup] = (x, y)
                }
                
                if !occupied && (y == 0 || x == 0 || y == height - 1 || x == width - 1) {
                    equivalenceClasses.combineClassesContaining(labelledImage[y][x], and: -1)
                }
            }
        }
        
        for equivalenceClass in equivalenceClasses.classToElements.values {
            let first = equivalenceClass.first
            for label in equivalenceClass {
                if label != first! {
                    labelToSize[first!]! += labelToSize[label]!
                    labelToSize[label] = nil
                }
            }
        }
        
        let labelsAndSizes = labelToSize.sorted { $0.1 > $1.1 }
        var backgroundLabel: Int?
        var leafGroup: Int?
        var leafSize: Int?; // assume the biggest blob is leaf, second is the scale
        for groupAndSize in labelsAndSizes {
            if (groupAndSize.key > 0 && leafGroup == nil) {
                leafGroup = groupAndSize.key
                leafSize = groupAndSize.value
            }
            if (groupAndSize.key < 0 && backgroundLabel == nil) {
                backgroundLabel = groupAndSize.key
            }
            
            if (leafGroup != nil && backgroundLabel != nil) {
                break
            }
        }
        
        var leafGroups: Set<Int>?
        var backgroundGroups: Set<Int>?
        for equivalenceClass in equivalenceClasses.classToElements.values {
            if equivalenceClass.contains(leafGroup!) {
                leafGroups = equivalenceClass
            }
            if equivalenceClass.contains(backgroundLabel!) {
                backgroundGroups = equivalenceClass
            }
            
            if (leafGroups != nil && backgroundGroups != nil) {
                break
            }
        }
        
        let leafArea = getArea(pixels: leafSize!)
        var eatenArea: Float = 0.0
        
        let drawingManager = DrawingManager(withCanvasSize: leafHolesView.frame.size, withProjection: userDrawingProjection)
        drawingManager.getContext().setStrokeColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        for groupAndSize in labelsAndSizes {
            if (groupAndSize.key < 0) {
                if  !(backgroundGroups?.contains(groupAndSize.key))! && leafGroups!.contains(emptyLabelToNeighboringOccupiedLabel[groupAndSize.key]!) {
                    eatenArea += getArea(pixels: groupAndSize.value)
                    let (startX, startY) = labelToStartingPoint[groupAndSize.key]!
                    floodFill(image: combinedImage, fromPoint: CGPoint(x: startX, y: startY), drawingTo: drawingManager)
                }
            }
        }
        drawingManager.finish(imageView: leafHolesView)

        if scaleMarkPixelLength != nil {
            resultsText.text = "leaf is \(String(format: "%.3f", leafArea)) cm2 with \(String(format: "%.3f", eatenArea)) cm2 or \(String(format: "%.3f", eatenArea / leafArea * 100))% eaten"
        } else {
            resultsText.text = "leaf is \(String(format: "%.3f", eatenArea / leafArea * 100))% eaten"
        }
    }
    
    func getArea(pixels: Int) -> Float {
        if (scaleMarkPixelLength != nil) {
            return pow(2.0 / Float(scaleMarkPixelLength!), 2) * Float(pixels)
        } else {
            return Float(pixels)
        }
    }
}
