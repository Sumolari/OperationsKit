//
//  BlockBasedAsynchronousOperationTests.swift
//  Tests
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 10/12/16.
//
//

import XCTest
import OperationsKit
import PromiseKit
import Nimble

class BlockBasedAsynchronousOperationTests: XCTestCase {
    
    // MARK: - Common fixtures
    
    /// Returns a queue properly set up to be used in tests.
    func queue() -> OperationQueue {
        let queue = OperationQueue()
        // Must be 1 to easily reason about lifecycle
        queue.maxConcurrentOperationCount = 1
        queue.name = "\(type(of: self))"
        return queue
    }
    
    // MARK: - Test lifecycle
    
    override func setUp() {
        super.setUp()
        // Put setup code here.
        // This method is called before the invocation of each test method in
        // the class.
        Nimble.AsyncDefaults.Timeout = 10
    }
    
    override func tearDown() {
        // Put teardown code here.
        // This method is called after the invocation of each test method in the
        // class.
        super.tearDown()
    }
    
    // MARK: - Tests
    
    /// Tests that when the block succeeds the operation succeeds, too.
    func test__operation_promise_success() {
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>() {
            return Promise<Void>(value: ())
        }
        
        self.queue().addOperation(op)
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation's must be resolved, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Operation's must be fulfilled, eventually.
        expect(op.promise.isFulfilled).toEventually(beTrue())
        // Operation's must be fulfilled with expected value, eventually.
        expect(op.promise.value).toEventually(beVoid())
        // Operation's must not be rejected, ever.
        expect(op.promise.isRejected).toNotEventually(beTrue())
        // Operation's result value must match expected value, too.
        expect(op.result?.value).toEventually(beVoid())
        
    }
    
    /// Tests that when the block fails the operation succeeds, fails.
    func test__operation_promise_fails() {
        
        let expectedError = NSError(domain: "error", code: -1, userInfo: nil)
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>() {
            return Promise<Void>(error: expectedError)
        }
        
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
        if let promiseError = op.promise.error as? BaseOperationError {
            // - Error must be `unknown`...
            switch promiseError {
            case .unknown(let underlyingError):
                // - Underlying error must match expected `NSError`...
                expect(underlyingError).to(matchError(expectedError))
            default:
                XCTFail("Promise error must be `unknown`")
            }
        } else {
            XCTFail("Promise error must be a `BaseOperationError` instance")
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
            XCTFail("Result error must be a `BaseOperationError` instance")
        }
        
        // Operation enqueued status must be finished, eventually.
        expect(op.status).toEventually(equal(OperationStatus.finished))
        
    }
    
    /// Tests that when the block won't be called until operation is started.
    func test__operation_block_not_called_until_started() {
        
        var flag: Bool = false
        
        let block: () -> Promise<Void> = {
            flag = true
            return Promise<Void>(value: ())
        }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>(
            block: block
        )
        
        // Operation's block must not be called until operation is started.
        expect(flag).toNotEventually(beTrue())
        
        self.queue().addOperation(op)
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation's block must be called when operation is started.
        expect(flag).toEventually(beTrue())
        // Operation's must be resolved, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Operation's must be fulfilled, eventually.
        expect(op.promise.isFulfilled).toEventually(beTrue())
        // Operation's must be fulfilled with expected value, eventually.
        expect(op.promise.value).toEventually(beVoid())
        // Operation's must not be rejected, ever.
        expect(op.promise.isRejected).toNotEventually(beTrue())
        // Operation's result value must match expected value, too.
        expect(op.result?.value).toEventually(beVoid())
        
    }
    
    /// Tests that a cancelled operation won't run its block.
    func test__operation_cancelled_wont_start() {
        
        let expectedError = BaseOperationError.Cancelled
        
        var flag: Bool = false
        
        let block: () -> Promise<Void> = { _ in
            flag = true
            return Promise<Void>(value: ())
        }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>(
            block: block
        )
        
        let queue = self.queue()
        queue.isSuspended = true
        queue.addOperation(op)
        op.cancel()
        queue.isSuspended = false
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation must not be executed, ever.
        expect(flag).toNotEventually(beTrue())
        // Operation's must be resolved, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Operation's must not be fulfilled, ever.
        expect(op.promise.isFulfilled).toNotEventually(beTrue())
        // Operation's must be rejected, eventually.
        expect(op.promise.isRejected).toEventually(beTrue())
        // Operation's must be rejected with expected error, eventually.
        expect(op.promise.error).toEventually(matchError(expectedError))
        // Operation's result error must match expected error, too.
        expect(op.result?.error).toEventually(matchError(expectedError))
        
    }
    
