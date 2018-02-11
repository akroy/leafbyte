//
//  SettingsViewController.swift
//  LeafByte
//
//  Created by Adam Campbell on 1/3/18.
//  Copyright © 2018 The Blue Folder Project. All rights reserved.
//

import GoogleSignIn
import UIKit

final class SettingsViewController: UIViewController, UITextFieldDelegate {
    // MARK: - Fields
    
    var settings: Settings!
    
    var activeField: UITextField?
    
    // MARK: - Outlets
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var datasetName: UITextField!
    @IBOutlet weak var imageSaveLocation: UISegmentedControl!
    @IBOutlet weak var measurementSaveLocation: UISegmentedControl!
    @IBOutlet weak var nextSampleNumber: UITextField!
    @IBOutlet weak var saveGps: UISwitch!
    @IBOutlet weak var scaleMarkLength: UITextField!
    
    @IBOutlet weak var datasetNameLabel: UILabel!
    @IBOutlet weak var nextSampleNumberLabel: UILabel!
    @IBOutlet weak var saveGpsLabel: UILabel!
    
    @IBOutlet weak var signOutOfGoogleButton: UIButton!
    
    // MARK: - Actions
    
    @IBAction func datasetNameChanged(_ sender: UITextField) {
        // Fall back to the default if the box is empty.
        var newDatasetName: String!
        if sender.text!.isEmpty {
            newDatasetName = Settings.defaultDatasetName
            
            // If we fallback, update the box too.
            datasetName.text = newDatasetName
        } else {
            newDatasetName = sender.text!
        }
        
        settings.datasetName = newDatasetName
        // Switch to the next sample number associated with this dataset.
        nextSampleNumber.text = String(settings.initializeNextSampleNumberIfNeeded())
        settings.serialize()
    }
    
    @IBAction func imageSaveLocationChanged(_ sender: UISegmentedControl) {
        dismissKeyboard()
        
        let newSaveLocation = indexToSaveLocation(sender.selectedSegmentIndex)
        let persistChange = {
            self.settings.imageSaveLocation = newSaveLocation
            self.settings.serialize()
            
            self.updateEnabledness()
        }
        
        if newSaveLocation == .googleDrive {
            GoogleSignInManager.initiateSignIn(
                onAccessTokenAndUserId: { (_, _) in
                    persistChange()
                },
                onError: { _ in
                    // Set the selected index back to the previous selected index; don't allow changing to Google Drive if you can't log-in.
                    self.imageSaveLocation.selectedSegmentIndex = self.saveLocationToIndex(self.settings.imageSaveLocation)
                    self.presentFailedGoogleSignInAlert()
                })
        } else {
            persistChange()
        }
    }
    
    @IBAction func measurementSaveLocationChanged(_ sender: UISegmentedControl) {
        dismissKeyboard()
        
        let newSaveLocation = indexToSaveLocation(sender.selectedSegmentIndex)
        let persistChange = {
            self.settings.measurementSaveLocation = newSaveLocation
            self.settings.serialize()
            
            self.updateEnabledness()
        }
        
        if newSaveLocation == .googleDrive {
            GoogleSignInManager.initiateSignIn(
                onAccessTokenAndUserId: { _, _ in 
                    persistChange()
            },
                onError: { _ in
                    // Set the selected index back to the previous selected index; don't allow changing to Google Drive if you can't log-in.
                    self.measurementSaveLocation.selectedSegmentIndex = self.saveLocationToIndex(self.settings.measurementSaveLocation)
                    self.presentFailedGoogleSignInAlert()
            })
        } else {
            persistChange()
        }
    }
    
    @IBAction func nextSampleNumberChanged(_ sender: UITextField) {
        // Fall back to the default if the box is empty.
        var newNextSampleNumber: Int!
        if sender.text!.isEmpty {
            newNextSampleNumber = Settings.defaultNextSampleNumber
            
            // If we fallback, update the box too.
            nextSampleNumber.text = String(newNextSampleNumber)
        } else {
            newNextSampleNumber = Int(sender.text!)
        }
        
        settings.datasetNameToNextSampleNumber[settings.datasetName] = newNextSampleNumber
        settings.serialize()
    }
    
    @IBAction func saveGpsChanged(_ sender: UISwitch) {
        dismissKeyboard()
        
        settings.saveGpsData = sender.isOn
        settings.serialize()
    }
    
    @IBAction func scaleMarkLengthChanged(_ sender: UITextField) {
        // Fall back to the default if the box is empty.
        var newScaleMarkLength: Double!
        if sender.text!.isEmpty {
            newScaleMarkLength = Settings.defaultScaleMarkLength
            
            // If we fallback, update the box too.
            scaleMarkLength.text = String(newScaleMarkLength)
        } else {
            newScaleMarkLength = Double(sender.text!)
        }
        
        settings.scaleMarkLength = newScaleMarkLength
        settings.serialize()
    }
    
