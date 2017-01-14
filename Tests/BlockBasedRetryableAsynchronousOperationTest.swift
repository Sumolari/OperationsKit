//
//  BlockBasedRetryableAsynchronousOperationTest.swift
//  Tests
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 11/12/16.
//
//

import XCTest
import OperationsKit
import PromiseKit
import Nimble

class BlockBasedRetryableAsynchronousOperationTest: XCTestCase {
    
    /// Well known errors that can be produced in these tests.
    enum TestError: Error {
        /// Expected error.
        case expected
    }
    
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
    
    /**
     Returns a block for an asynchronous operation that requires given amount
     of retries to complete successfully.
     
     - parameter times: Amount of attempts required to succeed.
     
     - returns: Promise wrapping the asynchronous operation.
     */
    fileprivate func block(toRetry times: UInt64) -> (Void) -> Promise<Void> {
        
        var counter: UInt64 = 0
        
        return {
            return Promise<Void>() { fulfill, reject in
                guard counter != times else { return fulfill() }
                counter += 1
                reject(TestError.expected)
            }
        }
        
    }
    
    /**
     Returns a block for an asynchronous operation that requires given amount
     of retries to complete successfully.
     
     - parameter times: Amount of attempts required to succeed.
     
     - returns: Progress and promise wrapping the asynchronous operation.
     */
    fileprivate func blockWithProgress(
        toRetry times: UInt64
    ) -> (Void) -> ProgressAndPromise<Void> {
        
        var counter: UInt64 = 0
        
        return {
            
            let progress = Progress(totalUnitCount: Int64(times))
            progress.completedUnitCount = Int64(counter)
            
            let promise = Promise<Void>() { fulfill, reject in
                guard counter != times else { return fulfill() }
                counter += 1
                reject(TestError.expected)
            }
            
            return ProgressAndPromise(progress: progress, promise: promise)
            
        }
        
    }
    
    /// Tests that the operation is actually retried.
    func testOperationIsRetried() {
        
        let retriesRequired: UInt64 = 3
        
        let op = BlockBasedRetryableAsynchronousOperation(
            maximumAttempts: retriesRequired,
            block: self.block(toRetry: retriesRequired)
        )
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.addOperation(op)
        
        expect(op.promise.isResolved).to(beFalse())
        expect(op.promise.isFulfilled).to(beFalse())
        expect(op.promise.isRejected).to(beFalse())
        
        expect(op.promise.isResolved).toEventually(beTrue())
        expect(op.promise.isFulfilled).toEventually(beTrue())
        expect(op.promise.isRejected).toNotEventually(beTrue())
        
    }
    
    /// Tests that the operation is actually retried but maximum allowed retry
    /// count is not exceeded.
    func testOperationIsRetriedWithLimits() {
        
        let retriesRequired: UInt64 = 3
        
        let op = BlockBasedRetryableAsynchronousOperation(
            maximumAttempts: retriesRequired - 1,
            block: self.block(toRetry: retriesRequired)
        )
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.addOperation(op)
        
        expect(op.promise.isResolved).to(beFalse())
        expect(op.promise.isFulfilled).to(beFalse())
        expect(op.promise.isRejected).to(beFalse())
        
        expect(op.promise.isResolved).toNotEventually(beTrue())
        expect(op.promise.isFulfilled).toNotEventually(beTrue())
        expect(op.promise.isRejected).toEventually(beTrue())
        
    }
    
    /// Tests that the operation is actually retried and its progress tracked.
    func testOperationWithProgressIsRetried() {
        
        let retriesRequired: UInt64 = 3
        
        let op = BlockBasedRetryableAsynchronousOperation(
            maximumAttempts: retriesRequired,
            block: self.blockWithProgress(toRetry: retriesRequired)
        )
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        expect(op.progress).toNot(beNil())
        expect(op.progress!.fractionCompleted).toNot(beCloseTo(1.0))
        
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.addOperation(op)
        
        expect(op.promise.isResolved).to(beFalse())
        expect(op.promise.isFulfilled).to(beFalse())
        expect(op.promise.isRejected).to(beFalse())
        
        expect(op.promise.isResolved).toEventually(beTrue())
        expect(op.promise.isFulfilled).toEventually(beTrue())
        expect(op.promise.isRejected).toNotEventually(beTrue())
        
        expect(op.progress!.fractionCompleted).to(beCloseTo(1.0))
        
    }
    
}
