//
//  BlockBasedRetryableAsynchronousOperation.swift
//  Pods
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 13/1/17.
//
//

import Foundation
import PromiseKit
import ReactiveSwift

/**
 A `BlockBasedRetryableAsynchronousOperation` is a subclass of 
 `RetryableAsynchronousOperation` that will retry an operation until it succeeds
 or a limit is reached.
 */
open class BlockBasedRetryableAsynchronousOperation<ReturnType, ExecutionError>:
RetryableAsynchronousOperation<ReturnType, ExecutionError>
where ExecutionError: RetryableOperationError {
    
    /// Block that will be run when this operation is started.
    internal var block: ((Void) throws -> Promise<ReturnType>)! = nil
    
    /// Progress returned by a progress-and-promise tuple, to hold a strong
    /// reference to it and prevent it from being deallocated too soon.
    fileprivate var progressAndPromiseProgress: Progress? = nil
    
    /**
     Initializes this asynchronous operation with a block which will return a
     tuple with a progress and a promise.
     
     - note: The block will be executed when the operation is executed by the
     operation queue it was enqueued in and not before.
     
     - warning: If given `block` throws an error the operation won't be retried.
     
     - note: Progress will be forwarded to this operation's progress.
     
     - parameter maximumAttempts: Maximum amount of times block will be run
     until giving up.
     - parameter block: Block returning a progress and a promise.
     */
    public init(
        maximumAttempts: UInt64 = 1,
        block: @escaping (Void) throws -> ProgressAndPromise<ReturnType>
    ) {
        super.init(maximumAttempts: maximumAttempts)
        self.block = { [unowned self] in
            
            let progressAndPromise = try block()
            
            self.progress.totalUnitCount =
                progressAndPromise.progress.totalUnitCount
            
            self.progress.completedUnitCount =
                progressAndPromise.progress.completedUnitCount
            
            self.progressAndPromiseProgress = progressAndPromise.progress
            
            self.progress.reactive.totalUnitCount <~ progressAndPromise
                .progress.reactive.producer(
                    forKeyPath: #keyPath(Progress.totalUnitCount)
                )
                .take(during: self.lifetime)
                .map { $0 as? Int64 }
                .skipNil()
            
            self.progress.reactive.completedUnitCount <~ progressAndPromise
                .progress.reactive.producer(
                    forKeyPath: #keyPath(Progress.completedUnitCount)
                )
                .take(during: self.lifetime)
                .map { $0 as? Int64 }
                .skipNil()
            
            return progressAndPromise.promise

        }
    }
    
    /**
     Initializes this asynchronous operation with a block which will return a
     promise and an optional progress tracking the block.
     
     - note: The block will be executed when the operation is executed by the
     operation queue it was enqueued in and not before.
     
     - parameter maximumAttempts: Maximum amount of times block will be run
     until giving up.
     - parameter progress: Optional progress tracking the block. If
     `nil` operation's progress will remain the default one: a stalled progress
     with a total count of 0 units.
     - parameter block: Block returning a promise.
     */
    public init(
        maximumAttempts: UInt64 = 1,
        progress: Progress? = nil,
        block: @escaping (Void) throws -> Promise<ReturnType>
    ) {
        self.block = block
        super.init(maximumAttempts: maximumAttempts, progress: progress)
    }
    
    open override func execute() throws {
        try self.block()
            .then { self.finish($0) }
            .catch { self.retry(dueTo: $0) }
    }
    
}
