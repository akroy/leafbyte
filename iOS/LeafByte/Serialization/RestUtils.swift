//
//  RestUtils.swift
//  LeafByte
//
//  Created by Abigail Getman-Pickering on 1/21/18.
//  Copyright © 2018 Zoe Getman-Pickering. All rights reserved.
//

import Foundation

func post(url: String, accessToken: String, jsonBody: String, onSuccessfulResponse: @escaping ([String: Any]) -> Void, onUnsuccessfulResponse: @escaping (Int, [String: Any]) -> Void, onError: @escaping (Error) -> Void) {
    post(url: url, accessToken: accessToken, body: jsonBody.data(using: .utf8)!, bodyForDebugging: jsonBody, onSuccessfulResponse: onSuccessfulResponse, onUnsuccessfulResponse: onUnsuccessfulResponse, onError: onError)
}

func post(url: String, accessToken: String, body: Data, bodyForDebugging: String? = nil, contentType: String = "application/json", onSuccessfulResponse: @escaping ([String: Any]) -> Void, onUnsuccessfulResponse: @escaping (Int, [String: Any]) -> Void, onError: @escaping (Error) -> Void) {
    makeRestCall(method: "POST", url: url, accessToken: accessToken, body: body, bodyForDebugging: bodyForDebugging, contentType: contentType, onSuccessfulResponse: onSuccessfulResponse, onUnsuccessfulResponse: onUnsuccessfulResponse, onError: onError)
}

private func makeRestCall(method: String, url urlString: String, accessToken: String, body: Data, bodyForDebugging: String? = nil, contentType: String, onSuccessfulResponse: @escaping ([String: Any]) -> Void, onUnsuccessfulResponse: @escaping (Int, [String: Any]) -> Void, onError: @escaping (Error) -> Void) {
    let url = URL(string: urlString)
    
    var request = URLRequest(url: url!)
    request.httpMethod = method
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.addValue(contentType, forHTTPHeaderField: "Content-Type")
    request.addValue(String(body.count), forHTTPHeaderField: "Content-Length")
    request.httpBody = body
    
    let session = URLSession(configuration: URLSessionConfiguration.default)
    
    let task = session.dataTask(with: request as URLRequest) { (data, response, error) in
        if error != nil {
            print("REST error: \(error!)")
            onError(error!)
            return
        }
        
        let dataJson = try! JSONSerialization.jsonObject(with: data!) as! [String: Any]
        
        let statusCode = (response! as! HTTPURLResponse).statusCode
        if statusCode < 200 || statusCode >= 300 {
            print("Unsuccessful REST response!")
            print("Url: \(url!)")
            if bodyForDebugging != nil {
                print("Request: \(bodyForDebugging!)")
            }
            print("Response: \(dataJson)")
            onUnsuccessfulResponse(statusCode, dataJson)
            return
        }
        
        onSuccessfulResponse(dataJson)
    }
    task.resume()
}
