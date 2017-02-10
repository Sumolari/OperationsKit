//
//  RecursionTest.swift
//  Tests
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 10/2/17.
//
//

import XCTest
import OperationsKit
import PromiseKit
import Nimble

class RecursionTest: XCTestCase {
    
    /// An operation which compute values of Fibonnacci sequence.
    class FibonacciOperation: AsynchronousOperation<UInt32, BaseOperationError> {
        
        /// Queue used to enqueue children operations.
        static let queue: OperationQueue = {
            
            let queue = OperationQueue()
            
            queue.maxConcurrentOperationCount = 1
            
            queue.name = "\(self)"
            
            return queue
            
        }()
        
        /// Desired sequence value.
        fileprivate let desiredValue: UInt32
        
        init(desiredValue: UInt32) {
            self.desiredValue = desiredValue
            super.init()
        }
        
        override func main() {
            
            super.main()
            
            print(String(format: "Computing fib(%d)", self.desiredValue))
            
            guard self.desiredValue > 1 else {
                print(
                    String(
                        format: "fib(%d)=%d",
                        self.desiredValue,
                        self.desiredValue
                    )
                )
                return self.finish(self.desiredValue)
            }
            
            let nMinusOne = FibonacciOperation(
                desiredValue: self.desiredValue - 1
            )
            
            let nMinusTwo = FibonacciOperation(
                desiredValue: self.desiredValue - 2
            )
            
            let operations = [nMinusOne, nMinusTwo]
            
            type(of: self).queue.addOperations(
                operations,
                waitUntilFinished: false
            )
            
            self.markAsFinished()
            
            when(fulfilled: operations.map { $0.promise })
                .then { results -> Void in
                    
                    let sum = results.reduce(0, +)
                    
                    print(
                        String(
                            format: "fib(%d)=%d",
                            self.desiredValue,
                            sum
                        )
                    )
                    
                    self.finish(sum)
                    
                }
                .catch { error in self.finish(error: BaseOperationError.wrap(error)) }
            
        }
        
    }

    
    /**
     An operation which will enqueue a new operation until reaching a certain 
     depth.
     */
    class DrillOperation: AsynchronousOperation<UInt32, BaseOperationError> {
        
        /// Time to wait before enqueuing next drilling operation.
        static let drillingTime: UInt32 = 1
        
        /// Queue used to enqueue children operations.
        static let drillQueue: OperationQueue = {
            
            let queue = OperationQueue()
            
            queue.maxConcurrentOperationCount = 1
            
            queue.name = "Drill Queue"
            
            return queue
            
        }()
        
        /// Current depth.
        fileprivate let currentDepth: UInt32
        /// Required depth.
        fileprivate let requiredDepth: UInt32
        
        convenience init(requiredDepth: UInt32) {
            self.init(currentDepth: 0, requiredDepth: requiredDepth)
        }
        
        fileprivate init(currentDepth: UInt32, requiredDepth: UInt32) {
            
            precondition(currentDepth <= requiredDepth)
            
            self.currentDepth = currentDepth
            self.requiredDepth = requiredDepth
            
            super.init()
            
        }
        
        override func main() {
            
            super.main()
            
            print(
                String(
                    format: "Drilling at depth %d of %d",
                    self.currentDepth,
                    self.requiredDepth
                )
            )
            
            guard self.currentDepth < self.requiredDepth else {
                return self.finish(self.currentDepth)
            }
            
            sleep(type(of: self).drillingTime)
            
            let child = DrillOperation(
                currentDepth: self.currentDepth + 1,
                requiredDepth: self.requiredDepth
            )
            
            type(of: self).drillQueue.addOperation(child)
            
            self.markAsFinished()
            
            child.promise
                .then { depth -> Void in self.finish(depth) }
                .catch { error in
                    
                    guard let knownError = error as? BaseOperationError else {
                        return self.finish(error: .unknown)
                    }
                    
                    self.finish(error: knownError)
                    
                }
            
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
    
    /// Tests that marking as finished an operation will allow execution of
    /// other operations in a serial queue.
    func testMarkAsFinished() {
        
        let timeToWait: UInt32 = 5
        
        let op = DrillOperation(requiredDepth: timeToWait)
        
        type(of: op).drillQueue.addOperation(op)
        
        expect(op.promise.value).toEventually(
            equal(timeToWait),
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
        
    }
    
    /// Tests that marking as finished an operation will allow execution of
    /// multiple child operations in a serial queue.
    func testMarkAsFinishedWithMultipleChildren() {
        
        let timeToWait: UInt32 = 1
        
        let result: (UInt32, UInt32) = (10, 55)
        
        let op = FibonacciOperation(desiredValue: result.0)
        
        type(of: op).queue.addOperation(op)
        
        expect(op.promise.value).toEventually(
            equal(result.1),
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
        
    }

}
