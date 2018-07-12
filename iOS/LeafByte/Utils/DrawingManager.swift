//
//  DrawingManager.swift
//  LeafByte
//
//  Created by Adam Campbell on 1/6/18.
//  Copyright © 2018 The Blue Folder Project. All rights reserved.
//

import CoreGraphics
import UIKit

// This class manages drawing on a CGContext.
final class DrawingManager {
    static let lightGreen = UIColor(red: 0.780392156, green: 1.0, blue: 0.5647058823, alpha: 1.0)
    static let darkGreen = UIColor(red: 0.13, green: 1.0, blue: 0.13, alpha: 1.0)
    static let lightRed = UIColor(red: 1.0, green: 0.7529411765, blue: 0.7960784314, alpha: 1.0)
    static let darkRed = UIColor(red: 1.0, green: 0, blue: 0, alpha: 1.0)
    
    // See "Points and Pixels" at https://www.raywenderlich.com/162315/core-graphics-tutorial-part-1-getting-started for why this exists.
    private static let pixelOffset = 0.5
    
    let context: CGContext
    
    private let projection: Projection
    private let canvasSize: CGSize
    
    init(withCanvasSize canvasSize: CGSize, withProjection baseProjection: Projection? = nil) {
        self.canvasSize = canvasSize
        UIGraphicsBeginImageContext(canvasSize)
        context = UIGraphicsGetCurrentContext()!
        // Make all the drawing precise.
        // This avoids our drawn lines looking blurry (since you can zoom in).
        // It looks particularly bad for the shaded in holes, since the alternating blurred lines look like stripes.
        context.interpolationQuality = CGInterpolationQuality.high
        context.setAllowsAntialiasing(false)
        context.setShouldAntialias(false)
        
        if baseProjection == nil {
            self.projection = Projection(scale: 1, xOffset: DrawingManager.pixelOffset, yOffset: DrawingManager.pixelOffset, bounds: canvasSize)
        } else {
            self.projection = Projection(fromProjection: baseProjection!, withExtraXOffset: DrawingManager.pixelOffset, withExtraYOffset: DrawingManager.pixelOffset)
        }
    }
    
    func drawLine(from fromPoint: CGPoint, to toPoint: CGPoint) {
        let projectedFromPoint = projection.project(point: fromPoint)
        
        // A line from a point to itself doesn't show up, so draw a 1 pixel rectangle.
        if fromPoint == toPoint {
            context.addRect(CGRect(origin: projectedFromPoint, size: CGSize(width: 1.0, height: 1.0)))
        }
        
        let projectedToPoint = projection.project(point: toPoint)
        
        context.move(to: projectedFromPoint)
        context.addLine(to: projectedToPoint)
        context.strokePath()
    }
    
    func drawLeaf(atPoint point: CGPoint) {
        let projectedPoint = projection.project(point: point)
        
        let size = CGFloat(70) * 0.8
        
        context.setLineCap(.round)
        
        let dotSize1 = size / 13
        context.setStrokeColor(DrawingManager.darkRed.cgColor)
        context.setLineWidth(dotSize1 + 1)
        context.addEllipse(in: CGRect(origin: CGPoint(x: projectedPoint.x - dotSize1, y: projectedPoint.y - dotSize1), size: CGSize(width: dotSize1 * 2, height: dotSize1 * 2)))
        context.strokePath()
                
        let stemLength = size * 2 / 7
        let startOfLeaf = CGPoint(x: projectedPoint.x + stemLength, y: projectedPoint.y - stemLength)
        
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.5)
        context.setLineCap(.square)
        
        context.move(to: CGPoint(x: projectedPoint.x + 1, y: projectedPoint.y - 1))
        context.addLine(to: CGPoint(x: projectedPoint.x + 3 * stemLength, y: projectedPoint.y - 3 * stemLength))
        context.strokePath()
        
        
        context.setFillColor(DrawingManager.darkRed.cgColor)
        drawLeafOutline(leafBase: startOfLeaf, withSize: size, withOffset: 2)
        
        context.setFillColor(DrawingManager.lightRed.cgColor)
        drawLeafOutline(leafBase: startOfLeaf, withSize: size)
        
        
        
        context.setStrokeColor(DrawingManager.darkRed.cgColor)
        context.setLineWidth(1.25)
        context.setLineCap(.round)
        
        context.move(to: projectedPoint)
        context.addLine(to: CGPoint(x: projectedPoint.x + 3 * stemLength, y: projectedPoint.y - 3 * stemLength))
        context.strokePath()
    }
    
    private func drawLeafOutline(leafBase: CGPoint, withSize size: CGFloat, withOffset offset: CGFloat = 0) {
        let leafTip = CGPoint(x: leafBase.x + size, y: leafBase.y - size)
        let controlPoint1 = CGPoint(x: leafBase.x + size * 2 / 7, y: leafBase.y - size * 2 / 7)
        let controlPoint2 = CGPoint(x: leafBase.x + size * 4 / 7, y: leafBase.y - size * 4 / 7)
        let deformation = size * 2 / 7
        
        let leafOutline = UIBezierPath()
        leafOutline.move(to: CGPoint(x: leafBase.x - offset, y: leafBase.y + offset))
        leafOutline.addCurve(to: CGPoint(x: leafTip.x + offset, y: leafTip.y - offset), controlPoint1: CGPoint(x: controlPoint1.x - deformation - offset, y: controlPoint1.y - deformation - offset), controlPoint2: CGPoint(x: controlPoint2.x - deformation - offset, y: controlPoint2.y - deformation - offset))
        leafOutline.addCurve(to: CGPoint(x: leafBase.x - offset, y: leafBase.y + offset), controlPoint1: CGPoint(x: controlPoint2.x + deformation + offset, y: controlPoint2.y + deformation + offset), controlPoint2: CGPoint(x: controlPoint1.x + deformation + offset, y: controlPoint1.y + deformation + offset))
        leafOutline.close()
        leafOutline.fill()
    }
    
    func drawX(at point: CGPoint, size: CGFloat) {
        let projectedPoint = projection.project(point: point)
        context.setLineCap(.round)
        
        context.move(to: projectedPoint.applying(CGAffineTransform(translationX: -size, y: -size)))
        context.addLine(to: projectedPoint.applying(CGAffineTransform(translationX: size, y: size)))
        
        context.move(to: projectedPoint.applying(CGAffineTransform(translationX: -size, y: size)))
        context.addLine(to: projectedPoint.applying(CGAffineTransform(translationX: size, y: -size)))
        
        context.strokePath()
    }
    
    func finish(imageView: UIImageView, addToPreviousImage: Bool = false) {
        if addToPreviousImage {
            imageView.image?.draw(in: CGRect(origin: CGPoint.zero, size: canvasSize))
        }
        
        imageView.image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
    }
}
