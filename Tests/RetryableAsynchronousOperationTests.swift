//
//  RetryableAsynchronousOperationTests.swift
//  Tests
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 10/2/17.
//
//

import XCTest
import OperationsKit
import PromiseKit
import Nimble

class RetryableAsynchronousOperationTests: XCTestCase {
    
    // MARK: - Common fixtures
    
    /// Returns a queue properly set up to be used in tests.
    func queue() -> OperationQueue {
        let queue = OperationQueue()
        // Must be 1 to easily reason about lifecycle
        queue.maxConcurrentOperationCount = 1
        queue.name = "\(type(of: self))"
        return queue
    }
    
    /**
     An operation which always repeat itself but each repetition is manually
     triggered.
     */
    class ManualOperation: RetryableAsynchronousOperation<Void, BaseRetryableOperationError> {
        override func execute() throws { }
    }
    
    /// An operation which always repeat itself until reaching maximum attempts.
    class UnlimitedOperation: RetryableAsynchronousOperation<Void, BaseRetryableOperationError> {
        fileprivate let msToWait: Double
        init(msToWait: Double, maximumAttempts: UInt64) {
            self.msToWait = msToWait
            super.init(maximumAttempts: maximumAttempts)
        }
        override func execute() throws {
            usleep(UInt32(self.msToWait * 1000))
            self.retry()
        }
    }
    
    /** 
     An operation which always repeat itself until reaching maximum attempts,
     throwing a specific error on each repetition.
     */
    class FailedOperation: RetryableAsynchronousOperation<Void, BaseRetryableOperationError> {
        fileprivate let constant: Swift.Error
        init(constant: Swift.Error, maximumAttempts: UInt64) {
            self.constant = constant
            super.init(maximumAttempts: maximumAttempts)
        }
        override func execute() throws { self.retry(dueTo: self.constant) }
    }
    
    /**
     An operation which will throw a specific error.
     */
    class ThrowingOperation: RetryableAsynchronousOperation<Void, BaseRetryableOperationError> {
        fileprivate let constant: Swift.Error
        fileprivate let afterAttempts: UInt64
        init(constant: Swift.Error, afterAttempts: UInt64, maximumAttempts: UInt64) {
            self.constant = constant
            self.afterAttempts = afterAttempts
            super.init(maximumAttempts: maximumAttempts)
        }
        override func execute() throws {
            guard self.attempts >= self.afterAttempts else {
                return self.retry(dueTo: self.constant)
            }
            throw self.constant
        }
    }
    
    // MARK: - Test lifecycle
    
    override func setUp() {
        super.setUp()
        // Put setup code here.
        // This method is called before the invocation of each test method in
        // the class.
    }
    