    /// Tests that an external progress is properly forwarded by operation.
    func test__operation_external_progress() {

        let totalUnitCount: Int64 = 5
        
        let progress = Progress(totalUnitCount: totalUnitCount)
        
        var fulfill: (() -> Void)! = nil
        let promise = Promise<Void>() { f, _ in fulfill = f }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>(
            progress: progress
        ) { return promise }
        
        self.queue().addOperation(op)
        
        // Operation must be executing, eventually.
        expect(op.isExecuting).toEventually(beTrue())
        
        for expectedProgress in 0..<totalUnitCount {
            // Operation's progress total unit count must be expected one.
            expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
            // Operation's progress completed unit count must be expected one.
            expect(op.progress.completedUnitCount).to(equal(expectedProgress))
            // Operation's progress fraction must be close to expected one.
            expect(op.progress.fractionCompleted).to(
                beCloseTo(Double(expectedProgress) / Double(totalUnitCount))
            )
            // We increase completed unit count.
            progress.completedUnitCount += 1
        }
        
        // We finish the operation to be good citizens...
        fulfill()
        
    }
    
    /**
     Tests that an external progress is properly forwarded by operation when
     finished.
     */
    func test__operation_external_progress_when_finished() {
        
        let totalUnitCount: Int64 = 5
        
        let progress = Progress(totalUnitCount: totalUnitCount)
        
        var fulfill: (() -> Void)! = nil
        let promise = Promise<Void>() { f, _ in fulfill = f }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>(
            progress: progress
        ) { return promise }
        
        self.queue().addOperation(op)
        
        // Operation must be executing, eventually.
        expect(op.isExecuting).toEventually(beTrue())
        
        for expectedProgress in 0..<(totalUnitCount - 2) {
            // Operation's progress total unit count must be expected one.
            expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
            // Operation's progress completed unit count must be expected one.
            expect(op.progress.completedUnitCount).to(equal(expectedProgress))
            // Operation's progress fraction must be close to expected one.
            expect(op.progress.fractionCompleted).to(
                beCloseTo(Double(expectedProgress) / Double(totalUnitCount))
            )
            // We increase completed unit count.
            progress.completedUnitCount += 1
        }
        
        // We finish the operation...
        fulfill()
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation's progress total unit count must be expected one.
        expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
        // Operation's progress completed unit count must be expected one.
        expect(op.progress.completedUnitCount).to(equal(totalUnitCount))
        // Operation's progress fraction must be close to expected one.
        expect(op.progress.fractionCompleted).to(beCloseTo(1))
        
    }
    
    /**
     Tests that an external progress is properly forwarded by operation when
     it's cancelled.
     */
    func test__operation_external_progress_when_cancelled() {
        
        let totalUnitCount: Int64 = 5
        
        let progress = Progress(totalUnitCount: totalUnitCount)
        
        let promise = Promise<Void>() { _ in }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>(
            progress: progress
        ) { return promise }
        
        self.queue().addOperation(op)
        
        // Operation must be executing, eventually.
        expect(op.isExecuting).toEventually(beTrue())
        
        for expectedProgress in 0..<(totalUnitCount - 2) {
            // Operation's progress total unit count must be expected one.
            expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
            // Operation's progress completed unit count must be expected one.
            expect(op.progress.completedUnitCount).to(equal(expectedProgress))
            // Operation's progress fraction must be close to expected one.
            expect(op.progress.fractionCompleted).to(
                beCloseTo(Double(expectedProgress) / Double(totalUnitCount))
            )
            // We increase completed unit count.
            progress.completedUnitCount += 1
        }
        
        // We cancel the operation...
        op.cancel()
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation's progress total unit count must be expected one.
        expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
        // Operation's progress completed unit count must be expected one.
        expect(op.progress.completedUnitCount).to(equal(totalUnitCount))
        // Operation's progress fraction must be close to expected one.
        expect(op.progress.fractionCompleted).to(beCloseTo(1))
        
    }
    
