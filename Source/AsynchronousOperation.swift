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
import enum Result.Result

// MARK: - Protocols

public protocol WrappableError: Swift.Error {
    
    /**
     Wraps given error, returning an instance of this type if original error
     was one or an `Unknown` error if it wasn't.
     
     - parameter error: Error to be wrapped.
     
     - returns: Proper instance of this type for given error.
     */
    static func wrap(_ error: Swift.Error) -> Self
    
    /**
     Unwraps underlying error, returning a Swift error.
     
     - returns: Underlyting error unwrapped.
     */
    func unwrap() -> Swift.Error
    
}

/**
 Common errors that may be throw by any kind of asynchronous operation.
 */
public protocol OperationError: WrappableError {
    
    /// The operation was cancelled.
    static var Cancelled: Self { get }
    
    /**
     Error to be returned when the operation failes with given unknown error.
     
     - parameter error: Unknown error which made the operation fail.
     
     - returns: Properly wrapped known error.
     */
    static func Unknown(_ error: Swift.Error) -> Self
    
}

extension OperationError {
    
    public static func wrap(_ error: Swift.Error) -> Self {
        guard let knownError = error as? Self else { return Self.Unknown(error) }
        return knownError
    }
    
}

// MARK: - Base errors

/**
 Common errors that may be throw by any kind of asynchronous operation.
 
 - canceled: The operation was cancelled.
 - unknown:  The operation failed due to given unknown error.
 */
public enum BaseOperationError: OperationError {
    
    public static var Cancelled: BaseOperationError { return .cancelled }
    public static func Unknown(_ error: Swift.Error) -> BaseOperationError {
        return .unknown(error)
    }

    case cancelled
    case unknown(Swift.Error)
    
    public func unwrap() -> Swift.Error {
        
        switch self {
        case .unknown(let error):
            
            if let wrappableError = error as? WrappableError {
                return wrappableError.unwrap()
            } else {
                return error
            }
            
        default:
            return self
            
        }
        
    }
    
}

// MARK: - Status

/**
 Possible states in which an operation can be.
 
 - pending: Operation is waiting for some dependencies to finish before it can
 be started.
 - ready: Operation is ready to be executed but is not running yet.
 - executing: Operation is currently being executed.
 - cancelled: Operation was cancelled and it isn't running any more.
 - finishing: Operation was executed successfully but children operations are
 running and must finish before this operation can fulfill its promise.
 - finished: Operation and its children finished.
 */
public enum OperationStatus {
    case pending
    case ready
    case executing
    case cancelled
    case finishing
    case finished
}

// MARK: - Base asynchronous operation

/**
 An `AsynchronousOperation` is a subclass of `Operation` wrapping a promise 
 based asynchronous operation.
 */
