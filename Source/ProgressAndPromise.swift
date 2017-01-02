//
//  ProgressAndPromise.swift
//  OperationsKit
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 10/12/16.
//
//

import Foundation
import PromiseKit

/**
 A `ProgressAndPromise` is a tuple of promise wrapping an asynchronous operation
 and a progress tracking its execution.
 */
public struct ProgressAndPromise<ReturnType> {
    /// Progress tracking advances in underlying asynchronous operation.
    public let progress: Progress
    /// Promise wrapping an asyncronous operation.
    public let promise: Promise<ReturnType>
    /**
     Initializes a new instance given a progress and a promise.
     */
    public init(progress: Progress, promise: Promise<ReturnType>) {
        self.progress = progress
        self.promise = promise
    }
}