    /**
     Tests that an external progress is properly forwarded by operation when
     finishes with an error.
     */
    func test__operation_external_progress_when_failed() {
        
        let totalUnitCount: Int64 = 5
        
        let progress = Progress(totalUnitCount: totalUnitCount)
        
        var reject: ((Swift.Error) -> Void)! = nil
        let promise = Promise<Void>() { _, r in reject = r }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>(
            progress: progress
        ) { return promise }
        
        self.queue().addOperation(op)
        
        // Operation must be executing, eventually.
        expect(op.isExecuting).toEventually(beTrue())
        
        for expectedProgress in 0..<(totalUnitCount - 2) {
            // Operation's progress total unit count must be expected one.
            expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
            // Operation's progress completed unit count must be expected one.
            expect(op.progress.completedUnitCount).to(equal(expectedProgress))
            // Operation's progress fraction must be close to expected one.
            expect(op.progress.fractionCompleted).to(
                beCloseTo(Double(expectedProgress) / Double(totalUnitCount))
            )
            // We increase completed unit count.
            progress.completedUnitCount += 1
        }
        
        // We finish the operation...
        reject(NSError(domain: "error", code: -1, userInfo: nil))
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation's progress total unit count must be expected one.
        expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
        // Operation's progress completed unit count must be expected one.
        expect(op.progress.completedUnitCount).to(equal(totalUnitCount))
        // Operation's progress fraction must be close to expected one.
        expect(op.progress.fractionCompleted).to(beCloseTo(1))
        
    }
    
    /// Tests that when the block succeeds the operation succeeds, too.
    func test__operation_pap_success() {
        
        let block: () -> ProgressAndPromise<Void> = {
            let progress = Progress(totalUnitCount: 1)
            let promise = Promise<Void>(value: ())
            return ProgressAndPromise(progress: progress, promise: promise)
        }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>(
            block: block
        )
        
        self.queue().addOperation(op)
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation's must be resolved, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Operation's must be fulfilled, eventually.
        expect(op.promise.isFulfilled).toEventually(beTrue())
        // Operation's must be fulfilled with expected value, eventually.
        expect(op.promise.value).toEventually(beVoid())
        // Operation's must not be rejected, ever.
        expect(op.promise.isRejected).toNotEventually(beTrue())
        // Operation's result value must match expected value, too.
        expect(op.result?.value).toEventually(beVoid())
        
    }
    
    /// Tests that when the block fails the operation succeeds, fails.
    func test__operation_pap_fails() {
        
        let expectedError = NSError(domain: "error", code: -1, userInfo: nil)
        
        let block: () -> ProgressAndPromise<Void> = {
            let progress = Progress(totalUnitCount: 1)
            let promise = Promise<Void>(error: expectedError)
            return ProgressAndPromise(progress: progress, promise: promise)
        }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>(
            block: block
        )
        
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
        if let promiseError = op.promise.error as? BaseOperationError {
            // - Error must be `unknown`...
            switch promiseError {
            case .unknown(let underlyingError):
                // - Underlying error must match expected `NSError`...
                expect(underlyingError).to(matchError(expectedError))
            default:
                XCTFail("Promise error must be `unknown`")
            }
        } else {
            XCTFail("Promise error must be a `BaseOperationError` instance")
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
            XCTFail("Result error must be a `BaseOperationError` instance")
        }
        
        // Operation enqueued status must be finished, eventually.
        expect(op.status).toEventually(equal(OperationStatus.finished))
        
    }
    
