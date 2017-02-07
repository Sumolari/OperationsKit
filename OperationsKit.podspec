Pod::Spec.new do |s|

  s.name         = "OperationsKit"
  s.version      = "0.0.3"
  s.summary      = "PromiseKit extension for OperationsQueue."

  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  s.description  = <<-DESC
  `OperationsKit` is a collection of utilities built on top of `PromiseKit`
  designed to make working with operation queues easier.

  Main features are:

  - `NSOperation` subclass for `PromiseKit`-based asynchronous operation.
  - Smart concurrency limits based on memory usage.
  - Convenience method to run collection of blocks in parallel.
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
  s.dependency "ReactiveCocoa", "~> 5.0.0"

end
