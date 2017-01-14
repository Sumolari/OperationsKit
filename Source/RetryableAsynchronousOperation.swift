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
 Common errors to be throw by any kind of retryable asynchronous operation.
 
 - reachedRetryLimit: The operation reached its maximum retry limit.
 */
public enum RetryableOperationCommonError: Error {
    case reachedRetryLimit
}

/**
 A `RetryableAsynchronousOperation` is a subclass of `AsynchronousOperation` 
 that will retry an operation until it succeeds or a limit is reached.
 */
open class RetryableAsynchronousOperation<ReturnType>: AsynchronousOperation<ReturnType> {

    /// Maximum amount of times the operation will be retried before giving up.
    open private(set) var maximumAttempts: UInt64
    
    /// Current amount of times the operation has been repeated.
    open private(set) var attempts: UInt64 = 0
    
    public init(maximumAttempts: UInt64 = 1) {
        self.maximumAttempts = maximumAttempts
        super.init()
    }
    
    open override func main() {
        
        super.main()
        
        guard self.attempts <= self.maximumAttempts else {
            self.finish()
            return self.rejectPromise(
                RetryableOperationCommonError.reachedRetryLimit
            )
        }
        
        self.attempts += 1
        
    }
    
}
