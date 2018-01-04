//
//  ImageUtils.swift
//  LeafByte
//
//  Created by Adam Campbell on 1/4/18.
//  Copyright © 2018 The Blue Folder Project. All rights reserved.
//

import CoreImage

// Convert a Core Image image to a Core Graphics image. Caution: this is slow.
// TODO: avoid doing this https://stackoverflow.com/questions/37450696/drawing-a-ciimage-is-too-slow
func ciToCgImage(_ ciImage: CIImage) -> CGImage {
    let context: CIContext = CIContext.init(options: nil)
    return context.createCGImage(ciImage, from: ciImage.extent)!
}
