//
//  AsynchronousOperationTests.swift
//  Tests
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 12/2/17.
//
//

import XCTest
import OperationsKit
import PromiseKit
import Nimble

class AsynchronousOperationTests: XCTestCase {
    
    // MARK: - Common fixtures
    
    /// Returns a queue properly set up to be used in tests.
    func queue() -> OperationQueue {
        let queue = OperationQueue()
        // Must be 1 to easily reason about lifecycle
        queue.maxConcurrentOperationCount = 1
        queue.name = "\(type(of: self))"
        return queue
    }
    
    /// Wait some ms.
    func wait(ms: Double) { usleep(UInt32(ms * 1000.0)) }
    
    /// An operation which finish with a constant value.
    class ConstantOperation: AsynchronousOperation<String, BaseOperationError> {
        fileprivate let constant: String
        init(constant: String) {
            self.constant = constant
            super.init()
        }
        override func execute() { self.finish(self.constant) }
    }
    
    /// An operation which must be manually finished.
    class ManualOperation: AsynchronousOperation<Void, BaseOperationError> {
        override func execute() { }
    }
    
    /// An operation which will spawn a child operation.
    class OperationWithChild: AsynchronousOperation<Void, BaseOperationError> {
        let childOperation = ManualOperation()
        weak var queue: OperationQueue?
        init(queue: OperationQueue) {
            self.queue = queue
            super.init()
        }
        override func execute() {
            print("\(self.queue)")
            self.queue?.addOperation(self.childOperation)
            self.finish(forwarding: self.childOperation.promise)
        }
    }
    
    enum FailedOperationError: OperationError {
        static var Cancelled: FailedOperationError { return .cancelled }
        static var Unknown: FailedOperationError { return .unknown }
        case cancelled
        case unknown
        case expected
    }
    
    /// An operation which fail with a constant error.
    class FailedOperation: AsynchronousOperation<Void, FailedOperationError> {
        fileprivate let constant: FailedOperationError
        init(error: FailedOperationError) {
            self.constant = error
            super.init()
        }
        override func execute() { self.finish(error: self.constant) }
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
    
    /**
     Tests that a simple asynchronous operation properly succeeds and returns 
     its result.
     */
    func test__result_success() {
        
        let expectedReturnValue = "Hello World!"
        
        let op = ConstantOperation(constant: expectedReturnValue)
        
        self.queue().addOperation(op)
        
        // Promise must resolve, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Promise must be fulfilled, not rejected.
        expect(op.promise.isFulfilled).toEventually(beTrue())
        // Promise must be fulfilled with expected value.
        expect(op.promise.value).toEventually(equal(expectedReturnValue))
        // Promise must not be rejected, ever.
        expect(op.promise.isRejected).toNotEventually(beTrue())
        // Operation's result must be the expected return value, too.
        expect(op.result?.value).toEventually(equal(expectedReturnValue))
        
    }
    
    /**
     Tests that a simple asynchronous operation has the expected lifecycle.
     */
    func test__operation_lifecycle() {
        
        let firstOp = ManualOperation()
        let secondOp = ManualOperation()
        
        let queue = self.queue()
        
        queue.addOperation(firstOp)
        queue.addOperation(secondOp)
        
        // The second operation enqueued must be ready.
        expect(secondOp.isReady).to(beTrue())
        // The second operation enqueued must not be executing.
        expect(secondOp.isExecuting).to(beFalse())
        // The second operation enqueued must not be resolved.
        expect(secondOp.promise.isResolved).to(beFalse())
        // The second operation enqueued result must be nil.
        expect(secondOp.result).to(beNil())
        // The second operation enqueued status must be ready.
        expect(secondOp.status).to(equal(OperationStatus.ready))
        // The first operation enqueued must be executing.
        expect(firstOp.isExecuting).to(beTrue())
        // The first operation enqueued status must be executing.
        expect(firstOp.status).to(equal(OperationStatus.executing))
        // We finish the first operation.
        firstOp.finish()
        // The second operation enqueued must be executing, eventually.
        expect(secondOp.isExecuting).toEventually(beTrue())
        // The second operation enqueued must not be resolved, eventually.
        expect(secondOp.promise.isResolved).toEventually(beFalse())
        // The second operation enqueued result must be nil, eventually.
        expect(secondOp.result).toEventually(beNil())
        // The second operation enqueued status must be executing, eventually.
        expect(secondOp.status).toEventually(equal(OperationStatus.executing))
        // We finish the second operation.
        secondOp.finish()
        // The second operation enqueued must not be executing.
        expect(secondOp.isExecuting).to(beFalse())
        // The second operation enqueued must be resolved.
        expect(secondOp.promise.isResolved).to(beTrue())
        // The second operation enqueued result must be Void.
        expect(secondOp.promise.value).to(beVoid())
        // The second operation enqueued error must be nil.
        expect(secondOp.promise.error).to(beNil())
        // The second operation enqueued status must be finished.
        expect(secondOp.status).to(equal(OperationStatus.finished))
        
    }
    
