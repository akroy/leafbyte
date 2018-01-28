//
//  RestUtils.swift
//  LeafByte
//
//  Created by Adam Campbell on 1/21/18.
//  Copyright © 2018 The Blue Folder Project. All rights reserved.
//

import Foundation

// TODO: need these be separate?
func post(url: String, accessToken: String, jsonBody: String, onSuccessfulResponse: @escaping ([String: Any]) -> Void, onUnsuccessfulResponse: @escaping ([String: Any]) -> Void, onError: @escaping (Error) -> Void) {
    makeRestCall(method: "POST", url: url, accessToken: accessToken, body: jsonBody.data(using: .utf8)!, contentType: "application/json", onSuccessfulResponse: onSuccessfulResponse, onUnsuccessfulResponse: onUnsuccessfulResponse, onError: onError)
}

func makeRestCall(method: String, url urlString: String, accessToken: String, body: Data, contentType: String, onSuccessfulResponse: @escaping ([String: Any]) -> Void, onUnsuccessfulResponse: @escaping ([String: Any]) -> Void, onError: @escaping (Error) -> Void) {
    let url = URL(string: urlString)
    
    var request = URLRequest(url: url!)
    request.httpMethod = method
    request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.addValue(contentType, forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    
    let session = URLSession(configuration: URLSessionConfiguration.default)
    
    let task = session.dataTask(with: request as URLRequest) { (data, response, error) in
        if error != nil {
            onError(error!)
            return
        }
        
        let dataJson = try! JSONSerialization.jsonObject(with: data!) as! [String: Any]
        
        let statusCode = (response! as! HTTPURLResponse).statusCode
        if statusCode < 200 || statusCode >= 300 {
            onUnsuccessfulResponse(dataJson)
            return
        }
        
        onSuccessfulResponse(dataJson)
    }
    task.resume()
}
