//
//  BaseRetryableOperationErrorTests.swift
//  Tests
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 29/4/17.
//
//

import XCTest
import OperationsKit
import Nimble

class BaseRetryableOperationErrorTests: XCTestCase {
    
    /**
     Custom errors that are not related with `OperationsKit`.
     
     - dummyError: Just a sample demo.
     */
    fileprivate enum CustomError: Error {
        case dummyError
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
    
    func test__expected_error_can_be_unwrapped() {
        
        let baseError = BaseRetryableOperationError.Cancelled
        
        let operationsKitWrappedError =
            BaseRetryableOperationError.wrap(baseError)
        
        expect(operationsKitWrappedError).to(
            matchError(BaseRetryableOperationError.self)
        )
        
        let unwrappedError = operationsKitWrappedError.unwrap()
        
        expect(unwrappedError).to(matchError(BaseRetryableOperationError.self))
        expect(unwrappedError).to(matchError(baseError))
        
    }
    
    func test__unexpected_error_can_be_unwrapped() {
        
        let baseError = CustomError.dummyError
        
        let operationsKitWrappedError =
            BaseRetryableOperationError.wrap(baseError)
        
        expect(operationsKitWrappedError).to(
            matchError(BaseRetryableOperationError.self)
        )
        expect(operationsKitWrappedError).toNot(matchError(CustomError.self))
        
        let unwrappedError = operationsKitWrappedError.unwrap()
        
        expect(unwrappedError).to(matchError(CustomError.self))
        expect(unwrappedError).to(matchError(baseError))
        
    }
    
    func test__grandchild_unexpected_error_can_be_unwrapped() {
        
        let baseError = CustomError.dummyError
        
        let operationsKitWrappedError = BaseRetryableOperationError.wrap(
            BaseOperationError.wrap(baseError)
        )
        
        expect(operationsKitWrappedError).to(
            matchError(BaseRetryableOperationError.self)
        )
        expect(operationsKitWrappedError).toNot(
            matchError(BaseOperationError.self)
        )
        expect(operationsKitWrappedError).toNot(matchError(CustomError.self))
        
        let unwrappedError = operationsKitWrappedError.unwrap()
        
        expect(unwrappedError).to(matchError(CustomError.self))
        expect(unwrappedError).to(matchError(baseError))
        
    }
    
}