    /**
     Tests that a simple asynchronous operation properly handle its dependencies.
     */
    func test__operation_dependencies() {
        
        let parentOp = ManualOperation()
        let childOp = ManualOperation()
        childOp.addDependency(parentOp)
        
        let queue = self.queue()
        
        queue.addOperation(childOp)
        queue.addOperation(parentOp)
        
        // Maybe we wait a ms?
        self.wait(ms: 1)
        // The child operation enqueued must not be ready.
        expect(childOp.isReady).to(beFalse())
        // The child operation enqueued must not be executing.
        expect(childOp.isExecuting).to(beFalse())
        // The child operation enqueued must not be resolved.
        expect(childOp.promise.isResolved).to(beFalse())
        // The child operation enqueued result must be nil.
        expect(childOp.result).to(beNil())
        // The child operation enqueued status must be pending.
        expect(childOp.status).to(equal(OperationStatus.pending))
        // The parent operation enqueued must be executing.
        expect(parentOp.isExecuting).to(beTrue())
        // The parent operation enqueued status must be executing.
        expect(parentOp.status).to(equal(OperationStatus.executing))
        // We pause the queue.
        queue.isSuspended = true
        // We finish the parent operation.
        parentOp.finish()
        // The child operation enqueued must be ready.
        expect(childOp.isReady).to(beTrue())
        // The child operation enqueued must not be executing.
        expect(childOp.isExecuting).to(beFalse())
        // The child operation enqueued must not be resolved.
        expect(childOp.promise.isResolved).to(beFalse())
        // The child operation enqueued result must be nil.
        expect(childOp.result).to(beNil())
        // The child operation enqueued status must be ready.
        expect(childOp.status).to(equal(OperationStatus.ready))
        // We resume the queue.
        queue.isSuspended = false
        // Maybe we wait a ms?
        self.wait(ms: 1)
        // The child operation enqueued must be executing.
        expect(childOp.isExecuting).to(beTrue())
        // The child operation enqueued must not be resolved.
        expect(childOp.promise.isResolved).to(beFalse())
        // The child operation enqueued result must be nil.
        expect(childOp.result).to(beNil())
        // The child operation enqueued status must be executing.
        expect(childOp.status).to(equal(OperationStatus.executing))
        // We finish the child operation, to clean up a little bit.
        childOp.finish()
        
    }
    
    /**
     Tests that a simple asynchronous operation properly handle its children
     operations.
     */
    func test__operation_children() {
        
        let queue = self.queue()
        
        let parentOp = OperationWithChild(queue: queue)
        let childOp = parentOp.childOperation
        
        queue.addOperation(parentOp)
        
        // The parent operation enqueued must not be executing, eventually.
        expect(parentOp.isExecuting).toEventually(beFalse())
        // The parent operation enqueued must be finished, eventually.
        expect(parentOp.isFinished).toEventually(beTrue())
        // The parent operation enqueued must not be resolved, eventually.
        expect(parentOp.promise.isResolved).toEventually(beFalse())
        // The parent operation enqueued result must be nil, eventually.
        expect(parentOp.result).toEventually(beNil())
        // The parent operation enqueued status must be finishing, eventually.
        expect(parentOp.status).toEventually(equal(OperationStatus.finishing))
        // The child operation enqueued must be executing, eventually.
        expect(childOp.isExecuting).toEventually(beTrue())
        // The child operation enqueued must not be resolved, eventually.
        expect(childOp.promise.isResolved).toEventually(beFalse())
        // The child operation enqueued result must be nil, eventually.
        expect(childOp.result).toEventually(beNil())
        // The child operation enqueued status must be executing, eventually.
        expect(childOp.status).toEventually(equal(OperationStatus.executing))
        // We finish child operation.
        childOp.finish()
        // The parent operation enqueued must be finished, eventually.
        expect(parentOp.isFinished).toEventually(beTrue())
        // The parent operation enqueued must be resolved, eventually.
        expect(parentOp.promise.isResolved).toEventually(beTrue())
        // The parent operation enqueued must be fulfilled, eventually.
        expect(parentOp.promise.isFulfilled).toEventually(beTrue())
        // The parent operation enqueued result must be void, eventually.
        expect(parentOp.result?.value).toEventually(beVoid())
        // The parent operation enqueued status must be finished, eventually.
        expect(parentOp.status).toEventually(equal(OperationStatus.finished))
        
    }
    
