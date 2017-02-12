//
//  RetryableAsynchronousOperationTest.swift
//  Tests
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 10/2/17.
//
//

import XCTest
import OperationsKit
import PromiseKit
import Nimble

class RetryableAsynchronousOperationTest: XCTestCase {
    
    /// Queue used to enqueue operations.
    static let queue: OperationQueue = {
        
        let queue = OperationQueue()
        
        queue.maxConcurrentOperationCount = 1
        
        queue.name = "\(self)"
        
        return queue
        
    }()
    
    /**
     An operation which always repeat itself until reaching maximum attempts.
     */
    class UnlimitedOperation: RetryableAsynchronousOperation<Void, BaseRetryableOperationError> {
        
        /// Time to sleep before repeating again.
        fileprivate let waitTime: UInt32
        
        init(waitTime: UInt32, maximumAttempts: UInt64) {
            self.waitTime = waitTime
            super.init(maximumAttempts: maximumAttempts)
        }
        
        override func main() {
            
            super.main()
            
            usleep(self.waitTime * 1000)
            
            self.main()
            
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
    
    /// Tests that the operation is executed only the maximum amount of times
    /// specified.
    func testMaximumExecutionAttempts() {
        
        let waitTime: UInt32 = 1
        let maximumAttempts: UInt64 = 3
        let expectationsWaitTime = TimeInterval((waitTime + 1) * UInt32(maximumAttempts))
        
        let op = UnlimitedOperation(waitTime: waitTime, maximumAttempts: maximumAttempts)
        
        type(of: self).queue.addOperation(op)
        
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
        
        expect(op.result?.error).toEventually(
            matchError(BaseRetryableOperationError.ReachedRetryLimit),
            timeout: expectationsWaitTime
        )
        
    }
    
}
