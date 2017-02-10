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
 Common errors that may be thrown by any kind of retryable asynchronous 
 operation.
 */
public protocol RetryableOperationError: OperationError {
    
    /// Operation reached its retry limit without success.
    static var ReachedRetryLimit: Self { get }
    
}

/**
 Common errors that may be throw by any kind of asynchronous operation.
 
 - canceled:          The operation was cancelled.
 - unknown:           The operation failed due to an unknown error.
 - reachedRetryLimit: Operation reached its retry limit without success.
 */
public enum BaseRetryableOperationError: RetryableOperationError {
    
    public static var Cancelled: BaseRetryableOperationError {
        return .cancelled
    }
    
    public static var Unknown: BaseRetryableOperationError {
        return .unknown
    }
    
    public static var ReachedRetryLimit: BaseRetryableOperationError {
        return .reachedRetryLimit
    }
    
    case cancelled
    case unknown
    case reachedRetryLimit
    
}

/**
 A `RetryableAsynchronousOperation` is a subclass of `AsynchronousOperation` 
 that will retry an operation until it succeeds or a limit is reached.
 */
open class RetryableAsynchronousOperation<ReturnType, ExecutionError>: AsynchronousOperation<ReturnType, ExecutionError>
where ExecutionError: RetryableOperationError {

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
            return self.finish(error: ExecutionError.ReachedRetryLimit)
        }
        
        self.attempts += 1
        
    }
    
}