open class AsynchronousOperation<ReturnType, ExecutionError>: Operation
where ExecutionError: OperationError {
    
    // MARK: Attributes
    
    /// Progress of this operation.
    open let progress: Progress
    
    /// Promise wrapping underlying promise returned by block.
    open let promise: Promise<ReturnType>
    
    /// Block to `fulfill` public promise.
    fileprivate let fulfillPromise: ((ReturnType) -> Void)
    
    /// Block to `reject` public promise, used when cancelling the operation or
    /// forwarding underlying promise errors.
    fileprivate let rejectPromise: ((Error) -> Void)
    
    /// Lock used to prevent race conditions when changing internal state
    /// (`isExecuting`, `isFinished`).
    fileprivate let stateLock = NSLock()
    
    /// Return value of this operation. Will be `nil` until operation finishes
    /// or when there's an error.
    open fileprivate(set) var result: Result<ReturnType, ExecutionError>? = nil
    
    /// Date when this operation started.
    open fileprivate(set) var startDate: Date? = nil
    
    /// Date when this operation ended.
    open fileprivate(set) var endDate: Date? = nil
    
    /// Time interval ellapsed to complete this operation.
    open var executionDuration: TimeInterval? {
        guard let start = self.startDate else { return nil }
        return self.endDate?.timeIntervalSince(start)
    }
    
    /// Current status of this operation.
    open var status: OperationStatus {
        guard self.isReady else { return .pending }
        guard self.isExecuting || self.isFinished else { return .ready }
        if self.isExecuting { return .executing }
        if self.isCancelled { return .cancelled }
        if self.promise.isResolved { return .finished }
        return .finishing
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
            
            guard self.isExecuting != newValue else { return }
            
            willChangeValue(forKey: "isExecuting")
            
            self.stateLock.withCriticalScope {
                    
                self._executing = newValue
                
                if newValue {
                    self.startDate = Date()
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
            
            guard self.isFinished != newValue else { return }
            
            willChangeValue(forKey: "isFinished")
            
            self.stateLock.withCriticalScope {
                    
                self._finished = newValue
                
                if newValue {
                    self.endDate = Date()
                }
                
            }
            
            didChangeValue(forKey: "isFinished")
            
        }
    }
    
    open override var isConcurrent: Bool { return true }
    open override var isAsynchronous: Bool { return true }
    
    // MARK: Constructors
    
    /**
     Creates a new operation whose progress will be tracked by given progress.
     
     - parameter progress: Progress tracking new operation's progress. If
     `nil` operation's progress will remain the default one: a stalled progress
     with a total count of 0 units.
     */
    public init(progress: Progress? = nil) {
        (
            self.promise,
            self.fulfillPromise,
            self.rejectPromise
        ) = Promise<ReturnType>.pending()
        self.progress = progress ?? Progress(totalUnitCount: 0)
        super.init()
    }
    
    // MARK: Status-change methods
    
    /// Do not override this method. You must override `execute` method instead.
    open override func main() {
        guard !self.isCancelled else { return }
        self.isExecuting = true
        do {
            try self.execute()
        } catch let error {
            self.finish(error: ExecutionError.wrap(error))
        }
    }
    
    open override func cancel() {
        guard !self.promise.isResolved else { return }
        super.cancel()
        self.isExecuting = false
        self.isFinished = true
        self._finish(error: ExecutionError.Cancelled)
    }
    
    /**
     Changes internal state to reflect that this operation has finished its own
     execution but does not resolve underlying promise, leaving the operation in
     the `finishing` state.
     
     - returns: `false` if operation was previously cancelled.
     */
    fileprivate func moveToFinishing() -> Bool {
        guard !self.isCancelled else { return false }
        self.isExecuting = false
        self.isFinished = true
        return true
    }
    
    /**
     Successfully finishes this operation regardless its cancellation state.
     
     - warning: Will ignore `isCancelled` attribute, potentially fulfilling an
     already rejected promise.
     
     - parameter returnValue: Value to be used to fulfill promise.
     */
    fileprivate func _finish(_ returnValue: ReturnType) {
        self.progress.completedUnitCount = self.progress.totalUnitCount
        self.result = .success(returnValue)
        self.fulfillPromise(returnValue)
    }

    /**
     You should call this method when your operation and its children operations
     successfully.
     
     - note: Moves this operation to `finished` status.
     - note: Fulfills underlying promise, passing value to chained promises.
     
     - parameter returnValue: Value to be used to fulfill promise.
     */
    open func finish(_ returnValue: ReturnType) {
        if self.moveToFinishing() {
            self._finish(returnValue)
        }
    }
    
    /**
     Finishes this operation with given error, regardless its cancellation 
     state.
     
     - warning: Will ignore `isCancelled` attribute, potentially rejecting an
     already rejected promise.
     
     - parameter error: Error to be thrown back.
     */
    fileprivate func _finish(error: Swift.Error) {
        self.progress.completedUnitCount = self.progress.totalUnitCount
        let wrappedError = ExecutionError.wrap(error)
        self.result = .failure(wrappedError)
        self.rejectPromise(wrappedError)
    }
    
    /**
     You should call this method when your operation or its children operations
     finish with an error.
     
     - note: Moves this operation to `finished` status.
     - note: Rejects underlying promise, passing error to chained promises.
     
     - parameter error: Error to be thrown back.
     */
    open func finish(error: Swift.Error) {
        if self.moveToFinishing() {
            self._finish(error: error)
        }
    }
    
    /**
     Convenience method to finish this operation chaining the result of a
     promise, useful to avoid boilerplate when dealing with children operations.
     
     - warning: This method won't prevent deadlocks when enqueuing children
     operations in the same queue used to enqueue parent. If you want to prevent
     deadlocks you must use `finish(immediatelyForwarding:)` method.
     
     - parameter promise: Promise whose result will be used to finish this
     operation, successfully or not.
     */
    open func finish(waitingAndForwarding promise: Promise<ReturnType>) {
        promise
            .then { self.finish($0) }
            .catch { self.finish(error: $0) }
    }
    
    /**
     Convenience method to finish this operation chaining the result of a 
     promise, useful to avoid boilerplate when dealing with children operations.
     
     - note: This method will prevent deadlocks when enqueuing children 
     operations in the same queue used to enqueue parent as will move parent
     operation to `finishing` status, dequeuing it from queue.
     
     - warning: You must hold a strong reference to this operation or its promise
     if you want to retrieve its result later on as the operation queue will
     remove its reference.
     
     - parameter promise: Promise whose result will be used to finish this 
     operation, successfully or not.
     */
    open func finish(immediatelyForwarding promise: Promise<ReturnType>) {
        if self.moveToFinishing() {
            promise
                .then { result -> Void in
                    guard !self.isCancelled else { return }
                    self._finish(result)
                }
                .catch { error in
                    guard !self.isCancelled else { return }
                    self._finish(error: error)
                }
        }
    }
    
    // MARK: Overridable methods
    
    /**
     Performs task.
     
     - note: You must override this method in your subclasses.
     
     - note: You must signal execution's end using `finish()` methods family.
     
     - warning: Do not call `super.execute()`.
     
     - throws: Any error throw will be catch and forwarded to `finish(error:)`.
     */
    open func execute() throws {
        fatalError("To be implemented by subclasses. You must not call `super.execute` method from a child class.")
    }
    
}
