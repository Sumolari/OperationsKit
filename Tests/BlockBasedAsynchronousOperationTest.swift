//
//  BlockBasedAsynchronousOperationTest.swift
//  Tests
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 10/12/16.
//
//

import XCTest
import OperationsKit
import PromiseKit
import Nimble

class BlockBasedAsynchronousOperationTest: XCTestCase {
    
    /**
     Well known errors that can be produced in these tests.
     
     - expected: Expected error.
     */
    enum TestError: OperationError {
        
        public static var Cancelled: TestError { return .cancelled }
        public static var Unknown: TestError { return .unknown }
        
        case cancelled
        case unknown
        case expected
        
    }
    
    /// Small delay to wait to let operation queue start operations.
    static let startThreshold: UInt32 = 500
    
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
     Returns a block for an asynchronous operation that will sleep some seconds.
     
     - parameter ms: Milliseconds the block should sleep.
     
     - returns: Promise wrapping the asynchronous operation.
     */
    fileprivate func block(toSleep ms: UInt32) -> (Void) -> Promise<Void> {
        
        return {
            return Promise<Void>() { fulfill, _ in
                print("Operation started, sleeping for \(ms) ms")
                usleep(ms * 1000)
                print("Operation woke up!")
                fulfill()
            }
        }
        
    }
    
    /**
     Returns a block for an asynchronous operation that will sleep some seconds
     and track its progress.
     
     - parameter ms: Milliseconds the block should sleep each time.
     - parameter times: Times that the block should sleep.
     
     - returns: Progress and promise wrapping the asynchronous operation.
     */
    fileprivate func block(
        toSleep ms: UInt32,
        times: Int64
    ) -> (Void) -> ProgressAndPromise<Void> {
        
        return {
        
            let progress = Progress(totalUnitCount: times)
            
            let promise = Promise<Void>() { fulfill, _ in
                print("Operation started, sleeping for \(ms) ms \(times) times")
                for i in 0..<times {
                    usleep(ms * 1000)
                    progress.completedUnitCount = i + 1
                    print("Operation woke up! \(times - i - 1) times remaining...")
                }
                fulfill()
            }
            
            return ProgressAndPromise(progress: progress, promise: promise)
            
        }
        
    }
    
    /**
     Returns a block for an asynchronous operation that will sleep some seconds.
     
     - parameter ms: Milliseconds the block should sleep.
     
     - returns: Promise wrapping the asynchronous operation.
     */
    fileprivate func block(
        toFailAfterSleeping ms: UInt32
    ) -> (Void) -> Promise<Void> {
        
        return {
            return Promise<Void>() { _, reject in
                print("Operation started, sleeping for \(ms) ms")
                usleep(ms)
                print("Operation woke up!")
                reject(TestError.expected)
            }
        }
        
    }
    
