//
//  SimpleOperationTest.swift
//  Tests
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 10/2/17.
//
//

import XCTest
import OperationsKit
import PromiseKit
import Nimble

class SimpleOperationTest: XCTestCase {
    
    /// Queue used to enqueue operations.
    static let queue: OperationQueue = {
        
        let queue = OperationQueue()
        
        queue.maxConcurrentOperationCount = 1
        
        queue.name = "\(self)"
        
        return queue
        
    }()
    
    /**
     An operation which finish with a constant value.
     */
    class ConstantOperation: AsynchronousOperation<String, BaseOperationError> {
        
        /// Constant value to be returned.
        fileprivate let constant: String
        
        init(constant: String) {
            self.constant = constant
            super.init()
        }
        
        override func main() {
            super.main()
            self.finish(self.constant)
        }
        
    }
    
    enum FailedOperationError: OperationError {
        
        static var Cancelled: FailedOperationError { return .cancelled }
        static var Unknown: FailedOperationError { return .unknown }
        
        case cancelled
        case unknown
        case expected
        
    }
    
    /**
     An operation which fail with a constant error.
     */
    class FailedOperation: AsynchronousOperation<Void, FailedOperationError> {
        
        /// Constant value to be returned.
        fileprivate let constant: FailedOperationError
        
        init(error: FailedOperationError) {
            self.constant = error
            super.init()
        }
        
        override func main() {
            super.main()
            self.finish(error: self.constant)
        }
        
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
    
    /// Tests that `result` attribute holds proper value when operation succeeds.
    func testResultSuccess() {
        
        let timeToWait: UInt32 = 1
        
        let helloWorld = "Hello World!"
        
        let op = ConstantOperation(constant: helloWorld)
        
        type(of: self).queue.addOperation(op)
        
        expect(op.promise.value).toEventually(
            equal(helloWorld),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
        expect(op.promise.isResolved).toEventually(
            beTrue(),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
        expect(op.promise.isFulfilled).toEventually(
            beTrue(),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
        expect(op.promise.isRejected).toNotEventually(
            beTrue(),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
        expect(op.result?.value).toEventually(
            equal(helloWorld),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
    }
    
    /// Tests that `result` attribute holds proper value when operation fails.
    func testResultFail() {
        
        let timeToWait: UInt32 = 1
        
        let errorExpected = FailedOperationError.expected
        
        let op = FailedOperation(error: errorExpected)
        
        type(of: self).queue.addOperation(op)
        
        expect(op.promise.isResolved).toEventually(
            beTrue(),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
        expect(op.promise.isFulfilled).toNotEventually(
            beTrue(),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
        expect(op.promise.isRejected).toEventually(
            beTrue(),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
        expect(op.result?.error).toEventually(
            matchError(errorExpected),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
    }
    
}
