//
//  SerializationUtils.swift
//  LeafByte
//
//  Created by Adam Campbell on 1/19/18.
//  Copyright © 2018 The Blue Folder Project. All rights reserved.
//

import Foundation
import UIKit

let header = [ "Date", "Time", "Leaf Area (cm2)", "Eaten Area (cm2)", "Percent Eaten" ]
let csvHeader = stringRowToCsvRow(header)

func serialize(settings: Settings, image: UIImage, percentEaten: String, leafAreaInCm2: String?, eatenAreaInCm2: String?) {
    serializeMeasurement(settings: settings, percentEaten: percentEaten, leafAreaInCm2: leafAreaInCm2, eatenAreaInCm2: eatenAreaInCm2)
    serializeImage(settings: settings, image: image)
}

private func serializeMeasurement(settings: Settings, percentEaten: String, leafAreaInCm2: String?, eatenAreaInCm2: String?) {
    if settings.measurementSaveLocation == .none {
        return
    }
    
    let date = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.MM.dd"
    let formattedDate = formatter.string(from: date)
    formatter.dateFormat = "HH:mm:ss"
    let formattedTime = formatter.string(from: date)
    
    let row = [ formattedDate, formattedTime, leafAreaInCm2 ?? "", eatenAreaInCm2 ?? "", percentEaten ]
    
    switch settings.measurementSaveLocation {
    case .local:
        let url = getUrlForVisibleFiles().appendingPathComponent("\(settings.seriesName).csv")
        initializeFileIfNonexistant(url, withData: csvHeader)
        
        let csvRow = stringRowToCsvRow(row)
        appendToFile(url, data: csvRow)
        
    case .googleDrive:
        ()

    default:
        break
    }
}

private func serializeImage(settings: Settings, image: UIImage) {
    switch settings.imageSaveLocation {
    case .none:
        ()
    case .local:
        let url = getUrlForVisibleFiles().appendingPathComponent("\(settings.seriesName).png")
        
        let pngImage = UIImagePNGRepresentation(image)!
        try! pngImage.write(to: url)
        
    case .googleDrive:
        ()
    }
}

private func stringRowToCsvRow(_ row: [String]) -> Data {
    return (row.joined(separator: ",") + "\n").data(using: String.Encoding.utf8)!
}
