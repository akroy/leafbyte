//
//  ImageProcessing.swift
//  LeafByte
//
//  Created by Abigail Getman-Pickering on 1/4/18.
//  Copyright © 2018 Zoe Getman-Pickering. All rights reserved.
//

import Accelerate
import CoreGraphics

let NUMBER_OF_HISTOGRAM_BUCKETS = 256

// Turns an image into a histogram of luma, or intensity.
// The histogram is represented as an array with 256 buckets, each bucket containing the number of pixels in that range of intensity.
func getLumaHistogram(image: CGImage) -> [Int] {
    let pixelData = image.dataProvider!.data!
    var initialVImage = vImage_Buffer(
        data: UnsafeMutableRawPointer(mutating: CFDataGetBytePtr(pixelData)),
        height: vImagePixelCount(image.height),
        width: vImagePixelCount(image.width),
        rowBytes: image.bytesPerRow)
    
    // vImageMatrixMultiply_ARGB8888 operates in place, pixel-by-pixel, so it's sometimes possible to use the same vImage for input and output.
    // However, images from UIGraphicsGetImageFromCurrentImageContext, which is where the initial image comes from, are readonly.
    let mutableBuffer = CFDataCreateMutable(nil, image.bytesPerRow * image.height)
    var lumaVImage = vImage_Buffer(
        data: UnsafeMutableRawPointer(mutating: CFDataGetBytePtr(mutableBuffer)),
        height: vImagePixelCount(image.height),
        width: vImagePixelCount(image.width),
        rowBytes: image.bytesPerRow)
    
    // We're about to call vImageMatrixMultiply_ARGB8888, the best documentation of which I've found is in the SDK source: https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.7.sdk/System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vImage.framework/Versions/A/Headers/Transform.h#L21 .
    // Essentially each pixel in the image is a row vector [R, G, B, A] and is post-multiplied by a matrix to create a new transformed image.
    // Because luma = RGB * [.299, .587, .114]' ( https://en.wikipedia.org/wiki/YUV#Conversion_to/from_RGB ), we can use this multiplication to get a luma value for each pixel.
    // The following matrix will replace the first channel of each pixel (previously red) with luma, while zeroing everything else (since nothing else matters to us).
    let matrix: [Int16] = [ 299, 0, 0, 0,
                            587, 0, 0, 0,
                            114, 0, 0, 0,
                            0,   0, 0, 0 ]
    // Our matrix can only have integers, but this is accomodated for by having a post-divisor applied to the result of the multiplication.
    // As such, we're actually doing luma = RGB * [299, 587, 114]' / 1000 .
    let divisor: Int32 = 1000
    vImageMatrixMultiply_ARGB8888(&initialVImage, &lumaVImage, matrix, divisor, nil, nil, UInt32(kvImageNoFlags))
    
    // Now we're going to use vImageHistogramCalculation_ARGB8888 to get a histogram of each channel in our image.
    // Since luma is the only channel we care about (we zeroed the rest), we'll use a garbage array to catch the other histograms.
    let lumaHistogram = [UInt](repeating: 0, count: NUMBER_OF_HISTOGRAM_BUCKETS)
    let lumaHistogramPointer = UnsafeMutablePointer<vImagePixelCount>(mutating: lumaHistogram) as UnsafeMutablePointer<vImagePixelCount>?
    let garbageHistogram = [UInt](repeating: 0, count: NUMBER_OF_HISTOGRAM_BUCKETS)
    let garbageHistogramPointer = UnsafeMutablePointer<vImagePixelCount>(mutating: garbageHistogram) as UnsafeMutablePointer<vImagePixelCount>?
    let histogramArray = [lumaHistogramPointer, garbageHistogramPointer, garbageHistogramPointer, garbageHistogramPointer]
    let histogramArrayPointer = UnsafeMutablePointer<UnsafeMutablePointer<vImagePixelCount>?>(mutating: histogramArray)
    
    vImageHistogramCalculation_ARGB8888(&lumaVImage, histogramArrayPointer, UInt32(kvImageNoFlags))
    
    return lumaHistogram.map { Int($0) }
}

