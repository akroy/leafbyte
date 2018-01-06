//
//  DrawingManager.swift
//  LeafByte
//
//  Created by Adam Campbell on 1/6/18.
//  Copyright © 2018 The Blue Folder Project. All rights reserved.
//

import CoreGraphics
import UIKit

class DrawingManager {
    // See "Points and Pixels" at https://www.raywenderlich.com/162315/core-graphics-tutorial-part-1-getting-started for why this exists.
    private static let pixelOffset = Float(0.5)
    
    private let context: CGContext
    private let projection: Projection
    
    init(withCanvasSize canvasSize: CGSize, withProjection baseProjection: Projection = Projection.identity) {
        UIGraphicsBeginImageContext(canvasSize)
        context = UIGraphicsGetCurrentContext()!
        
        self.projection = Projection(fromProjection: baseProjection, withExtraXOffset: DrawingManager.pixelOffset, withExtraYOffset: DrawingManager.pixelOffset)
    }
    
    func setColorToRed() {
        context.setStrokeColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
    }
    
    func drawLine(from fromPoint: CGPoint, to toPoint: CGPoint) {
        let projectedFromPoint = projection.project(x: Float(fromPoint.x), y: Float(fromPoint.y))
        let projectedToPoint = projection.project(x: Float(toPoint.x), y: Float(toPoint.y))
        
        context.move(to: CGPoint(x: CGFloat(projectedFromPoint.0), y: CGFloat(projectedFromPoint.1)))
        context.addLine(to: CGPoint(x: CGFloat(projectedToPoint.0), y: CGFloat(projectedToPoint.1)))
        context.strokePath()
    }
    
    func finish(imageView: UIImageView) {
        imageView.image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
    }
}
