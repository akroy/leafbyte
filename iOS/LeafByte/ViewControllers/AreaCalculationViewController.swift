//
//  AreaCalculationViewController.swift
//  LeafByte
//
//  Created by Adam Campbell on 12/24/17.
//  Copyright © 2017 The Blue Folder Project. All rights reserved.
//

import CoreGraphics
import UIKit

final class AreaCalculationViewController: UIViewController, UIScrollViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate, UIPopoverPresentationControllerDelegate {
    // MARK: - Fields
    
    // These are passed from the previous view.
    var settings: Settings!
    var sourceType: UIImagePickerControllerSourceType!
    var cgImage: CGImage!
    var uiImage: UIImage!
    var scaleMarkPixelLength: Int?
    var scaleMarkEnd1: CGPoint?
    var scaleMarkEnd2: CGPoint?
    var inTutorial: Bool!
    var barcode: String?
    var initialConnectedComponentsInfo: ConnectedComponentsInfo!
    
    // Projection from the drawing space back to the base image, so we can check if the drawing is in bounds.
    var userDrawingToBaseImage: Projection!
    var baseImageRect: CGRect!
    
    // Track the previous, current, and "future" drawings to enable undoing and redoing.
    // Each drawing is a list of points to be connected by lines.
    var undoBuffer = [[CGPoint]]()
    var currentDrawing = [CGPoint]()
    var redoBuffer = [[CGPoint]]()
    
    // Tracks whether viewDidAppear has run, so that we can initialize only once.
    // It seems like this view should only appear once anyways, except that the flicker when the image picker closes counts as an appearance.
    var viewDidAppearHasRun = false
    
    // The current mode can be scrolling or drawing.
    var inScrollingMode = true
    
    // Track the actual results.
    var formattedPercentConsumed: String!
    var formattedLeafAreaIncludingConsumedAreaInCm2: String?
    var formattedConsumedAreaInCm2: String?
    
    let imagePicker = UIImagePickerController()
    
    // This is set while choosing the next image and is passed to the next thresholding view.
    var selectedImage: CGImage?
    
    // A point on the leaf at which to mark the leaf and whether the user has changed that point.
    var pointOnLeaf: (Int, Int)?
    var pointOnLeafHasBeenChanged = false
    
    // MARK: - Outlets
    
    @IBOutlet weak var gestureRecognizingView: UIScrollView!
    @IBOutlet weak var scrollableView: UIView!
    @IBOutlet weak var baseImageView: UIImageView!
    @IBOutlet weak var leafHolesView: UIImageView!
    @IBOutlet weak var scaleMarkingView: UIImageView!
    @IBOutlet weak var userDrawingView: UIImageView!
    @IBOutlet weak var grid: UIImageView!
    
    @IBOutlet weak var modeToggleButton: UIButton!
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!
    @IBOutlet weak var calculateButton: UIButton!
    @IBOutlet weak var completeButton: UIButton!
    
    @IBOutlet weak var sampleNumberButton: UIButton!
    @IBOutlet weak var resultsText: UILabel!
    @IBOutlet weak var notesField: UITextField!
    
    // MARK: - Actions
    
    @IBAction func toggleScrollingMode(_ sender: Any) {
        setScrollingMode(!inScrollingMode)
    }
    
    @IBAction func undo(_ sender: Any) {
        // Move the drawing from the undo buffer to the redo buffer.
        redoBuffer.append(undoBuffer.popLast()!)
        
        // Wipe the screen and redraw all drawings except the one we just "undid".
        initializeImage(view: userDrawingView, size: uiImage.size)
        undoBuffer.forEach { drawing in drawCompleteDrawing(drawing) }
        
        // Update the buttons.
        calculateButton.isEnabled = true
        undoButton.isEnabled = !undoBuffer.isEmpty
        redoButton.isEnabled = true
    }
    
    @IBAction func redo(_ sender: Any) {
        // Move the drawing from the redo buffer to the undo buffer.
        let drawingToRedo = redoBuffer.popLast()!
        undoBuffer.append(drawingToRedo)
        
        // Simpler than undo, we can simply draw this one drawing.
        drawCompleteDrawing(drawingToRedo)
        
        // Update the buttons.
        calculateButton.isEnabled = true
        undoButton.isEnabled = true
        redoButton.isEnabled = !redoBuffer.isEmpty
    }
    