// Use Otsu's method, an algorithm that takes a histogram of intensities (that it assumes is roughly bimodal, corresponding to foreground and background) and tries to find the cut that separates the two modes ( https://en.wikipedia.org/wiki/Otsu%27s_method ).
// Note that this implementation is the optimized form that maximizes inter-class variance as opposed to minimizing intra-class variance (also described at the above link).
func otsusMethod(histogram: [Int]) -> Float {
    // The following equations and algorithm are taken from https://en.wikipedia.org/wiki/Otsu%27s_method#Otsu's_Method , and variable names here refer to variable names in equations there.
    
    // We can transform omega0 and mu0Numerator as we go through the loop. Both omega1 and mu1Numerator are easily derivable, since both omegas and muNumerators sum to constants.
    var omega0 = 0
    let sumOfOmegas = histogram.reduce(0, +)
    var mu0Numerator = 0
    // This calculates a dot product.
    let sumOfMuNumerators = zip(Array(0...NUMBER_OF_HISTOGRAM_BUCKETS - 1), histogram).reduce(0, { (accumulator, pair) in
        accumulator + (pair.0 * pair.1) })
    
    var maximumInterClassVariance = 0.0
    var bestCut = 0
    
    for index in 0...NUMBER_OF_HISTOGRAM_BUCKETS - 1 {
        omega0 = omega0 + histogram[index]
        let omega1 = sumOfOmegas - omega0
        if omega0 == 0 || omega1 == 0 {
            continue
        }
        
        mu0Numerator += index * histogram[index]
        let mu1Numerator = sumOfMuNumerators - mu0Numerator
        let mu0 = Double(mu0Numerator) / Double(omega0)
        let mu1 = Double(mu1Numerator) / Double(omega1)
        // Note that omega0 and omega1 are turned into Doubles before multiplying.
        // They were Ints and while Int has been equivalent to Int64 since iPad 4 and iPhone 5 (the first 64-bit devices), on older devices it was equivalent to Int32, and the multiplications would overflow ( https://en.wikipedia.org/wiki/Integer_overflow ).
        let interClassVariance = Double(omega0) * Double(omega1) * pow(mu0 - mu1, 2)
        
        if interClassVariance >= maximumInterClassVariance {
            maximumInterClassVariance = interClassVariance
            bestCut = index
        }
    }
    
    return Float(bestCut) / Float(NUMBER_OF_HISTOGRAM_BUCKETS - 1)
}

struct Size {
    var standardPart = 0
    var drawingPart = 0
    
    func total() -> Int {
        return standardPart + drawingPart
    }
    
    static func +=(left: inout Size, right: Size) {
        left.standardPart += right.standardPart
        left.drawingPart += right.drawingPart
    }
}

// This exists because Swift doesn't let you use structs like (Int, Int) as keys in a dictionary.
struct PointToIdentify: Hashable {
    let x: Int
    let y: Int
    
    init(_ point: (Int, Int)) {
        self.init(x: point.0, y: point.1)
    }
    
    init(_ point: CGPoint) {
        self.init(x: roundToInt(point.x), y: roundToInt(point.y))
    }
    
    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

struct ConnectedComponentsInfo {
    let labelToMemberPoint: [Int: (Int, Int)]
    let emptyLabelToNeighboringOccupiedLabels: [Int: Set<Int>]
    let labelToSize: [Int: Size]
    let equivalenceClasses: UnionFind
    let labelsOfPointsToIdentify: [PointToIdentify: Int]
    
