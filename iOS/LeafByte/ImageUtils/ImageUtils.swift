//
//  ImageUtils.swift
//  LeafByte
//
//  Created by Adam Campbell on 1/5/18.
//  Copyright © 2018 The Blue Folder Project. All rights reserved.
//

import UIKit

func resizeImage(_ image: UIImage, within newBounds: CGSize) -> UIImage {
    // Check if resizing is necessary.
    if image.size.width <= newBounds.width && image.size.height <= newBounds.height {
        return image
    }
    
    // Find the resizing ratio that maintains the aspect ratio.
    let resizingRatioForWidth = newBounds.width / image.size.width
    let resizingRatioForHeight = newBounds.height / image.size.height
    let resizingRatio = min(resizingRatioForWidth, resizingRatioForHeight)
    
    let newSize = CGSize(width: image.size.width * resizingRatio, height: image.size.height * resizingRatio)
    
    let cgImage = uiToCgImage(image)
    
    let context = CGContext(
        data: nil,
        width: Int(newSize.width),
        height: Int(newSize.height),
        bitsPerComponent: cgImage.bitsPerComponent,
        bytesPerRow: 0,
        space: cgImage.colorSpace!,
        bitmapInfo: cgImage.bitmapInfo.rawValue)!
    context.interpolationQuality = .high
    context.draw(cgImage, in: CGRect(origin: CGPoint.zero, size: CGSize(width: newSize.width, height: newSize.height)))
    
    // TODO: I bet I can get away without this conversion
    return cgToUiImage(context.makeImage()!)
}

// Flood fills an image from a point ( https://en.wikipedia.org/wiki/Flood_fill ).
// Assumes that the starting point is "empty" (false) in the boolean image, and draws to the drawing manager.
func floodFill(image: BooleanIndexableImage, fromPoint startingPoint: CGPoint, drawingTo drawingManager: DrawingManager) {
    // This tracks what ranges are already filled in, mapping a y coordinate to a list of x ranges.
    var filledRanges = [Int: [(Int, Int)]]()
    // This is a list of points to fill from.
    var queue: Set<CGPoint> = [startingPoint]
    
    while !queue.isEmpty {
        // We're going to find the largest horizontal line containing this point that stays in the empty area.
        let point = queue.popFirst()!
        let x = Int(round(point.x))
        let y = Int(round(point.y))
        // If this point is already filled, we can truncate here.
        if isFilled(x: x, y: y, referringTo: filledRanges) {
            continue
        }
        
        // Check if the points above or below the point should be added to the queue.
        if y < image.height - 1 && !image.getPixel(x: x, y: y + 1) && !isFilled(x: x, y: y + 1, referringTo: filledRanges) {
            queue.insert(CGPoint(x: x, y: y + 1))
        }
        if y > 0 && !image.getPixel(x: x, y: y - 1) && !isFilled(x: x, y: y - 1, referringTo: filledRanges) {
            queue.insert(CGPoint(x: x, y: y - 1))
        }
        // As an optimization, as we move left and right, we only need to consider the above or below points for adding to the queue if we've passed a filled point.
        // This is because otherwise those points would be in the same line that has already been added to the queue above.
        // As such, we need to track eligibility for adding to the queue on both the north and south side.
        let initialEligibleForQueueNorth = y < image.height - 1 && image.getPixel(x: x, y: y + 1)
        let initialEligibleForQueueSouth = y > 0 && image.getPixel(x: x, y: y - 1)
        
        var leftmostX = x
        var eligibleForQueueNorth = initialEligibleForQueueNorth
        var eligibleForQueueSouth = initialEligibleForQueueSouth
        // Move left as far as possible.
        while leftmostX > 0 && !image.getPixel(x: leftmostX - 1, y: y) {
            leftmostX -= 1
            
            // Check if the northern pixel should be added to the queue, and update eligibility.
            if y < image.height - 1 {
                if image.getPixel(x: leftmostX, y: y + 1) {
                    eligibleForQueueNorth = true
                } else if eligibleForQueueNorth {
                    if !isFilled(x: leftmostX, y: y + 1, referringTo: filledRanges) {
                        queue.insert(CGPoint(x: leftmostX, y: y + 1))
                    }
                    eligibleForQueueNorth = false
                }
            }
            
            // Check if the southern pixel should be added to the queue, and update eligibility.
            if y > 0 {
                if image.getPixel(x: leftmostX, y: y - 1) {
                    eligibleForQueueSouth = true
                } else if eligibleForQueueSouth {
                    if !isFilled(x: leftmostX, y: y - 1, referringTo: filledRanges) {
                        queue.insert(CGPoint(x: leftmostX, y: y - 1))
                    }
                    eligibleForQueueSouth = false
                }
            }
        }

        var rightmostX = x
        eligibleForQueueNorth = initialEligibleForQueueNorth
        eligibleForQueueSouth = initialEligibleForQueueSouth
        // Move right as far as possible.
        while rightmostX < image.width - 1 && !image.getPixel(x: rightmostX + 1, y: y) {
            rightmostX += 1
            
            // Check if the northern pixel should be added to the queue, and update eligibility.
            if y < image.height - 1 {
                if image.getPixel(x: rightmostX, y: y + 1) {
                    eligibleForQueueNorth = true
                } else if eligibleForQueueNorth {
                    if !isFilled(x: rightmostX, y: y + 1, referringTo: filledRanges) {
                        queue.insert(CGPoint(x: rightmostX, y: y + 1))
                    }
                    eligibleForQueueNorth = false
                }
            }
            
            // Check if the southern pixel should be added to the queue, and update eligibility.
            if y > 0 {
                if image.getPixel(x: rightmostX, y: y - 1) {
                    eligibleForQueueSouth = true
                } else if eligibleForQueueSouth {
                    if !isFilled(x: rightmostX, y: y - 1, referringTo: filledRanges) {
                        queue.insert(CGPoint(x: rightmostX, y: y - 1))
                    }
                    eligibleForQueueSouth = false
                }
            }
        }
        
        // Draw the horizontal line from the leftmost clear point to the rightmost clear point.
        drawingManager.drawLine(from: CGPoint(x: leftmostX, y: y), to: CGPoint(x: rightmostX, y: y))
        
        // Mark the range as filled in so we don't come back to it.
        if filledRanges[y] != nil {
            filledRanges[y]!.append((leftmostX, rightmostX))
        } else {
            filledRanges[y] = [(leftmostX, rightmostX)]
        }
    }
}

private func isFilled(x: Int, y: Int, referringTo filledRanges: [Int: [(Int, Int)]]) -> Bool {
    let filledXRanges = filledRanges[y]
    if filledXRanges == nil {
        return false
    }
    
    return filledXRanges!.contains(where: { filledXRange in
        x >= filledXRange.0 && x <= filledXRange.1 })
}