    @IBAction func calculate(_ sender: Any) {
        // Don't allow recalculation until there's a possibility of a different result.
        calculateButton.isEnabled = false
        
        resultsText.text = NSLocalizedString("Loading", comment: "Shown while the results are being calculated")
        // The label won't update until this action returns, so put this calculation on the queue, and it'll be executed right after this function ends.
        DispatchQueue.main.async {
            self.calculateArea()
        }
    }
    
    @IBAction func goHome(_ sender: Any) {
        dismissNavigationController(self: self)
    }
    
    @IBAction func share(_ sender: Any) {
        // If anything has changed, recalculate to prevent accidentally sharing bad data.
        if calculateButton.isEnabled {
            calculateButton.isEnabled = false
            calculateArea()
        }
        
        let imageToShare = getCombinedImage()
        let dataToShare = [ imageToShare, resultsText.text! + NSLocalizedString(" Analyzed with LeafByte https://github.com/akroy/leafbyte", comment: "Shown after the results when sharing the results, e.g. on social media. Note the leading space that separates from the results") ] as [Any]
        let activityViewController = UIActivityViewController(activityItems: dataToShare, applicationActivities: nil)
        
        // Exclude activity types that don't make sense here.
        activityViewController.excludedActivityTypes = [
            UIActivityType.addToReadingList,
            UIActivityType.assignToContact,
            UIActivityType.openInIBooks,
            UIActivityType.postToVimeo,
            UIActivityType.print,
        ]
        
        // Make this work on iPads ( https://stackoverflow.com/questions/25644054/uiactivityviewcontroller-crashing-on-ios8-ipads ).
        activityViewController.popoverPresentationController?.sourceView = self.view
        
        self.present(activityViewController, animated: true, completion: nil)
    }
    