    /// Tests that the operation is asynchronous.
    func testOperationIsAsynchronous() {
        
        let timeToSleep: UInt32 = 2
        let expectationsWaitTime = TimeInterval(2 * timeToSleep)
        
        let op = BlockBasedAsynchronousOperation<Void, TestError>(
            block: self.block(toSleep: timeToSleep)
        )
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.addOperation(op)
        
        usleep(type(of:self).startThreshold) // To let queue to start operation
        
        expect(op.isExecuting).to(beTrue())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        expect(op.isConcurrent).to(beTrue())
        expect(op.isAsynchronous).to(beTrue())
        
        expect(op.promise.isResolved).to(beFalse())
        expect(op.promise.isFulfilled).to(beFalse())
        expect(op.promise.isRejected).to(beFalse())
        
        expect(op.promise.isResolved).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isFulfilled).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isRejected).toNotEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beTrue())
        
    }
    
    /// Tests that the operation properly succeeds.
    func testOperationSucceeds() {
        
        let timeToSleep: UInt32 = 2
        let expectationsWaitTime = TimeInterval(2 * timeToSleep)
        
        let op = BlockBasedAsynchronousOperation<Void, TestError>(
            block: self.block(toSleep: timeToSleep)
        )
        
        var finished: Bool = false
        _ = op.promise.then { _ in finished = true }
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        expect(op.executionDuration).to(beNil())
        
        let enqueueDate = Date()
        
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.addOperation(op)
        
        usleep(type(of:self).startThreshold) // To let queue to start operation
        
        expect(op.isExecuting).to(beTrue())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        expect(op.promise.isResolved).to(beFalse())
        expect(op.promise.isFulfilled).to(beFalse())
        expect(op.promise.isRejected).to(beFalse())
        
        expect(op.promise.isResolved).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isFulfilled).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isRejected).toNotEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(finished).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beTrue())
        
        let ellapsedTime = Date().timeIntervalSince(enqueueDate)
        
        expect(op.executionDuration).toEventually(
            beCloseTo(ellapsedTime, within: 0.5),
            timeout: expectationsWaitTime
        )
        
        
        
    }
    
    /// Tests that the operation properly succeeds.
    func testCompletionBlockIsCalledOnce() {
        
        let timeToSleep: UInt32 = 2
        let expectationsWaitTime = TimeInterval(2 * timeToSleep)
        
        let op = BlockBasedAsynchronousOperation<Void, TestError>(
            block: self.block(toSleep: timeToSleep)
        )
        
        var counter = 0
        op.completionBlock = { _ in counter += 1 }
        
        var finished: Bool = false
        _ = op.promise.then { _ in finished = true }
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.addOperation(op)
        
        expect(counter).to(equal(0))
        
        usleep(type(of:self).startThreshold) // To let queue to start operation
        
        expect(op.isExecuting).to(beTrue())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        expect(op.promise.isResolved).to(beFalse())
        expect(op.promise.isFulfilled).to(beFalse())
        expect(op.promise.isRejected).to(beFalse())
        
        expect(op.promise.isResolved).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isFulfilled).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isRejected).toNotEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(finished).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beTrue())
        
        expect(counter).toEventually(equal(1))
        expect(counter).toNotEventually(equal(2))
        expect(counter).toNotEventually(equal(0))
        
    }
    
    /// Tests that the operation properly fails.
    func testOperationFails() {
        
        let timeToSleep: UInt32 = 2
        let expectationsWaitTime = TimeInterval(2 * timeToSleep)
        
        let op = BlockBasedAsynchronousOperation<Void, TestError>(
            block: self.block(toFailAfterSleeping: timeToSleep)
        )
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        var finished: Bool = false
        op.promise.catch { _ in finished = true }
        
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.addOperation(op)
        
        usleep(type(of:self).startThreshold) // To let queue to start operation
        
        expect(op.isExecuting).to(beTrue())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        expect(op.promise.isResolved).to(beFalse())
        expect(op.promise.isFulfilled).to(beFalse())
        expect(op.promise.isRejected).to(beFalse())
        
        expect(op.promise.isResolved).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isFulfilled).toNotEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isRejected).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(finished).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beTrue())
        
    }
    
    /// Tests that the operation runs completion block on fail.
    func testCompletionBlockIsCalledOnFail() {
        
        let timeToSleep: UInt32 = 2
        let expectationsWaitTime = TimeInterval(2 * timeToSleep)
        
        let op = BlockBasedAsynchronousOperation<Void, TestError>(
            block: self.block(toFailAfterSleeping: timeToSleep)
        )
        
        var counter = 0
        op.completionBlock = { _ in counter += 1 }
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        var finished: Bool = false
        op.promise.catch { _ in finished = true }
        
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.addOperation(op)
        
        expect(counter).to(equal(0))
        
        usleep(type(of:self).startThreshold) // To let queue to start operation
        
        expect(op.isExecuting).to(beTrue())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        expect(op.promise.isResolved).to(beFalse())
        expect(op.promise.isFulfilled).to(beFalse())
        expect(op.promise.isRejected).to(beFalse())
        
        expect(op.promise.isResolved).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isFulfilled).toNotEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isRejected).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(finished).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beTrue())
        
        expect(counter).toEventually(equal(1))
        expect(counter).toNotEventually(equal(2))
        expect(counter).toNotEventually(equal(0))
        
    }
    
    /// Tests that the operation is cancellable.
    func testOperationIsCancellable() {
        
        let timeToSleep: UInt32 = 2
        let expectationsWaitTime = TimeInterval(2 * timeToSleep)
        
        let op = BlockBasedAsynchronousOperation<Void, TestError>(
            block: self.block(toSleep: timeToSleep)
        )
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.addOperation(op)
        
        usleep(type(of:self).startThreshold) // To let queue to start operation
        
        expect(op.promise.isResolved).to(beFalse())
        expect(op.promise.isFulfilled).to(beFalse())
        expect(op.promise.isRejected).to(beFalse())
        
        expect(op.isExecuting).to(beTrue())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        op.cancel()
        
        expect(op.isCancelled).to(beTrue())
        expect(op.isExecuting).to(beFalse())
        expect(op.isFinished).to(beTrue())
        
        expect(op.promise.isRejected).to(beTrue())
        
        expect(op.promise.isResolved).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isFulfilled).toNotEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
    }

    /// Tests that the operation properly reports its progress.
    func testOperationTracksProgress() {
        
        let timeToSleep: UInt32 = 2
        let timesToSleep: Int64 = 5
        let expectationsWaitTime = TimeInterval(2 * timeToSleep)
        
        let op = BlockBasedAsynchronousOperation<Void, TestError>(
            block: self.block(
                toSleep: timeToSleep,
                times: timesToSleep
            )
        )
        
        expect(op.progress).toNot(beNil())
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        let queue = OperationQueue()
        queue.qualityOfService = .background
        queue.addOperation(op)
        
        usleep(type(of:self).startThreshold) // To let queue to start operation
        
        expect(op.progress).toNot(beNil())
        
        expect(op.progress!.fractionCompleted).toNot(beCloseTo(1.0))
        
        expect(op.isExecuting).to(beTrue())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beFalse())
        
        expect(op.isConcurrent).to(beTrue())
        expect(op.isAsynchronous).to(beTrue())
        
        expect(op.promise.isResolved).to(beFalse())
        expect(op.promise.isFulfilled).to(beFalse())
        expect(op.promise.isRejected).to(beFalse())
        
        expect(op.promise.isResolved).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isFulfilled).toEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.promise.isRejected).toNotEventually(
            beTrue(),
            timeout: expectationsWaitTime
        )
        
        expect(op.progress!.fractionCompleted).to(beCloseTo(1.0))
        
        expect(op.isExecuting).to(beFalse())
        expect(op.isCancelled).to(beFalse())
        expect(op.isFinished).to(beTrue())
        
    }
    
}
