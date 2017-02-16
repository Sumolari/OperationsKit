/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 An extension to NSLock to simplify executing critical code.
 
 From Advanced NSOperations sample code in WWDC 2015 https://developer.apple.com/videos/play/wwdc2015/226/
 From https://developer.apple.com/sample-code/wwdc/2015/downloads/Advanced-NSOperations.zip
 */

import Foundation

extension NSLock {
    
    /**
     Runs given block as a critical section, ensuring that any other block run
     using this method will not start until the block is finished.
     
     - parameter block: Block to be run.
     
     - returns: Value returned by the block.
     */
    public func withCriticalScope<T>(block: (Void) -> T) -> T {
        lock()
        let value = block()
        unlock()
        return value
    }
    
}