    /// Tests that when the block won't be called until operation is started.
    func test__operation_pap_not_called_until_started() {
        
        var flag: Bool = false
        
        let block: () -> ProgressAndPromise<Void> = {
            flag = true
            let progress = Progress(totalUnitCount: 1)
            let promise = Promise<Void>(value: ())
            return ProgressAndPromise(progress: progress, promise: promise)
        }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>(
            block: block
        )
        
        // Operation's block must not be called until operation is started.
        expect(flag).toNotEventually(beTrue())
        
        self.queue().addOperation(op)
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation's block must be called when operation is started.
        expect(flag).toEventually(beTrue())
        // Operation's must be resolved, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Operation's must be fulfilled, eventually.
        expect(op.promise.isFulfilled).toEventually(beTrue())
        // Operation's must be fulfilled with expected value, eventually.
        expect(op.promise.value).toEventually(beVoid())
        // Operation's must not be rejected, ever.
        expect(op.promise.isRejected).toNotEventually(beTrue())
        // Operation's result value must match expected value, too.
        expect(op.result?.value).toEventually(beVoid())
        
    }
    
    /// Tests that a cancelled operation won't run its block.
    func test__operation_pap_cancelled_wont_start() {
        
        let expectedError = BaseOperationError.Cancelled
        
        var flag: Bool = false
        
        let block: () -> ProgressAndPromise<Void> = { _ in
            flag = true
            let progress = Progress(totalUnitCount: 1)
            let promise = Promise<Void>(value: ())
            return ProgressAndPromise(progress: progress, promise: promise)
        }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>(
            block: block
        )
        
        let queue = self.queue()
        queue.isSuspended = true
        queue.addOperation(op)
        op.cancel()
        queue.isSuspended = false
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation must not be executed, ever.
        expect(flag).toNotEventually(beTrue())
        // Operation's must be resolved, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Operation's must not be fulfilled, ever.
        expect(op.promise.isFulfilled).toNotEventually(beTrue())
        // Operation's must be rejected, eventually.
        expect(op.promise.isRejected).toEventually(beTrue())
        // Operation's must be rejected with expected error, eventually.
        expect(op.promise.error).toEventually(matchError(expectedError))
        // Operation's result error must match expected error, too.
        expect(op.result?.error).toEventually(matchError(expectedError))
        
    }
    
    /// Test that a progress and promise block's progress is properly forwarded.
    func test_operation_pap_progress() {
        
        let totalUnitCount: Int64 = 5
        
        let progress = Progress(totalUnitCount: totalUnitCount)
        
        var fulfill: (() -> Void)! = nil
        let promise = Promise<Void>() { f, _ in fulfill = f }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>() {
            return ProgressAndPromise(progress: progress, promise: promise)
        }
        
        self.queue().addOperation(op)
        
        // Operation must be executing, eventually.
        expect(op.isExecuting).toEventually(beTrue())
        
        for expectedProgress in 0..<totalUnitCount {
            // Operation's progress total unit count must be expected one.
            expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
            // Forwarding progress may take a little bit so we must wait for it.
            // Operation's progress completed unit count must be expected one.
            expect(op.progress.completedUnitCount).toEventually(
                equal(expectedProgress),
                timeout: 10
            )
            // Operation's progress fraction must be close to expected one.
            expect(op.progress.fractionCompleted).toEventually(
                beCloseTo(Double(expectedProgress) / Double(totalUnitCount))
            )
            // We increase completed unit count.
            progress.completedUnitCount += 1
        }
        
        // We finish the operation to be good citizens...
        fulfill()
        
    }
    
    /** 
     Test that a progress and promise block's progress is properly forwarded
     when operation finishes successfully.
     */
    func test_operation_pap_progress_when_finished() {
        
        let totalUnitCount: Int64 = 5
        
        let progress = Progress(totalUnitCount: totalUnitCount)
        
        var fulfill: (() -> Void)! = nil
        let promise = Promise<Void>() { f, _ in fulfill = f }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>() {
            return ProgressAndPromise(progress: progress, promise: promise)
        }
        
        self.queue().addOperation(op)
        
        // Operation must be executing, eventually.
        expect(op.isExecuting).toEventually(beTrue())
        
        for expectedProgress in 0..<(totalUnitCount - 2) {
            // Operation's progress total unit count must be expected one.
            expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
            // Forwarding progress may take a little bit so we must wait for it.
            // Operation's progress completed unit count must be expected one.
            expect(op.progress.completedUnitCount).toEventually(
                equal(expectedProgress)
            )
            // Operation's progress fraction must be close to expected one.
            expect(op.progress.fractionCompleted).toEventually(
                beCloseTo(Double(expectedProgress) / Double(totalUnitCount))
            )
            // We increase completed unit count.
            progress.completedUnitCount += 1
        }
        
        // We finish the operation...
        fulfill()
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation's progress total unit count must be expected one.
        expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
        // Operation's progress completed unit count must be expected one.
        expect(op.progress.completedUnitCount).toEventually(
            equal(totalUnitCount)
        )
        // Operation's progress fraction must be close to expected one.
        expect(op.progress.fractionCompleted).toEventually(beCloseTo(1))
        
    }
    
