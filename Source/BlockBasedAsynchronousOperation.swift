//
//  BlockBasedAsynchronousOperation.swift
//  Pods
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 13/1/17.
//
//

import Foundation
import PromiseKit
import ReactiveCocoa

/**
 An `AsynchronousOperation` is a subclass of `NSOperation` wrapping a promise
 based asynchronous operation.
 
 Instances of this class are initialized given a block that takes no parameters
 and returns a promise. When the promise is resolved the operation is finished.
 
 Instances of this class have getters to retrieve the underlying promise which
 is wrapped in an additional promise to allow cancellation.
 */
open class BlockBasedAsynchronousOperation<ReturnType, ExecutionError>: AsynchronousOperation<ReturnType, ExecutionError>
where ExecutionError: OperationError {
    
    /// Block that will be run when this operation is started.
    internal var block: ((Void) -> Promise<ReturnType>)! = nil
    
    public init(block: @escaping (Void) -> ProgressAndPromise<ReturnType>) {
        super.init()
        self.block = { [weak self] in
            
            let progress = self?.progress
            
            let progressAndPromise = block()
            progress?.totalUnitCount =
                progressAndPromise.progress.totalUnitCount
            
            progressAndPromise.progress.reactive
                .values(forKeyPath: "completedUnitCount")
                .start { event in
                    
                    switch event {
                    case .completed, .failed(_), .interrupted:
                        if let cuc = progress?.totalUnitCount {
                            progress?.completedUnitCount = cuc
                        }
                    case .value(let optionalValue):
                        guard let value = optionalValue as? Int64 else { return }
                        progress?.completedUnitCount = value
                    }
                    
            }
            
            return progressAndPromise.promise
        }
    }
    
    public init(
        progress: Progress? = nil,
        block: @escaping (Void) -> Promise<ReturnType>
    ) {
        super.init()
        self.block = block
        self.progress = progress
    }
    
    open override func main() {
        super.main()
        self.block()
            .then { result -> Void in self.finish(result) }
            .then { self.completionBlock?() }
            .catch { error in self.finish(error: ExecutionError.wrap(error)) }
    }
    
}
