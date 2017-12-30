//
//  LBMainMenuViewController.swift
//  LeafByte
//
//  Created by Adam Campbell on 12/20/17.
//  Copyright © 2017 The Blue Folder Project. All rights reserved.
//

import UIKit

class LBMainMenuViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        
        //self.navigationController?.popToRootViewController(animated: false)
    }
    
    @IBAction func backToMainMenu(segue: UIStoryboardSegue){}

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.setAnimationsEnabled(true)
    }
    
    @IBAction func takePicture(_ sender: Any) {
        // TODO: handle case where no given access
        if !UIImagePickerController.isSourceTypeAvailable(.camera){
            let alertController = UIAlertController.init(title: nil, message: "No available camera.", preferredStyle: .alert)
            
            let okAction = UIAlertAction.init(title: "OK", style: .default, handler: {(alert: UIAlertAction!) in
            })
            
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        imagePicker.sourceType = .camera
        present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func choosePictureFromLibrary(_ sender: Any) {
        //imagePicker.modalPresentationStyle = .overCurrentContext
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    
    var image: UIImage?
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "imageChosen"
        {
            guard let navController = segue.destination as? UINavigationController else {
                print(type(of: segue.destination))
                return
                //fatalError("Expected a seque from the main menu to threshold but instead went to: \(segue.destination)")
            }
            
            guard let destination = navController.topViewController as? LBThresholdViewController else {
                return
            }
            
            destination.image = image!
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        // The info dictionary may contain multiple representations of the image. You want to use the original.
        guard let selectedImage = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            fatalError("Expected a dictionary containing an image, but was provided the following: \(info)")
        }
    
        image = selectedImage
        
        // Dismiss the picker.
        dismiss(animated: false, completion: {() in
            UIView.setAnimationsEnabled(false)
            self.performSegue(withIdentifier: "imageChosen", sender: self)
        })
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}