    @IBAction func nextImage(_ sender: Any) {
        // Disable to prevent double serializing.
        completeButton.isEnabled = false
        
        // If anything has changed, recalculate to prevent accidentally recording bad data.
        if calculateButton.isEnabled {
            calculateButton.isEnabled = false
            calculateArea()
            
            // Pause for .25s so this isn't a weird flicker.
            usleep(250000)
        }
        
        let afterSerialization = {
            self.imagePicker.sourceType = self.sourceType
            
            if self.sourceType == .camera {
                requestCameraAccess(self: self, onSuccess: {
                    if self.settings.useBarcode {
                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "toBarcodeScanning", sender: self)
                        }
                    } else {
                        self.present(self.imagePicker, animated: true, completion: nil)
                    }
                })
            } else {
                self.present(self.imagePicker, animated: true, completion: nil)
            }
        }
        
        // Record everything before moving on.
        handleSerialization(onSuccess: afterSerialization)
    }
    
    @IBAction func editSampleNumber(_ sender: Any) {
        presentSampleNumberAlert(self: self, sampleNumberButton: sampleNumberButton, settings: settings)
    }
    
    // MARK: - UIViewController overrides
    
    override func viewDidLoad(){
        super.viewDidLoad()
        
        setupGestureRecognizingView(gestureRecognizingView: gestureRecognizingView, self: self)
        setupImagePicker(imagePicker: imagePicker, self: self)
        
        baseImageView.contentMode = .scaleAspectFit
        leafHolesView.contentMode = .scaleAspectFit
        scaleMarkingView.contentMode = .scaleAspectFit
        userDrawingView.contentMode = .scaleAspectFit
        
        baseImageView.image = uiImage
        initializeImage(view: leafHolesView, size: uiImage.size)
        initializeImage(view: scaleMarkingView, size: uiImage.size)
        initializeImage(view: userDrawingView, size: uiImage.size)
        drawMarkers()
        
        userDrawingToBaseImage = Projection(fromView: baseImageView, toImageInView: baseImageView.image!)
        baseImageRect = CGRect(origin: CGPoint.zero, size: baseImageView.image!.size)
        
        setSampleNumberButtonText(sampleNumberButton, settings: settings)
        
        setScrollingMode(true)
        
        // Setup to get a callback when return is pressed on a keyboard.
        // Note that current iOS is buggy and doesn't show the return button for number keyboards even when enabled; this aims to handle that case once it works.
        notesField.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !viewDidAppearHasRun {
            calculateButton.isEnabled = false
            let baseImage = IndexableImage(cgImage)
            let combinedImage = LayeredIndexableImage(width: baseImage.width, height: baseImage.height)
            combinedImage.addImage(baseImage)
            
            if pointOnLeafHasBeenChanged == true {
                // The user has chosen a new point to mark the leaf, so refresh our calculations.
                initialConnectedComponentsInfo = labelConnectedComponents(image: combinedImage, pointToIdentify: pointOnLeaf)
            }
            
            useConnectedComponentsResults(connectedComponentsInfo: initialConnectedComponentsInfo, image: combinedImage)
            
            initializeGrid()
            
            if inTutorial {
                self.performSegue(withIdentifier: "helpPopover", sender: nil)
            }
            
            viewDidAppearHasRun = true
        }
    }
    
    // This is called before transitioning from this view to another view.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // If the segue is imageChosen, we're transitioning forward in the main flow, and we need to pass the selection forward.
        if segue.identifier == "imageChosen"
        {
            guard let destination = segue.destination as? ThresholdingViewController else {
                fatalError("Expected the next view to be the thresholding view but is \(segue.destination)")
            }
            
            destination.settings = settings
            destination.sourceType = sourceType
            destination.image = selectedImage!
            destination.inTutorial = false
        }
        // If the segue is toBarcodeScanning, we're transitioning forward in the main flow, but with barcode scanning.
        else if segue.identifier == "toBarcodeScanning"
        {
            if #available(iOS 10.0, *) {
                guard let destination = segue.destination as? BarcodeScanningViewController else {
                    fatalError("Expected the next view to be the barcode scanning view but is \(segue.destination)")
                }
                
                destination.settings = settings
            } else {
                fatalError("Attempting to use barcode scanning pre-iOS 10.0")
            }
        }
        else if segue.identifier == "helpPopover" {
            setupPopoverViewController(segue.destination, self: self)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // See finishWithImagePicker for why animations may be disabled; make sure they're enabled before leaving.
        UIView.setAnimationsEnabled(true)
    }
    
    // MARK: - UIPopoverPresentationControllerDelegate overrides
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    // MARK: - UIScrollViewDelegate overrides
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollableView
    }
    
    // MARK: - UIResponder overrides
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // If a user taps outside of the keyboard, close the keyboard.
        // Note that this callback doesn't run when interacting with the scroll view; those cases are handled in the UIScrollViewDelegate overrides above.
        dismissKeyboard()
        
        // No drawing in scrolling mode.
        if inScrollingMode {
            return
        }
        
        let candidatePoint = (touches.first?.location(in: userDrawingView))!
        // "Drawing" outside the image doesn't count.
        if !isDrawingPointInBaseImage(candidatePoint) {
            return
        }
        
        currentDrawing.append(candidatePoint)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // No drawing in scrolling mode.
        if inScrollingMode {
            return
        }
        
        let candidatePoint = touches.first!.location(in: userDrawingView)
        // "Drawing" outside the image doesn't count.
        if !isDrawingPointInBaseImage(candidatePoint) {
            return
        }
        
        // If there was a previous point, connect the dots.
        if !currentDrawing.isEmpty {
            drawLine(fromPoint: currentDrawing.last!, toPoint: candidatePoint)
        }
        
        currentDrawing.append(candidatePoint)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // No drawing in scrolling mode or outside the image.
        if inScrollingMode || currentDrawing.isEmpty {
            return
        }
        
        // If only one point, nothing has been drawn yet.
        if currentDrawing.count == 1 {
            drawLine(fromPoint: currentDrawing.last!, toPoint: currentDrawing.last!)
        }
        
        // Move the current drawing to the undo buffer.
        undoBuffer.append(currentDrawing)
        currentDrawing = []
        // Clear the redo buffer.
        redoBuffer = []
        
        // Update the buttons, allow recalculation now that there's a possibility of a different result.
        calculateButton.isEnabled = true
        undoButton.isEnabled = true
        redoButton.isEnabled = false
        
        // Switch back to scrolling after each line drawn.
        setScrollingMode(true)
    }
    
    // MARK: - UIImagePickerControllerDelegate overrides
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        finishWithImagePicker(self: self, info: info, selectImage: { selectedImage = $0 })
    }
    
    // If the image picker is canceled, dismiss it.
    // Also go back to the home screen, to sidestep complications around re-saving the same data (it's as if you're in the original image picker).
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
        dismissNavigationController(self: self)
    }
    
    // MARK: - UITextFieldDelegate overrides
    
    func textFieldDidBeginEditing(_ textField: UITextField){
        // Disable the gesture recognition so that we can catch touches outside of the keyboard to cancel the keyboard.
        gestureRecognizingView.isUserInteractionEnabled = false
    }
    
    // Called when return is pressed on the keyboard.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        dismissKeyboard()
        return true
    }
    
    // MARK: - Helpers
    
    // We want to limit drawing interactions to points that match up to the base image.
    // Otherwise, since connected components and flood filling are calculated within the base image, those operations will seem broken.
    private func isDrawingPointInBaseImage(_ point: CGPoint) -> Bool {
        let projectedPoint = userDrawingToBaseImage.project(point: point)
        return baseImageRect.contains(projectedPoint)
    }
    
    // Draw a complete drawing, made up of a sequence of points.
    private func drawCompleteDrawing(_ drawing: [CGPoint]) {
        if drawing.count == 1 {
            drawLine(fromPoint: drawing.first!, toPoint: drawing.first!)
        } else {
            for index in 0...drawing.count - 2 {
                drawLine(fromPoint: drawing[index], toPoint: drawing[index + 1])
            }
        }
    }
    
    private func drawLine(fromPoint: CGPoint, toPoint: CGPoint) {
        redoButton.isEnabled = false
        
        let drawingManager = DrawingManager(withCanvasSize: baseImageView.image!.size, withProjection: userDrawingToBaseImage)
        drawingManager.context.setStrokeColor(DrawingManager.darkGreen.cgColor)
        drawingManager.context.setLineWidth(2)
        drawingManager.drawLine(from: fromPoint, to: toPoint)
        drawingManager.finish(imageView: userDrawingView, addToPreviousImage: true)
    }
    
    private func setScrollingMode(_ inScrollingMode: Bool) {
        self.inScrollingMode = inScrollingMode
        
        gestureRecognizingView.isUserInteractionEnabled = inScrollingMode
        grid.isHidden = inScrollingMode
        
        if inScrollingMode {
            modeToggleButton.setTitle(NSLocalizedString("Draw", comment: "Enters the mode to draw leaf edges"), for: .normal)
        } else {
            modeToggleButton.setTitle(NSLocalizedString("Cancel", comment: "Exits the mode to draw leaf edges"), for: .normal)
        }
    }
    
    private func calculateArea() {
        // The BooleanIndexableImage will be a view across both sources of pixels.
        // First we add the base iamge of the leaf.
        let baseImage = IndexableImage(cgImage)
        let combinedImage = LayeredIndexableImage(width: baseImage.width, height: baseImage.height)
        combinedImage.addImage(baseImage)
        
        // Then we include any user drawings.
        let userDrawing = IndexableImage(uiToCgImage(userDrawingView.image!))
        combinedImage.addImage(userDrawing)
        
        let connectedComponentsInfo = labelConnectedComponents(image: combinedImage, pointToIdentify: pointOnLeafHasBeenChanged ? pointOnLeaf : nil)
        
        useConnectedComponentsResults(connectedComponentsInfo: connectedComponentsInfo, image: combinedImage)
    }
    
    private func useConnectedComponentsResults(connectedComponentsInfo: ConnectedComponentsInfo, image: LayeredIndexableImage) {
        let labelsAndSizes = connectedComponentsInfo.labelToSize.sorted { $0.1.total() > $1.1.total() }
        var leafLabelAndSize: (key: Int, value: Size)?
        if connectedComponentsInfo.labelOfPointToIdentify != nil {
            // A specific point on the leaf has been marked.
            leafLabelAndSize = labelsAndSizes.first(where: { $0.key == connectedComponentsInfo.labelOfPointToIdentify! })
        } else {
            // Assume the largest occupied component is the leaf.
            leafLabelAndSize = labelsAndSizes.first(where: { $0.key > 0 })
        }
        
        if leafLabelAndSize == nil {
            // This is a blank image, and trying to calculate area will crash.
            setNoLeafFound()
            return
        }
        let leafLabels = connectedComponentsInfo.equivalenceClasses.getElementsInClassWith(leafLabelAndSize!.key)!
        let leafAreaInPixels = leafLabelAndSize!.value.standardPart
        
        let emptyLabelsAndSizes = labelsAndSizes.filter { $0.key < 0 }
        
        if emptyLabelsAndSizes.count == 0 {
            // This is a solid image, so calculating area is pointless.
            setNoLeafFound()
            return
        }
        
        // Assume the biggest is the background, and everything else is potentially a hole.
        let emptyLabelsWithoutBackground = emptyLabelsAndSizes.dropFirst()
        
        let drawingManager = DrawingManager(withCanvasSize: leafHolesView.image!.size)
        drawingManager.context.setStrokeColor(DrawingManager.lightGreen.cgColor)
        
        var consumedAreaInPixels = leafLabelAndSize!.value.drawingPart
        for emptyLabelAndSize in emptyLabelsWithoutBackground {
            // This component is a hole if it neighbors the leaf (since we already filtered out the background).
            if !connectedComponentsInfo.emptyLabelToNeighboringOccupiedLabels[emptyLabelAndSize.key]!.intersection(leafLabels).isEmpty {
                // Add to the consumed size.
                consumedAreaInPixels += emptyLabelAndSize.value.standardPart
                
                // And fill in the consumed area.
                let (floodStartX, floodStartY) = connectedComponentsInfo.labelToMemberPoint[emptyLabelAndSize.key]!
                floodFill(image: image, fromPoint: CGPoint(x: floodStartX, y: floodStartY), drawingTo: drawingManager)
            }
        }
        
        drawingManager.finish(imageView: leafHolesView)
        
        // Set the result of the calculation, giving absolute area if the scale is set.
        let leafAreaIncludingConsumedAreaInPixels = leafAreaInPixels + consumedAreaInPixels
        let percentConsumed = Double(consumedAreaInPixels) / Double(leafAreaIncludingConsumedAreaInPixels) * 100
        formattedPercentConsumed = formatDouble(withThreeDecimalPoints: percentConsumed)
        if scaleMarkPixelLength != nil {
            let leafAreaIncludingConsumedAreaInCm2 = convertPixelsToCm2(leafAreaIncludingConsumedAreaInPixels)
            formattedLeafAreaIncludingConsumedAreaInCm2 = formatDouble(withThreeDecimalPoints: leafAreaIncludingConsumedAreaInCm2)
            let consumedAreaInCm2 = convertPixelsToCm2(consumedAreaInPixels)
            formattedConsumedAreaInCm2 = formatDouble(withThreeDecimalPoints: consumedAreaInCm2)
            
            // Set the number of lines or else lines past the first are dropped.
            resultsText.numberOfLines = 3
            resultsText.text = String.localizedStringWithFormat(NSLocalizedString("Total Leaf Area= %@ cm2\nConsumed Leaf Area= %@ cm2 \nPercent Consumed= %@%%", comment: "Results including absolute data"), formattedLeafAreaIncludingConsumedAreaInCm2!, formattedConsumedAreaInCm2!, formattedPercentConsumed!)
        } else {
            formattedLeafAreaIncludingConsumedAreaInCm2 = nil
            formattedConsumedAreaInCm2 = nil
            resultsText.text = String.localizedStringWithFormat(NSLocalizedString("Leaf is %d%% consumed.", comment: "Results with only relative data"), formattedPercentConsumed!)
        }
    }
    
    private func convertPixelsToCm2(_ pixels: Int) -> Double {
        if scaleMarkPixelLength == nil {
            fatalError("Attempting to calculate absolute area without scale set.")
        }
        
        let cmPerPixel = settings.scaleMarkLength / Double(scaleMarkPixelLength!)
        return pow(cmPerPixel, 2) * Double(pixels)
    }
    
    private func formatDouble(withThreeDecimalPoints double: Double) -> String {
        return String(format: "%.3f", double)
    }
    
    private func getCombinedImage() -> UIImage {
        return combineImages([ baseImageView, leafHolesView, scaleMarkingView, userDrawingView ])
    }
    
    private func setNoLeafFound() {
        resultsText.text = NSLocalizedString("No leaf found", comment: "Shown if the image is not valid to calculate results")
    }
    
    private func handleSerialization(onSuccess: @escaping () -> Void) {
        let onFailure = {
            let alertController = UIAlertController(title: nil, message: NSLocalizedString("Could not save to Google Drive.", comment: "Shown if saving to Google Drive fails"), preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancels the attempt to save"), style: .default, handler: { _ in
                self.completeButton.isEnabled = true
            })
            let switchToLocalAction = UIAlertAction(title: NSLocalizedString("Switch to Files App", comment: "Shown if saving to Google Drive fails to provide an alternative"), style: .default, handler: { _ in
                if self.settings.measurementSaveLocation == .googleDrive {
                    self.settings.measurementSaveLocation = .local
                }
                if self.settings.imageSaveLocation == .googleDrive {
                    self.settings.imageSaveLocation = .local
                }
                self.settings.serialize()
                
                self.handleSerialization(onSuccess: onSuccess)
            })
            let retryAction = UIAlertAction(title: NSLocalizedString("Retry", comment: "Allows attempting to save to Google Drive again"), style: .default, handler: { _ in
                self.handleSerialization(onSuccess: onSuccess)
            })
            
            alertController.addAction(cancelAction)
            alertController.addAction(switchToLocalAction)
            alertController.addAction(retryAction)
            
            self.present(alertController, animated: true, completion: nil)
        }
        
        serialize(settings: settings, image: getCombinedImage(), percentConsumed: formattedPercentConsumed, leafAreaInCm2: formattedLeafAreaIncludingConsumedAreaInCm2, consumedAreaInCm2: formattedConsumedAreaInCm2, barcode: barcode, notes: notesField.text!, onSuccess: onSuccess, onFailure: onFailure)
    }
    
    private func drawMarkers() {
        let drawingManager = DrawingManager(withCanvasSize: scaleMarkingView.image!.size)
        
        if scaleMarkPixelLength != nil {
            drawingManager.context.setLineWidth(2)
            drawingManager.context.setStrokeColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            drawingManager.drawLine(from: scaleMarkEnd1!, to: scaleMarkEnd2!)
        }
        
        drawingManager.drawStar(atPoint: CGPoint(x: pointOnLeaf!.0, y: pointOnLeaf!.1), withSize: 13)
        drawingManager.context.setFillColor(DrawingManager.lightGreen.cgColor)
        drawingManager.drawStar(atPoint: CGPoint(x: pointOnLeaf!.0, y: pointOnLeaf!.1), withSize: 10)
        
        drawingManager.finish(imageView: scaleMarkingView)
    }
    
    private func initializeGrid() {
        let size = 25
        let drawingManager = DrawingManager(withCanvasSize: grid.frame.size)
        drawingManager.context.setStrokeColor(gray: 0.5, alpha: 0.4)
        
        for y in stride(from: 0, to: roundToInt(grid.frame.height, rule: .down), by: size) {
            drawingManager.drawLine(from: CGPoint(x: 0, y: y), to: CGPoint(x: grid.frame.width, y: CGFloat(y)))
        }
        for x in stride(from: 0, to: roundToInt(grid.frame.width, rule: .down), by: size) {
            drawingManager.drawLine(from: CGPoint(x: x, y: 0), to: CGPoint(x: CGFloat(x), y: grid.frame.height))
        }
        
        drawingManager.finish(imageView: grid)
    }
    
    private func dismissKeyboard() {
        // Reenable gesture recognition if we disabled it for the keyboard.
        gestureRecognizingView.isUserInteractionEnabled = inScrollingMode
        
        self.view.endEditing(true)
    }
}