    override func tearDown() {
        // Put teardown code here.
        // This method is called after the invocation of each test method in the
        // class.
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func test__operation_reaches_retry_limit() {
        
        let attempts: UInt64 = 3
        let op = UnlimitedOperation(msToWait: 1, maximumAttempts: attempts)
        
        self.queue().addOperation(op)
        
        let errorExpected = BaseRetryableOperationError.ReachedRetryLimit
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation enqueued status must be finished, eventually.
        expect(op.status).toEventually(equal(OperationStatus.finished))
        // Promise must be resolved, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Promise must not be fulfilled, ever.
        expect(op.promise.isFulfilled).toNotEventually(beTrue())
        // Promise must be rejected, eventually.
        expect(op.promise.isRejected).toEventually(beTrue())
        // Promise must be rejected with expected error.
        expect(op.promise.error).toEventually(matchError(errorExpected))
        // Operation's result must be the expected error, too.
        expect(op.result?.error).toEventually(matchError(errorExpected))
        
    }
    
    func test__operation_retries_until_succeeds() {
     
        let attempts: UInt64 = 3
        let op = ManualOperation(maximumAttempts: attempts)
        
        self.queue().addOperation(op)
        
        // Operation must be executing, eventually.
        expect(op.isExecuting).toEventually(beTrue())
        
        // We do this twice.
        for _ in 0..<(attempts - 1) {
            // Operation must not be finished.
            expect(op.isFinished).to(beFalse())
            // Operation must be executing.
            expect(op.isExecuting).to(beTrue())
            // Operation enqueued status must be executing.
            expect(op.status).to(equal(OperationStatus.executing))
            // Operation promise must not be resolved.
            expect(op.promise.isResolved).to(beFalse())
            // Operation result must be nil.
            expect(op.result).to(beNil())
            // We retry the operation.
            op.retry()
        }
        
        op.finish()
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation enqueued status must be finished, eventually.
        expect(op.status).toEventually(equal(OperationStatus.finished))
        // Operation promise must be resolved, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Operation promise must be fulfilled, eventually.
        expect(op.promise.isFulfilled).toEventually(beTrue())
        // Operation promise must be fulfilled with expected value, eventually.
        expect(op.promise.value).toEventually(beVoid())
        // Operation result must be expected value, too, eventually.
        expect(op.result?.value).toEventually(beVoid())
        
    }
    
    func test__canceled_operation_is_not_retried() {
        
        let attempts: UInt64 = 3
        let op = ManualOperation(maximumAttempts: attempts)
        
        let errorExpected = BaseRetryableOperationError.Cancelled
        
        self.queue().addOperation(op)
        
        // Operation attempts must match expected value.
        expect(op.attempts).to(equal(0))
        // We retry the operation.
        op.retry()
        // Operation attempts must match expected value.
        expect(op.attempts).to(equal(1))
        // We cancel.
        op.cancel()
        // Operation attempts must match expected value.
        expect(op.attempts).to(equal(1))
        // We retry the operation.
        op.retry()
        // Operation attempts must match expected value.
        expect(op.attempts).to(equal(1))
        // Operation must be resolved with proper error.
        expect(op.promise.error).to(matchError(errorExpected))
        // Operation result must be proper error, too.
        expect(op.result?.error).to(matchError(errorExpected))
        
    }
    
    func test__throwing_operation_is_not_retried() {
        
        let expectedError = NSError(domain: "expected", code: -1, userInfo: nil)
        
        let attempts: UInt64 = 3
        let op = ThrowingOperation(
            constant: expectedError,
            afterAttempts: 0,
            maximumAttempts: attempts
        )
        
        let queue = self.queue()
        queue.isSuspended = true
        queue.addOperation(op)
        
        // Operation attempts must match expected value.
        expect(op.attempts).to(equal(0))
        // Operation must not be finished.
        expect(op.isFinished).to(beFalse())
        // Operation must be ready to be run.
        expect(op.status).to(equal(OperationStatus.ready))
        
        queue.isSuspended = false
        
        // Operation attempts must match expected value, eventually.
        expect(op.attempts).toEventually(equal(0))
  
        // Promise must be rejected with expected error...
        // - Promise must be rejected with a `BaseOperationError` error...
        expect(op.isFinished).toEventually(beTrue()) // Wait until finishes...
        if let promiseError = op.promise.error as? BaseRetryableOperationError {
            // - Error must be `unknown`...
            switch promiseError {
            case .unknown(let underlyingError):
                // - Underlying error must match expected `NSError`...
                expect(underlyingError).to(matchError(expectedError))
            default:
                XCTFail("Promise error must be `unknown`")
            }
        } else {
            XCTFail("Promise error must be a `BaseRetryableOperationError` instance")
        }
        // Operation's result must be the expected error, too...
        if let error = op.result?.error {
            // - Error must be `unknown`...
            switch error {
            case .unknown(let underlyingError):
                // - Underlying error must match expected `NSError`...
                expect(underlyingError).to(matchError(expectedError))
            default:
                XCTFail("Result error must be `unknown`")
            }
        } else {
            XCTFail("Result error must be a `BaseRetryableOperationError` instance")
        }
        
    }
    
    func test__throwing_operation_is_retried_until_exception_thrown() {
        
        let expectedError = NSError(domain: "expected", code: -1, userInfo: nil)
        
        let attempts: UInt64 = 3
        let op = ThrowingOperation(
            constant: expectedError,
            afterAttempts: 1,
            maximumAttempts: attempts
        )
        
        let queue = self.queue()
        queue.isSuspended = true
        queue.addOperation(op)
        
        
        // Operation attempts must match expected value.
        expect(op.attempts).to(equal(0))
        // Operation must not be finished.
        expect(op.isFinished).to(beFalse())
        // Operation must be ready to be run.
        expect(op.status).to(equal(OperationStatus.ready))
        
        queue.isSuspended = false
        
        // Operation attempts must match expected value, eventually.
        expect(op.attempts).toEventually(equal(1))
        
        // Promise must be rejected with expected error...
        // - Promise must be rejected with a `BaseOperationError` error...
        expect(op.isFinished).toEventually(beTrue()) // Wait until finishes...
        if let promiseError = op.promise.error as? BaseRetryableOperationError {
            // - Error must be `unknown`...
            switch promiseError {
            case .unknown(let underlyingError):
                // - Underlying error must match expected `NSError`...
                expect(underlyingError).to(matchError(expectedError))
            default:
                XCTFail("Promise error must be `unknown`")
            }
        } else {
            XCTFail("Promise error must be a `BaseRetryableOperationError` instance")
        }
        // Operation's result must be the expected error, too...
        if let error = op.result?.error {
            // - Error must be `unknown`...
            switch error {
            case .unknown(let underlyingError):
                // - Underlying error must match expected `NSError`...
                expect(underlyingError).to(matchError(expectedError))
            default:
                XCTFail("Result error must be `unknown`")
            }
        } else {
            XCTFail("Result error must be a `BaseRetryableOperationError` instance")
        }
        
    }
    
    func test__operation_retry_count_is_updated() {
    
        let attempts: UInt64 = 3
        let op = ManualOperation(maximumAttempts: attempts)
        
        self.queue().addOperation(op)
        
        // We do this twice.
        for currentAttempt in 0..<attempts {
            // Operation attempts must match expected value.
            expect(op.attempts).to(equal(currentAttempt))
            // We retry the operation.
            op.retry()
        }
        
        expect(op.attempts).to(equal(attempts))
        
    }
    
    /**
     Tests that a retryable asynchronous operation with a generic NSError 
     properly fails wrapping the error in an unknown error.
     */
    func test__result_fail_generic_error() {
        
        let expectedError = NSError(domain: "error", code: -1, userInfo: nil)
        
        let op = FailedOperation(constant: expectedError, maximumAttempts: 3)
        
        self.queue().addOperation(op)
        
        // Promise must resolve, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Promise must not be fulfilled, ever.
        expect(op.promise.isFulfilled).toNotEventually(beTrue())
        // Promise must be rejected, eventually.
        expect(op.promise.isRejected).toEventually(beTrue())
        
        // Promise must be rejected with expected error...
        // - Promise must be rejected with a `BaseOperationError` error...
        expect(op.isFinished).toEventually(beTrue()) // Wait until finishes...
        if let promiseError = op.promise.error as? BaseRetryableOperationError {
            // - Error must be `unknown`...
            switch promiseError {
            case .unknown(let underlyingError):
                // - Underlying error must match expected `NSError`...
                expect(underlyingError).to(matchError(expectedError))
            default:
                XCTFail("Promise error must be `unknown`")
            }
        } else {
            XCTFail("Promise error must be a `BaseRetryableOperationError` instance")
        }
        // Operation's result must be the expected error, too...
        if let error = op.result?.error {
            // - Error must be `unknown`...
            switch error {
            case .unknown(let underlyingError):
                // - Underlying error must match expected `NSError`...
                expect(underlyingError).to(matchError(expectedError))
            default:
                XCTFail("Result error must be `unknown`")
            }
        } else {
            XCTFail("Result error must be a `BaseRetryableOperationError` instance")
        }
        
        // Operation enqueued status must be finished, eventually.
        expect(op.status).toEventually(equal(OperationStatus.finished))
        
    }
    
}
