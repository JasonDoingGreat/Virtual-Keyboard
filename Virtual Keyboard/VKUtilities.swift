//
//  VKUtilities.swift
//  Virtual Keyboard
//
//  Created by Zezhou Li on 1/5/17.
//  Copyright © 2017 Zezhou Li. All rights reserved.
//

import Foundation
import UIKit

func vk_dispatch_main(closure:@escaping ()->()) {
    DispatchQueue.main.async {
        closure()
    }
}
