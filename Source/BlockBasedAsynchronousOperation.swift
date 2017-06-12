//
//  BlockBasedAsynchronousOperation.swift
//  Pods
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 13/1/17.
//
//

import Foundation
import PromiseKit
import ReactiveSwift

/**
 An `BlockBasedAsynchronousOperation` is a subclass of `AsynchronousOperation` 
 wrapping a promise-return block in an asynchronous operation.
 
 Instances of this class have getters to retrieve the underlying promise which
 is wrapped in an additional promise to allow cancellation.
 */
open class BlockBasedAsynchronousOperation<ReturnType, ExecutionError>:
AsynchronousOperation<ReturnType, ExecutionError>
where ExecutionError: OperationError {
    
    /// Block that will be run when this operation is started.
    internal var block: ((Void) throws -> Promise<ReturnType>)! = nil
    
    /** 
     Initializes this asynchronous operation with a block which will return a
     tuple with a progress and a promise.
     
     - note: The block will be executed when the operation is executed by the
     operation queue it was enqueued in and not before.
     
     - note: Progress will be forwarded to this operation's progress.
     
     - parameter block: Block returning a progress and a promise.
     */
    public init(block: @escaping (Void) throws -> ProgressAndPromise<ReturnType>) {
        super.init()
        self.block = { [unowned self] in
            
            let progressAndPromise = try block()
            
            self.progress.totalUnitCount =
                progressAndPromise.progress.totalUnitCount
            self.progress.completedUnitCount =
                progressAndPromise.progress.completedUnitCount
            
            self.progress.reactive.totalUnitCount <~ progressAndPromise
                .progress.reactive.producer(
                    forKeyPath: #keyPath(Progress.totalUnitCount)
                )
                .map { $0 as? Int64 }
                .skipNil()
            
            self.progress.reactive.completedUnitCount <~ progressAndPromise
                .progress.reactive.producer(
                    forKeyPath: #keyPath(Progress.completedUnitCount)
                )
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
     
     - parameters:
       - progress: Optional progress tracking the block. If `nil` operation's 
         progress will remain the default one: a stalled progress with a total 
         count of 0 units.
       - block: Block returning a promise.
     */
    public init(
        progress: Progress? = nil,
        block: @escaping (Void) throws -> Promise<ReturnType>
    ) {
        self.block = block
        super.init(progress: progress)
    }
    
    open override func execute() throws {
        self.finish(waitingAndForwarding: try self.block())
    }
    
}
