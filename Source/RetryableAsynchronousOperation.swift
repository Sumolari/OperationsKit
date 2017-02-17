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
    
    public static func Unknown(_ error: Swift.Error) -> BaseRetryableOperationError {
        return .unknown(error)
    }
    
    public static var ReachedRetryLimit: BaseRetryableOperationError {
        return .reachedRetryLimit
    }
    
    case cancelled
    case unknown(Swift.Error)
    case reachedRetryLimit
    
}

/**
 A `RetryableAsynchronousOperation` is a subclass of `AsynchronousOperation` 
 that will retry the operation until it succeeds or a limit is reached.
 
 Your `execute()` method should call `retry(dueTo:)` method when a recoverable
 error is thrown. If your `execute` method throws an error the operation will
 finish immediately.
 */
open class RetryableAsynchronousOperation<ReturnType, ExecutionError>:
AsynchronousOperation<ReturnType, ExecutionError>
where ExecutionError: RetryableOperationError {

    /// Maximum amount of times the operation will be retried before giving up.
    open private(set) var maximumAttempts: UInt64
    
    /// Current amount of times the operation has been repeated.
    open private(set) var attempts: UInt64 = 0
    
    public init(maximumAttempts: UInt64 = 1) {
        self.maximumAttempts = maximumAttempts
        super.init()
    }
    
    /**
     Retries this operation. Your subclasss must call this method when a 
     recoverable error arises.
     
     - warning: Do not call `execute()` inside `execute()` method as it might
     cause an infinite recursion loop. Call `retry()` method instead.
     
     - note: This method will take into account `isCancelled` attribute, 
     finishing the operation when it might be retried but was manually 
     cancelled.
     
     - note: When no `error` is given or giving `nil` if this operation reaches
     its maximum attempts count a `ExecutionError.ReachedRetryLimit` will be
     passed back.
     
     - parameter error: Recoverable error that was throw. When not `nil` and 
     maximum attempts are reached this is the error that will be passed back.
     */
    open func retry(dueTo error: Swift.Error? = nil) {
        
        guard !self.isCancelled else { return }
        
        guard self.attempts < self.maximumAttempts else {
            return self.finish(error: error ?? ExecutionError.ReachedRetryLimit)
        }
        
        self.attempts += 1
        
        do {
            try self.execute()
        } catch let error {
            self.finish(error: error)
        }
        
    }
    
}