    @IBAction func signOutOfGoogle(_ sender: Any) {
        if settings.measurementSaveLocation == .googleDrive {
            settings.measurementSaveLocation = .local
            measurementSaveLocation.selectedSegmentIndex = saveLocationToIndex(.none)
        }
        if settings.imageSaveLocation == .googleDrive {
            settings.imageSaveLocation = .local
            imageSaveLocation.selectedSegmentIndex = saveLocationToIndex(.none)
        }
        settings.serialize()
        
        GIDSignIn.sharedInstance().signOut()
    }
    
    @IBAction func resetDriveHistory(_ sender: Any) {
        settings.datasetNameToUserIdToGoogleFolderId = [:]
        settings.datasetNameToUserIdToGoogleSpreadsheetId = [:]
        settings.userIdToTopLevelGoogleFolderId = [:]
        settings.serialize()
    }
    
    // MARK: - UIViewController overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        datasetName.text = settings.datasetName
        imageSaveLocation.selectedSegmentIndex = saveLocationToIndex(settings.imageSaveLocation)
        measurementSaveLocation.selectedSegmentIndex = saveLocationToIndex(settings.measurementSaveLocation)
        nextSampleNumber.text = String(settings.getNextSampleNumber())
        saveGps.setOn(settings.saveGpsData, animated: false)
        scaleMarkLength.text = String(settings.scaleMarkLength)
        
        // Setup to get a callback when return is pressed on a keyboard.
        // Note that current iOS is buggy and doesn't show the return button for number keyboards even when enabled; this aims to handle that case once it works.
        datasetName.delegate = self
        nextSampleNumber.delegate = self
        scaleMarkLength.delegate = self
        
        updateEnabledness()
        
        registerForKeyboardNotifications()
        
        // Make sure touch events aren't intercepted by the scroll view.
        let recog = UITapGestureRecognizer(target: self, action: #selector(SettingsViewController.dismissKeyboard))
        recog.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(recog)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        deregisterFromKeyboardNotifications()
    }
    
    // If a user taps outside of the keyboard, close the keyboard.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        dismissKeyboard()
    }
    
    // MARK: - UITextFieldDelegate overrides
    
    // Called when return is pressed on the keyboard.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        dismissKeyboard()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField){
        // Track the current edited fields.
        activeField = textField
    }
    
    func textFieldDidEndEditing(_ textField: UITextField){
        // Clear the current edited fields.
        activeField = nil
    }
    
    // MARK: - Helpers
    
    // @objc to allow calling as a Selector.
    @objc private func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    private func indexToSaveLocation(_ index: Int) -> Settings.SaveLocation {
        switch index {
        case 1:
            return Settings.SaveLocation.local
        case 2:
            return Settings.SaveLocation.googleDrive
        default:
            return Settings.SaveLocation.none
        }
    }
    
    private func saveLocationToIndex(_ saveLocation: Settings.SaveLocation) -> Int {
        switch saveLocation {
        case .none:
            return 0
        case .local:
            return 1
        case .googleDrive:
            return 2
        }
    }
    
    // Disable controls that would have no effect.
    private func updateEnabledness() {
        let measurementSavingEnabled = settings.measurementSaveLocation != .none
        saveGps.isEnabled = measurementSavingEnabled
        saveGpsLabel.isEnabled = measurementSavingEnabled
        
        let anySavingEnabled = settings.measurementSaveLocation != .none || settings.imageSaveLocation != .none
        datasetName.isEnabled = anySavingEnabled
        datasetNameLabel.isEnabled = anySavingEnabled
        nextSampleNumber.isEnabled = anySavingEnabled
        nextSampleNumberLabel.isEnabled = anySavingEnabled
        
        let anyGoogleDriveSavingEnabled = settings.measurementSaveLocation == .googleDrive || settings.imageSaveLocation == .googleDrive
        signOutOfGoogleButton.isEnabled = anyGoogleDriveSavingEnabled
    }
    
    private func presentFailedGoogleSignInAlert() {
        presentAlert(self: self, title: nil, message: "Google sign-in is required for saving to Google Drive")
    }
    
    func registerForKeyboardNotifications(){
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWasShown(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillBeHidden(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    func deregisterFromKeyboardNotifications(){
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    @objc func keyboardWasShown(notification: NSNotification){
        var info = notification.userInfo!
        let keyboardSize = (info[UIKeyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue.size
        
        let contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height, 0.0)
        self.scrollView.contentInset = contentInsets
        self.scrollView.scrollIndicatorInsets = contentInsets
        
        var aRect = self.view.frame
        aRect.size.height -= keyboardSize.height
        if let activeField = self.activeField {
            print(aRect)
            print(activeField.frame.origin)
            if (!aRect.contains(activeField.frame.origin)){
                scrollView.setContentOffset(CGPoint(x: 0, y: 200), animated: true)
            }
        }
    }
    
    @objc func keyboardWillBeHidden(notification: NSNotification){
        // When the keyboard is to be hidden, scroll the view back.
        var info = notification.userInfo!
        let keyboardSize = (info[UIKeyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue.size
        let contentInsets = UIEdgeInsetsMake(0.0, 0.0, -keyboardSize.height, 0.0)
        self.scrollView.contentInset = contentInsets
        self.scrollView.scrollIndicatorInsets = contentInsets
    }
}
