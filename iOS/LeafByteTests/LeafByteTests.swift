//
//  LeafByteTests.swift
//  LeafByteTests
//
//  Created by Adam Campbell on 12/20/17.
//  Copyright © 2017 The Blue Folder Project. All rights reserved.
//

import XCTest
@testable import LeafByte

class LeafByteTests: XCTestCase {
    func testThresholdingFilter() {
        let image = loadImage(named: "leafWithScale")
        
        var thresholdedImage: CIImage!
        self.measure {
            let filter = ThresholdingFilter()
            filter.setInputImage(image)
            thresholdedImage = filter.outputImage
        }
        
        let indexableImage = IndexableImage(ciToCgImage(thresholdedImage))
        
        XCTAssert(indexableImage.getPixel(x: 5, y: 5).isWhite())
        XCTAssert(indexableImage.getPixel(x: 1400, y: 1400).isNonWhite())
    }
    
    func testSuggestedThreshold() {
        let uiImage = loadImage(named: "leafWithScale")
        let cgImage = uiToCgImage(uiImage)
        
        var suggestedThreshold: Float!
        self.measure {
            suggestedThreshold = getSuggestedThreshold(image: cgImage)
        }
        
        XCTAssertEqual(139, Int(round(suggestedThreshold * 255)))
    }
    
    func testSettingsSerialization() {
        let settings = Settings()
        settings.measurementSaveLocation = .googleDrive
        settings.imageSaveLocation = .googleDrive
        settings.seriesName = "The Tale of Genji"
        settings.saveGpsData = true
        
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("settings")
        settings.serialize(at: path)
        let deserializedSettings = Settings.deserialize(from: path)
        
        XCTAssertEqual(settings, deserializedSettings)
    }
    
    func testDeserializeMissingSettings() {
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("no-settings-here")
        let deserializedSettings = Settings.deserialize(from: path)
        
        XCTAssertEqual(Settings(), deserializedSettings)
    }
    
    private func loadImage(named name: String) -> UIImage {
        let bundle = Bundle(for: type(of: self))
        guard let path = bundle.path(forResource: name, ofType: "jpg") else {
            fatalError("Image \(name) not found")
        }
        guard let image = UIImage(contentsOfFile: path) else {
            fatalError("Image \(name) could not be loaded")
        }
        return image
    }
}
