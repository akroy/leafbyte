//
//  UIStoryboardUnwindSegueFromRight.swift
//  LeafByte
//
//  Created by Adam Campbell on 12/23/17.
//  Copyright © 2017 The Blue Folder Project. All rights reserved.
//

import UIKit

class UIStoryboardUnwindSegueFromRight: UIStoryboardSegue {
    
    override func perform()
    {
        let src = self.source as UIViewController
        let dst = self.destination as UIViewController
        
        src.view.superview?.insertSubview(dst.view, belowSubview: src.view)
        src.view.transform = CGAffineTransform.init(translationX: 0, y: 0)
        
        UIView.animate(withDuration: 0.25,
                                   delay: 0.0,
                                   options: [],
                                   animations: {
                                    src.view.transform = CGAffineTransform.init(translationX: src.view.frame.size.width, y: 0)
        },
                                   completion: { finished in
                                    src.dismiss(animated: false, completion: nil)
        }
        )
    }
}