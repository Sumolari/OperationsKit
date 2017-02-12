//
//  Progress+Reactive.swift
//  Pods
//
//  Created by Lluís Ulzurrun de Asanza Sàez on 12/2/17.
//
//

import ReactiveSwift

extension Reactive where Base: Progress {
    
    /// Sets the total unit count to be reflected by the progress.
    public var totalUnitCount: BindingTarget<Int64> {
        return makeBindingTarget { $0.totalUnitCount = $1 }
    }
    
    /// Sets the completed unit count to be reflected by the progress.
    public var completedUnitCount: BindingTarget<Int64> {
        return makeBindingTarget { $0.completedUnitCount = $1 }
    }
    
}
