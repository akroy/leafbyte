//
//  GoogleSignInManager.swift
//  LeafByte
//
//  Created by Adam Campbell on 1/20/18.
//  Copyright © 2018 The Blue Folder Project. All rights reserved.
//

import GoogleSignIn

// This pretends to be a view controller, because the delegate has a runtime requirement of being a view controller.
class GoogleSignInManager: UIViewController, GIDSignInDelegate, GIDSignInUIDelegate {
    
    var actionWithAccessToken: ((_ accessToken: String) -> Void)!
    
    static func initiateSignIn(actionWithAccessToken: @escaping (_ accessToken: String) -> Void) {
        let googleSignInManager = GoogleSignInManager()
        googleSignInManager.actionWithAccessToken = actionWithAccessToken
        
        googleSignInManager.initiateSignIn()
    }
    
    func initiateSignIn() {
        // This is LeafByte's Google Drive API key.
        GIDSignIn.sharedInstance().clientID = "82243022118-vmepc1s96dt76ss9pc46l2kvlo5mom1r.apps.googleusercontent.com"
        
        // Only request access to files created by LeafByte.
        // TODO: drive.file once creating file self
        GIDSignIn.sharedInstance().scopes = [ "https://www.googleapis.com/auth/drive" ]
        
        // Enable callback once the sign-in completes.
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        
        // Actually do the sign-in.
        GIDSignIn.sharedInstance().signIn()
    }
    
    // Called automatically when sign-in is complete.
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        // TODO: how to get errors out!??
        if error != nil {
            fatalError(String(describing: error!))
        }
        
        
        
        
        actionWithAccessToken(user.authentication.accessToken!)
        //return
        let token = user.authentication.accessToken!
        
        createFolder(name: "Noodle folder", accessToken: token, actionWithFolderId: { folderId in
            createSheet(name: "Noodle", accessToken: token, actionWithSpreadsheetId: { spreadsheetId in
                appendToSheet(spreadsheetId: spreadsheetId, row: ["a", "b", "Noodle"], accessToken: token)
                moveToFolder(folderId: folderId, childId: spreadsheetId, accessToken: token)
            })
        })
        
        
        //let spreadsheetId = "1Q2zq547BPvw2b5BeLQiIaG21CZOUXGhUM4tO-lhFNfs"
        
    }
}
