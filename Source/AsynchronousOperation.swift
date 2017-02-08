//
//  AsynchronousOperation.swift
//  OperationsKit
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 10/12/16.
//
//

import Foundation
import PromiseKit
import ReactiveCocoa

/**
 Common errors to be throw by any kind of asynchronous operation.
 
 - cancelled: The operation was cancelled.
 */
public enum AsynchronousOperationCommonError: Error {
    case cancelled
}

/**
 An `AsynchronousOperation` is a subclass of `NSOperation` wrapping a promise
 based asynchronous operation.
 
 Instances of this class are initialized given a block that takes no parameters
 and returns a promise. When the promise is resolved the operation is finished.
 
 Instances of this class have getters to retrieve the underlying promise which
 is wrapped in an additional promise to allow cancellation.
 */
open class AsynchronousOperation<ReturnType>: Operation {
    
    /// Progress of this operation, optional.
    open internal(set) var progress: Progress? = nil
    
    /// Promise wrapping underlying promise returned by block.
    open fileprivate(set) var promise: Promise<ReturnType>! = nil
    
    /// Block to `fulfill` public promise.
    fileprivate var fulfillPromise: ((ReturnType) -> Void)! = nil
    
    /// Block to `reject` public promise, used when cancelling the operation or
    /// forwarding underlying promise errors.
    fileprivate var rejectPromise: ((Error) -> Void)! = nil
    
    /// Lock used to prevent race conditions when changing internal state
    /// (`isExecuting`, `isFinished`).
    fileprivate let stateLock = NSLock()
    
    /// Date when this operation started.
    open fileprivate(set) var startDate: Date? = nil
    
    /// Date when this operation ended.
    open fileprivate(set) var endDate: Date? = nil
    
    /// Time interval ellapsed to complete this operation.
    open var executionDuration: TimeInterval? {
        guard let start = self.startDate else { return nil }
        return self.endDate?.timeIntervalSince(start)
    }
    
    /**
     Internal attribute used to store whether this operation is executing or 
     not.
    
     - note: This attribute is **not** thread safe and should not be used
     directly. Use `isExecuting` attribute instead.
     */
    fileprivate var _executing: Bool = false
    override fileprivate(set) open var isExecuting: Bool {
        get {
            return self.stateLock.withCriticalScope { self._executing }
        }
        set {
            willChangeValue(forKey: "isExecuting")
            
            self.stateLock.withCriticalScope {
                
                if self._executing != newValue {
                    
                    self._executing = newValue
                    
                    if newValue {
                        self.startDate = Date()
                    } else {
                        self.endDate = Date()
                    }
                    
                }
                
            }
            
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    /**
     Internal attribute used to store whether this operation is finished or
     not.
     
     - note: This attribute is **not** thread safe and should not be used
     directly. Use `isFinished` attribute instead.
     */
    private var _finished: Bool = false
    override fileprivate(set) open var isFinished: Bool {
        get {
            return self.stateLock.withCriticalScope { self._finished }
        }
        set {
            willChangeValue(forKey: "isFinished")
            
            self.stateLock.withCriticalScope {
                if self._finished != newValue {
                    self._finished = newValue
                }
            }
            
            didChangeValue(forKey: "isFinished")
        }
    }
    
    public override init() {
        super.init()
        self.progress = Progress(totalUnitCount: 1)
        self.promise = Promise<ReturnType>() {
            [unowned self] fullfill, reject in
            self.fulfillPromise = fullfill
            self.rejectPromise = reject
        }
    }
    
    public init(progress: Progress? = nil) {
        super.init()
        self.progress = progress
        self.promise = Promise<ReturnType>() {
            [unowned self] fullfill, reject in
            self.fulfillPromise = fullfill
            self.rejectPromise = reject
        }
    }
    
    open override func main() {
        self.isExecuting = true
    }
    
    open override func cancel() {
        super.cancel()
        self.finish(error: AsynchronousOperationCommonError.cancelled)
    }
    
    /// Changes internal state to reflect that this operation has either 
    /// finished or been cancelled but does not resolve underlying promise.
    public func markAsFinished() {
        self.isExecuting = false
        self.isFinished = true
    }
    
    /**
     You should call this method when your operation successfully finishes.
     
     - note: Changes internal state to reflect that his operation has been 
     finished and fulfills underlying promise, returning given value back to 
     chained ones.
     
     - parameter returnValue: Value to be used to fulfill promise.
     */
    public func finish(_ returnValue: ReturnType) {
        self.markAsFinished()
        self.fulfillPromise(returnValue)
    }
    
    /**
     You should call this method when your operation finishes with an error.
     
     - note: Changes internal state to reflect that his operation has failed and
     rejects underlying promise, throwing given error back to chained promises.
     
     - parameter error: Error to be thrown back.
     */
    public func finish(error: Error) {
        self.markAsFinished()
        self.rejectPromise(error)
    }
    
    open override var isConcurrent: Bool {
        get {
            return true
        }
    }
    
    open override var isAsynchronous: Bool {
        get {
            return true
        }
    }
    
}
