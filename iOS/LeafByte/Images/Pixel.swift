//
//  Pixel.swift
//  LeafByte
//
//  Created by Abigail Getman-Pickering on 1/4/18.
//  Copyright © 2018 Zoe Getman-Pickering. All rights reserved.
//

// A representation of a single pixel.
struct Pixel: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
    
    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    func isVisible() -> Bool {
        return self.alpha != 0
    }
    
    func isInvisible() -> Bool {
        return self.alpha == 0
    }
    
    // MARK: Equatable overrides
    
    static func == (lhs: Pixel, rhs: Pixel) -> Bool {
        return lhs.red == rhs.red
            && lhs.green == rhs.green
            && lhs.blue == rhs.blue
            && lhs.alpha == rhs.alpha
    }
}
