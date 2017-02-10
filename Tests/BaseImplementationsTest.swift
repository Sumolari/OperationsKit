//
//  BaseImplementationsTest.swift
//  Tests
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 10/2/17.
//
//

import XCTest
import OperationsKit
import Nimble
import PromiseKit

class BaseImplementationsTest: XCTestCase {
    
    /// Operation queue to be used for this test case.
    static let queue: OperationQueue = {
        
        let queue = OperationQueue()
        
        queue.name = "\(self).queue"
        
        return queue
        
    }()
    
    /// An operation which will wait some time and finish with an unknown error.
    class ExplicitUnknownErrorOperation: AsynchronousOperation<Void, BaseOperationError> {
        
        /// Time to wait before rejecting with an unknown error.
        fileprivate let waitingTime: UInt32
        
        init(waitingTime: UInt32) {
            self.waitingTime = waitingTime
            super.init()
        }
        
        override func main() {
            
            super.main()
            
            sleep(self.waitingTime)
            
            self.finish(error: BaseOperationError.Unknown)
            
        }
        
    }
    
    /**
     A retryable operation which will wait some time and finish with an unknown 
     error.
     */
    class ExplicitUnknownErrorRetryableOperation: RetryableAsynchronousOperation<Void, BaseRetryableOperationError> {
        
        /// Time to wait before rejecting with an unknown error.
        fileprivate let waitingTime: UInt32
        
        init(waitingTime: UInt32) {
            self.waitingTime = waitingTime
            super.init()
        }
        
        override func main() {
            
            super.main()
            
            sleep(self.waitingTime)
            
            self.finish(error: BaseRetryableOperationError.Unknown)
            
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
    
    /// Tests operation error base implementation properly return an unknown 
    /// error.
    func testBaseOperationErrorUnknown() {
        
        let timeToWait: UInt32 = 1
        
        let op = ExplicitUnknownErrorOperation(waitingTime: 1)
        
        type(of: self).queue.addOperation(op)
        
        expect(op.promise.error).toEventually(
            matchError(BaseOperationError.Unknown),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
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
        
    }
    
    /// Tests operation error base implementation properly return an unknown
    /// error.
    func testOperationUnknownErrorTransform() {
        
        let timeToWait: UInt32 = 1
        
        let op = BlockBasedAsynchronousOperation<Void, BaseOperationError>() {
            
            _ -> ProgressAndPromise<Void> in
            
            let progress = Progress(totalUnitCount: 0)
            
            let promise = Promise<Void>() { _, reject in
                
                DispatchQueue.global(qos: .default).async {

                    sleep(timeToWait)
                    
                    reject(
                        NSError(
                            domain: "forcedError",
                            code: -1,
                            userInfo: nil
                        )
                    )
                        
                }
                
            }
            
            return ProgressAndPromise(progress: progress, promise: promise)
            
        }
        
        type(of: self).queue.addOperation(op)
        
        expect(op.promise.error).toEventually(
            matchError(BaseOperationError.Unknown),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
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
        
    }
    
    /// Tests operation error base implementation properly return a cancelled
    /// error.
    func testBaseOperationErrorCancelled() {
        
        let timeToWait: UInt32 = 1
        
        let op = ExplicitUnknownErrorOperation(waitingTime: 1)
        
        type(of: self).queue.addOperation(op)
        
        op.cancel()
        
        expect(op.promise.error).toEventually(
            matchError(BaseOperationError.Cancelled),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
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
        
    }
    
    /// Tests retryable operation error base implementation properly return an 
    /// unknown error.
    func testBaseRetryableOperationErrorUnknown() {
        
        let timeToWait: UInt32 = 1
        
        let op = ExplicitUnknownErrorRetryableOperation(waitingTime: 1)
        
        type(of: self).queue.addOperation(op)
        
        expect(op.promise.error).toEventually(
            matchError(BaseRetryableOperationError.Unknown),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
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
        
    }
    
    /// Tests retryable operation error base implementation properly return a
    /// retry limit reached error.
    func testRetryableOperationUnknownErrorTransform() {
        
        let timeToWait: UInt32 = 1
        
        let op = BlockBasedRetryableAsynchronousOperation<Void, BaseRetryableOperationError>() {
            
            _ -> ProgressAndPromise<Void> in
            
            let progress = Progress(totalUnitCount: 0)
            
            let promise = Promise<Void>() { _, reject in
                
                DispatchQueue.global(qos: .default).async {
                    
                    sleep(timeToWait)
                    
                    reject(
                        NSError(
                            domain: "forcedError",
                            code: -1,
                            userInfo: nil
                        )
                    )
                    
                }
                
            }
            
            return ProgressAndPromise(progress: progress, promise: promise)
            
        }
        
        type(of: self).queue.addOperation(op)
        
        expect(op.promise.error).toEventually(
            matchError(BaseRetryableOperationError.ReachedRetryLimit),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
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
        
    }
    
    /// Tests retryable operation error base implementation properly return a 
    /// cancelled error.
    func testBaseRetryableOperationErrorCancelled() {
        
        let timeToWait: UInt32 = 1
        
        let op = ExplicitUnknownErrorRetryableOperation(waitingTime: 1)
        
        type(of: self).queue.addOperation(op)
        
        op.cancel()
        
        expect(op.promise.error).toEventually(
            matchError(BaseRetryableOperationError.Cancelled),
            timeout: TimeInterval(UInt32(2000) * timeToWait)
        )
        
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
        
    }
    
}