    init(labelToMemberPoint: [Int: (Int, Int)], emptyLabelToNeighboringOccupiedLabels: [Int: Set<Int>], labelToSize: [Int: Size], equivalenceClasses: UnionFind, labelsOfPointsToIdentify: [PointToIdentify: Int]) {
        self.labelToMemberPoint = labelToMemberPoint
        self.emptyLabelToNeighboringOccupiedLabels = emptyLabelToNeighboringOccupiedLabels
        self.labelToSize = labelToSize
        self.equivalenceClasses = equivalenceClasses
        self.labelsOfPointsToIdentify = labelsOfPointsToIdentify
    }
}

let BACKGROUND_LABEL = -1

// Find all the connected components in an image, that is the contiguous areas that are the same ( https://en.wikipedia.org/wiki/Connected-component_labeling ).
// "Occupied" refers to "true" values in the image, and "empty" refers to "false" values in the image.
// E.g. the leaf and scale mark will be occupied connected components, while the holes in the leaf will be "empty" connected components.
// It is assumed that the input layered image will have the main leaf in the 0th spot and, if present, the user drawing in the 1st spot.
// If pointToIdentify is passed in, the label of that point will be returned.
func labelConnectedComponents(image: LayeredIndexableImage, pointsToIdentify: [PointToIdentify] = []) -> ConnectedComponentsInfo {
    let width = image.width
    let height = image.height
    
    // Initialize most structures we'll eventually be returning.
    // Maps a label to a point in that component, allowing us to reconstruct the component later.
    var labelToMemberPoint = [Int: (Int, Int)]()
    // Tells what occupied components surround any empty component.
    var emptyLabelToNeighboringOccupiedLabels = [Int: Set<Int>]()
    // Tells the size of each component.
    var labelToSize = [Int: Size]()
    // A data structure to track what labels actually correspond to the same component (because of the way the algorithm runs, a single blob might get partially marked with one label and partially with another).
    let equivalenceClasses = UnionFind()
    
    // Negative labels will refer to empty components; positive will refer to occupied components.
    // Track what labels to give out next as we create new groups.
    var nextOccupiedLabel = 1
    var nextEmptyLabel = -2
    
    // Use -1 as a special label for the area outside the image.
    equivalenceClasses.createSubsetWith(BACKGROUND_LABEL)
    emptyLabelToNeighboringOccupiedLabels[BACKGROUND_LABEL] = []
    labelToSize[BACKGROUND_LABEL] = Size()
    
    // As an optimization (speeds this loop up by 40%), save off the isOccupied and label values for the previous y layer for the next loop through.
    var previousYIsOccupied: [Bool]!
    var previousYLabels: [Int]!
    
    // The labels of any points to identify will be saved.
    // This is indexed in this direction to simplify the process of consolidating equivalent labels later.
    var labelsToPointsToIdentify = [Int: [PointToIdentify]]()
    
    // Index the pointsToIdentify by their y coordinate to associated x coordinates, to make it easier to identify which rows contain points to identify.
    var pointsToIdentifyYsToXs = [Int: [Int]]()
    for pointToIdentify in pointsToIdentify {
        if pointsToIdentifyYsToXs[pointToIdentify.y] == nil {
            pointsToIdentifyYsToXs[pointToIdentify.y] = [ pointToIdentify.x ]
        } else {
            // Due to strange behavior in Swift 4 (this will change in Swift 5), we can't directly append to a list in a dictionary ( https://stackoverflow.com/a/24535563/1092672 ).
            var pointsToIdentifyXsForY = pointsToIdentifyYsToXs[pointToIdentify.y]!
            pointsToIdentifyXsForY.append(pointToIdentify.x)
            pointsToIdentifyYsToXs[pointToIdentify.y] = pointsToIdentifyXsForY
        }
    }
    
    for y in 0...height - 1 {
        var currentYIsOccupied = [Bool]()
        currentYIsOccupied.reserveCapacity(width)
        
        var currentYLabels = [Int]()
        currentYLabels.reserveCapacity(width)
        
        // As an optimization (speeds this loop up by another 40%), save off the isOccupied and label value for the previous x for the next loop through.
        var previousXIsOccupied: Bool!
        var previousXLabel: Int!
        for x in 0...width - 1 {
            let layerWithPixel = image.getLayerWithPixel(x: x, y: y)
            let isOccupied = layerWithPixel > -1
            currentYIsOccupied.append(isOccupied)
            
            // Check the pixel's neighbors.
            // Note that we're using 4-connectivity ( https://en.wikipedia.org/wiki/Pixel_connectivity ) for speed.
            // Because we've only set the label for pixels we've already iterated over, we only need to check west and north.
            var westIsOccupied: Bool?
            var westLabel: Int?
            if x > 0 {
                westIsOccupied = previousXIsOccupied
                westLabel = previousXLabel
            }
            previousXIsOccupied = isOccupied
            var northIsOccupied: Bool?
            var northLabel: Int?
            if y > 0 {
                northIsOccupied = previousYIsOccupied[x]
                northLabel = previousYLabels[x]
            }
            
            // Determine what label this pixel should have.
            var label: Int!
            if isOccupied == westIsOccupied {
                label = westLabel
                
                // If this pixel matches the west and north, those two ought to be equivalent.
                if isOccupied == northIsOccupied {
                    equivalenceClasses.combineClassesContaining(westLabel!, and: northLabel!)
                }
            } else if isOccupied == northIsOccupied {
                label = northLabel!
            } else {
                // If this pixel matches neither, it's part of a new component.
                if isOccupied {
                    label = nextOccupiedLabel
                    nextOccupiedLabel += 1
                } else {
                    label = nextEmptyLabel
                    nextEmptyLabel -= 1
                }
                
                // Initialize the new label.
                labelToMemberPoint[label] = (x, y)
                emptyLabelToNeighboringOccupiedLabels[label] = []
                labelToSize[label] = Size()
                equivalenceClasses.createSubsetWith(label)
            }
            
            // Increment size.
            // If the pixel was on the 1st layer, it's the user drawing.
            // If on the 0th layer, it's the main leaf.
            // If -1, it was unoccupied.
            if layerWithPixel == 1 {
                labelToSize[label]!.drawingPart += 1
            } else {
                labelToSize[label]!.standardPart += 1
            }
            
            // Update the neighbor map if we have neighboring occupied and empty.
            if isOccupied {
                // Note that these are explicit checks rather just "if !westIsOccupied {", because these values are optional.
                if westIsOccupied == false {
                    emptyLabelToNeighboringOccupiedLabels[westLabel!]!.insert(label)
                }
                if northIsOccupied == false {
                    emptyLabelToNeighboringOccupiedLabels[northLabel!]!.insert(label)
                }
            } else {
                if westIsOccupied == true {
                    emptyLabelToNeighboringOccupiedLabels[label]!.insert(westLabel!)
                }
                if northIsOccupied == true {
                    emptyLabelToNeighboringOccupiedLabels[label]!.insert(northLabel!)
                }
            }

            // Any empty pixels on the edge of the image are part of the "outside of the image" component.
            if !isOccupied && (y == 0 || x == 0 || y == height - 1 || x == width - 1) {
                equivalenceClasses.combineClassesContaining(label, and: BACKGROUND_LABEL)
            }
            
            previousXLabel = label
            currentYLabels.append(label)
        }
        
        // Check if this y row has any associated points to identify.
        let pointsToIdentifyXs = pointsToIdentifyYsToXs[y]
        if pointsToIdentifyXs != nil {
            for pointToIdentifyX in pointsToIdentifyXs! {
                // For each associated point to identify, record the association between the point and label.
                let label = currentYLabels[pointToIdentifyX]
                let point = PointToIdentify(x: pointToIdentifyX, y: y)
                if labelsToPointsToIdentify[label] == nil {
                    labelsToPointsToIdentify[label] = [ point ]
                } else {
                    // Due to strange behavior in Swift 4 (this will change in Swift 5), we can't directly append to a list in a dictionary ( https://stackoverflow.com/a/24535563/1092672 ).
                    var pointsForLabel = labelsToPointsToIdentify[label]!
                    pointsForLabel.append(point)
                    labelsToPointsToIdentify[label] = pointsForLabel
                }
            }
        }
        
        previousYIsOccupied = currentYIsOccupied
        previousYLabels = currentYLabels
    }
    
    // -1, the label for the outside of the image, has a fake member point.
    // Let's fix that so it can't break any code that uses the result of this function.
    let outsideOfImageClass = equivalenceClasses.getClassOf(BACKGROUND_LABEL)!
    let outsideOfImageClassElement = equivalenceClasses.classToElements[outsideOfImageClass]!.first(where: { $0 != BACKGROUND_LABEL })
    if outsideOfImageClassElement != nil {
        labelToMemberPoint[BACKGROUND_LABEL] = labelToMemberPoint[outsideOfImageClassElement!]
    } else {
        // -1 is in a class of it's own.
        // This means it's useless, so remove it.
        labelToMemberPoint[BACKGROUND_LABEL] = nil
        emptyLabelToNeighboringOccupiedLabels[BACKGROUND_LABEL] = nil
        labelToSize[BACKGROUND_LABEL] = nil
        equivalenceClasses.classToElements[outsideOfImageClass] = nil
    }
    
    // Update the labels of the points to identify as labels are consolidated.
    var labelsOfPointsToIdentify = [PointToIdentify: Int]()
    
    // "Normalize" by combining equivalent labels.
    for equivalenceClassElements in equivalenceClasses.classToElements.values {
        // Because we take the max, the background class will use -1.
        let representative = equivalenceClassElements.max()!
        
        // Make the member point be the top-most member point in the equivalence.
        // That way the leaf marker is drawn in a place less likely to overlap the leaf.
        let topMostMemberPoint = equivalenceClassElements
            .map({ labelToMemberPoint[$0]! })
            .sorted(by: { $0.1 < $1.1 })[0]
        labelToMemberPoint[representative] = topMostMemberPoint
        
        // Do an initial loop-through including the first element of the class.
        equivalenceClassElements.forEach { label in
            // The label of the point to identify would now be obsolete, so save off the new canonical label.
            if labelsToPointsToIdentify[label] != nil {
                for point in labelsToPointsToIdentify[label]! {
                    labelsOfPointsToIdentify[point] = representative
                }
            }
        }
        
        // Do a second loop-through without the representative element of the class.
        equivalenceClassElements.filter { $0 != representative }.forEach { label in
            // Normalize labelToSize.
            labelToSize[representative]! += labelToSize[label]!
            labelToSize[label] = nil
            
            // Normalize emptyLabelToNeighboringOccupiedLabels.
            emptyLabelToNeighboringOccupiedLabels[representative]!.formUnion(emptyLabelToNeighboringOccupiedLabels[label]!)
            emptyLabelToNeighboringOccupiedLabels[label] = nil
        }
    }
    
    return ConnectedComponentsInfo(
        labelToMemberPoint: labelToMemberPoint,
        emptyLabelToNeighboringOccupiedLabels: emptyLabelToNeighboringOccupiedLabels,
        labelToSize: labelToSize,
        equivalenceClasses: equivalenceClasses,
        labelsOfPointsToIdentify: labelsOfPointsToIdentify)
}
