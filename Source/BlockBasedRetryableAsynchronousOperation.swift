//
//  BlockBasedRetryableAsynchronousOperation.swift
//  Pods
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 13/1/17.
//
//

import Foundation
import PromiseKit

/**
 A `RetryableAsynchronousOperation` is a subclass of `AsynchronousOperation`
 that will retry an operation until it succeeds or a limit is reached.
 */
open class BlockBasedRetryableAsynchronousOperation<ReturnType, ExecutionError>:
RetryableAsynchronousOperation<ReturnType, ExecutionError>
where ExecutionError: RetryableOperationError {
    
    /// Block that will be run when this operation is started.
    internal var block: ((Void) -> Promise<ReturnType>)! = nil
    
    public init(
        maximumAttempts: UInt64 = 1,
        block: @escaping (Void) -> ProgressAndPromise<ReturnType>
    ) {
        super.init(maximumAttempts: maximumAttempts)
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
        maximumAttempts: UInt64 = 1,
        progress: Progress? = nil,
        block: @escaping (Void) -> Promise<ReturnType>
    ) {
        super.init(maximumAttempts: maximumAttempts)
        self.block = block
        self.progress = progress
    }
    
    open override func main() {
        
        super.main()
        
        self.block()
            .then { result -> Void in self.finish(result) }
            .catch { _ in
                
                guard self.attempts <= self.maximumAttempts else {
                    return self.finish(error: ExecutionError.ReachedRetryLimit)
                }
                
                self.main()
        
            }
        
    }
    
}
