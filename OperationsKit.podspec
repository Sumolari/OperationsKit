Pod::Spec.new do |s|

  s.name         = "OperationsKit"
  s.version      = "0.2.0"
  s.summary      = "Operation subclasses offering a promise-based interface."

  s.description  = <<-DESC
  `OperationsKit` is a collection of `Operation` subclasses which offer a
  promise-based interface to chain results, built on top of `PromiseKit`.

  Its main focus is to offer an easy to use, promise-based approach to work
  with heavy operations, giving users additional methods to spawn children
  operations without deadlocking the system and tracking operation's progress.

  Main features are:

  - `Operation` subclasses for `PromiseKit`-based asynchronous operation.
  - Ready-to-use retryable operation for those situation when a recoverable
  error may arise.
  - Subclasses to wrap blocks returning promises in `Operation`s.
  - Convenience method to wait for children operations without blocking parent's
  queue.
  - Built-in progress to track asynchronous operation status.
  - Extensive code coverage.
                   DESC

  s.homepage = "https://github.com/Sumolari/OperationsKit"
  s.license  = { :type => "MIT", :file => "LICENSE" }
  s.author   = { "Lluís Ulzurrun de Asanza i Sàez" => "me@llu.is" }

  s.source = {
  	:git => "https://github.com/Sumolari/OperationsKit.git",
  	:tag => "#{s.version}"
  }

  s.ios.deployment_target  = '8.0'
  s.osx.deployment_target  = '10.10'

  s.source_files  = "Source", "Source/**/*.{h,m,swift}"

  s.dependency "PromiseKit", "~> 4.1"
  s.dependency "ReactiveCocoa", "~> 5.0"
  s.dependency "Result", "~> 3.1"

end