    /**
     Tests that a simple asynchronous operation properly fails and returns its
     error.
     */
    func test__result_fail() {
        
        let expectedError = FailedOperationError.expected
        
        let op = FailedOperation(error: expectedError)
        
        self.queue().addOperation(op)
        
        // Promise must resolve, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Promise must not be fulfilled, ever.
        expect(op.promise.isFulfilled).toNotEventually(beTrue())
        // Promise must be rejected, eventually.
        expect(op.promise.isRejected).toEventually(beTrue())
        // Promise must be rejected with expected error.
        expect(op.promise.error).toEventually(matchError(expectedError))
        // Operation's result must be the expected error, too.
        expect(op.result?.error).toEventually(matchError(expectedError))
        // Operation enqueued status must be finished, eventually.
        expect(op.status).toEventually(equal(OperationStatus.finished))
        
    }
    
    /**
     Tests that a simple asynchronous operation is properly cancelled.
     */
    func test__result_cancelled() {
        
        let expectedError = BaseOperationError.Cancelled
        
        let op = ManualOperation()
        
        self.queue().addOperation(op)
        
        op.cancel()
        op.finish()
        
        // Promise must resolve, eventually.
        expect(op.promise.isResolved).toEventually(beTrue())
        // Promise must not be fulfilled, ever.
        expect(op.promise.isFulfilled).toNotEventually(beTrue())
        // Promise must be rejected, eventually.
        expect(op.promise.isRejected).toEventually(beTrue())
        // Promise must be rejected with expected error.
        expect(op.promise.error).toEventually(matchError(expectedError))
        // Operation's result must be the expected error, too.
        expect(op.result?.error).toEventually(matchError(expectedError))
        // Operation enqueued status must be cancelled, eventually.
        expect(op.status).toEventually(equal(OperationStatus.cancelled))
        
    }
    
    /**
     Tests that a simple asynchronous operation properly handle its children
     operations.
     */
    func test__operation_timing() {
        
        let queue = self.queue()
        
        let op = ManualOperation()
        
        // Operation has no start date yet.
        expect(op.startDate).to(beNil())
        // Operation has no end date yet.
        expect(op.endDate).to(beNil())
        // Operation has no execution duration yet.
        expect(op.executionDuration).to(beNil())
        
        queue.addOperation(op)
        
        // Maybe we wait a ms?
        self.wait(ms: 1)
        // We store start date.
        let startDate = Date()
        // Operation has start date.
        expect(op.startDate).toNot(beNil())
        // Operation start date is similar to expected one.
        expect(op.startDate?.timeIntervalSince1970).to(
            beCloseTo(startDate.timeIntervalSince1970, within: 1)
        )
        // Operation has no end date yet.
        expect(op.endDate).to(beNil())
        // Operation has no execution duration yet.
        expect(op.executionDuration).to(beNil())
        // We finish operation.
        op.finish()
        // We store end time.
        let endDate = Date()
        // Operation has end date.
        expect(op.endDate).toNot(beNil())
        // Operation end date is similar to expected one.
        expect(op.endDate?.timeIntervalSince1970).to(
            beCloseTo(endDate.timeIntervalSince1970, within: 1)
        )
        // Operation has execution duration.
        expect(op.executionDuration).toNot(beNil())
        // Operation execution time is similar to expected one.
        let executionDuration = endDate.timeIntervalSince(startDate)
        expect(op.executionDuration).to(beCloseTo(executionDuration, within: 1))
        
    }
    
    /**
     Tests that base operation's reports itself as asynchronous and concurrent.
     */
    func test__abstract_operation_reports_as_concurrent_and_asynchronous() {
        let op = AsynchronousOperation<Void, BaseOperationError>()
        expect(op.isConcurrent).to(beTrue())
        expect(op.isAsynchronous).to(beTrue())
    }
    
    /**
     Tests that not overriding base operation's `execute()` method will throw
     a fatal error.
     */
    func test__abstract_operation_fails() {
        let op = AsynchronousOperation<Void, BaseOperationError>()
        expect { op.start() }.to(throwAssertion())
    }
    
}