    /**
     Test that a progress and promise block's progress is properly forwarded
     when operation is cancelled.
     */
    func test_operation_pap_progress_when_cancelled() {
        
        let totalUnitCount: Int64 = 5
        
        let progress = Progress(totalUnitCount: totalUnitCount)
        
        let promise = Promise<Void>() { _ in }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>() {
            return ProgressAndPromise(progress: progress, promise: promise)
        }
        
        self.queue().addOperation(op)
        
        // Operation must be executing, eventually.
        expect(op.isExecuting).toEventually(beTrue())
        
        for expectedProgress in 0..<(totalUnitCount - 2) {
            // Operation's progress total unit count must be expected one.
            expect(op.progress.totalUnitCount).toEventually(
                equal(totalUnitCount)
            )
            // Forwarding progress may take a little bit so we must wait for it.
            // Operation's progress completed unit count must be expected one.
            expect(op.progress.completedUnitCount).toEventually(
                equal(expectedProgress)
            )
            // Operation's progress fraction must be close to expected one.
            expect(op.progress.fractionCompleted).toEventually(
                beCloseTo(Double(expectedProgress) / Double(totalUnitCount))
            )
            // We increase completed unit count.
            progress.completedUnitCount += 1
        }
        
        // We cancel the operation...
        op.cancel()
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation's progress total unit count must be expected one.
        expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
        // Operation's progress completed unit count must be expected one.
        expect(op.progress.completedUnitCount).toEventually(
            equal(totalUnitCount)
        )
        // Operation's progress fraction must be close to expected one.
        expect(op.progress.fractionCompleted).to(beCloseTo(1))
        
    }
    
    /**
     Test that a progress and promise block's progress is properly forwarded
     when operation finishes with an error.
     */
    func test_operation_pap_progress_when_failed() {
        
        let totalUnitCount: Int64 = 5
        
        let progress = Progress(totalUnitCount: totalUnitCount)
        
        var reject: ((Swift.Error) -> Void)! = nil
        let promise = Promise<Void>() { _, r in reject = r }
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>() {
            return ProgressAndPromise(progress: progress, promise: promise)
        }
        
        self.queue().addOperation(op)
        
        // Operation must be executing, eventually.
        expect(op.isExecuting).toEventually(beTrue())
        
        for expectedProgress in 0..<(totalUnitCount - 2) {
            // Operation's progress total unit count must be expected one.
            expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
            // Forwarding progress may take a little bit so we must wait for it.
            // Operation's progress completed unit count must be expected one.
            expect(op.progress.completedUnitCount).toEventually(
                equal(expectedProgress)
            )
            // Operation's progress fraction must be close to expected one.
            expect(op.progress.fractionCompleted).toEventually(
                beCloseTo(Double(expectedProgress) / Double(totalUnitCount))
            )
            // We increase completed unit count.
            progress.completedUnitCount += 1
        }
        
        // We finish the operation...
        reject(NSError(domain: "error", code: -1, userInfo: nil))
        
        // Operation must be finished, eventually.
        expect(op.isFinished).toEventually(beTrue())
        // Operation's progress total unit count must be expected one.
        expect(op.progress.totalUnitCount).to(equal(totalUnitCount))
        // Operation's progress completed unit count must be expected one.
        expect(op.progress.completedUnitCount).toEventually(
            equal(totalUnitCount)
        )
        // Operation's progress fraction must be close to expected one.
        expect(op.progress.fractionCompleted).toEventually(beCloseTo(1))
        
    }
    
}
