//
//  RetryableAsynchronousOperation.swift
//  Pods
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 11/12/16.
//
//

import Foundation
import PromiseKit

/**
 A `RetryableAsynchronousOperation` is a subclass of `AsynchronousOperation` 
 that will retry an operation until it succeeds or a limit is reached.
 */
open class RetryableAsynchronousOperation<ReturnType>: AsynchronousOperation<ReturnType> {

    /// Maximum amount of times the operation will be retried before giving up.
    open private(set) var maximumAttempts: UInt64
    
    /// Current amount of times the operation has been repeated.
    open private(set) var attempts: UInt64 = 0
    
    public init(
        maximumAttempts: UInt64 = 1,
        block: @escaping (Void) -> ProgressAndPromise<ReturnType>
    ) {
        self.maximumAttempts = maximumAttempts
        super.init(block: block)
    }
    
    public init(
        maximumAttempts: UInt64 = 1,
        progress: Progress? = nil,
        block: @escaping (Void) -> Promise<ReturnType>
    ) {
        self.maximumAttempts = maximumAttempts
        super.init(progress: progress, block: block)
    }
    
    open override func main() {
        
        self.block()
            .then { result -> Void in self.fulfillPromise(result) }
            .then { self.completionBlock?() }
            .catch { error in
                guard self.attempts < self.maximumAttempts else {
                    return self.rejectPromise(error)
                }
                self.attempts += 1
                self.main()
            }
        
    }
    
}
