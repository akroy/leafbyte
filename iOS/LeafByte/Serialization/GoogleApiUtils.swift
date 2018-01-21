//
//  GoogleApiUtils.swift
//  LeafByte
//
//  Created by Adam Campbell on 1/21/18.
//  Copyright © 2018 The Blue Folder Project. All rights reserved.
//

func createFolder(name: String, accessToken: String, actionWithFolderId: @escaping (String) -> Void) {
    createFile(name: name, folderId: nil, type: "folder", accessToken: accessToken, actionWithId: actionWithFolderId)
}

func createSheet(name: String, folderId: String, accessToken: String, actionWithSpreadsheetId: @escaping (String) -> Void) {
    createFile(name: name, folderId: folderId, type: "spreadsheet", accessToken: accessToken, actionWithId: actionWithSpreadsheetId)
}

func appendToSheet(spreadsheetId: String, row: [String], accessToken: String) {
    let formattedRow = row.map({"\"\($0)\""}).joined(separator: ",")
    post(url: "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetId)/values/Sheet1:append?valueInputOption=RAW&insertDataOption=INSERT_ROWS",
        accessToken: accessToken,
        jsonBody: "{values: [[\(formattedRow)]]}")
}

private func createFile(name: String, folderId: String?, type: String, accessToken: String, actionWithId: @escaping (String) -> Void) {
    let parentsParam = folderId != nil
        ? " parents: [{id: \"\(folderId!)\"}],"
        : ""
    
    post(url: "https://www.googleapis.com/drive/v2/files",
         accessToken: accessToken,
         jsonBody: "{title: \"\(name)\",\(parentsParam) mimeType: \"application/vnd.google-apps.\(type)\"}",
        actionWithResponse: { response in actionWithId(response["id"] as! String) })
}
