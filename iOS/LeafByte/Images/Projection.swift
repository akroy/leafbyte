//
//  Projection.swift
//  LeafByte
//
//  Created by Adam Campbell on 1/6/18.
//  Copyright © 2018 The Blue Folder Project. All rights reserved.
//

import CoreGraphics
import UIKit

// Represents a projection from one space to another ( https://en.wikipedia.org/wiki/Projection_(mathematics) ).
// For example, finding the matching pixel in two different spaces that have different dimensions.
class Projection {
    static let identity = Projection(scale: 1, xOffset: 0, yOffset: 0)
    
    let scale: Double
    let xOffset: Double
    let yOffset: Double
    
    init(fromImageInView image: UIImage, toView view: UIView ) {
        let viewSize = view.frame.size
        let imageSize = image.size
        
        // Work back to find how the image was scaled into the view.
        let scalingRatioForWidth = viewSize.width / imageSize.width
        let scalingRatioForHeight = viewSize.height / imageSize.height
        let scalingRatio = min(scalingRatioForWidth, scalingRatioForHeight)
        
        scale = Double(scalingRatio)
        
        xOffset = Double(viewSize.width - imageSize.width * scalingRatio) / 2
        yOffset = Double(viewSize.height - imageSize.height * scalingRatio) / 2
    }
    
    init(invertProjection baseProjection: Projection) {
        scale = 1 / baseProjection.scale
        xOffset = -baseProjection.xOffset / baseProjection.scale
        yOffset = -baseProjection.yOffset / baseProjection.scale
    }
    
    init(fromProjection baseProjection: Projection, withExtraXOffset extraXOffset: Double = 0, withExtraYOffset extraYOffset: Double = 0) {
        scale = baseProjection.scale
        xOffset = baseProjection.xOffset + extraXOffset
        yOffset = baseProjection.yOffset + extraYOffset
    }
    
    init(scale: Double, xOffset: Double, yOffset: Double) {
        self.scale = scale
        self.xOffset = xOffset
        self.yOffset = yOffset
    }
    
    func project(x: Int, y: Int) -> (Int, Int) {
        let (projectedX, projectedY) = project(x: Double(x), y: Double(y))
        return (roundToInt(projectedX), roundToInt(projectedY))
    }
    
    func project(point: CGPoint) -> CGPoint {
        let (projectedX, projectedY) = project(x: point.x, y: point.y)
        return CGPoint(x: projectedX, y: projectedY)
    }
    
    func project(x: CGFloat, y: CGFloat) -> (CGFloat, CGFloat) {
        let (projectedX, projectedY) = project(x: Double(x), y: Double(y))
        return (CGFloat(projectedX), CGFloat(projectedY))
    }
    
    func project(x: Double, y: Double) -> (Double, Double) {
        let projectedX = x * scale + xOffset
        let projectedY = y * scale + yOffset
        return (projectedX, projectedY)
    }
}