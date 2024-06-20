Pod::Spec.new do |spec|
  spec.name = "VerIDCommonTypes"
  spec.version = "1.0.0"
  spec.summary = "Common types for Ver-ID SDK classes"
  spec.homepage = "https://github.com/AppliedRecognition/Ver-ID-Common-Types-Apple"
  spec.license = { :type => "Commercial", :file => "LICENCE.txt" }
  spec.author = "Jakub Dolejs"
  spec.platform = :ios, "13.0"
  spec.swift_versions = "5.0"
  spec.source = { :git => "https://github.com/AppliedRecognition/Ver-ID-Common-Types-Apple.git", :branch => "main" }
  spec.source_files = "Sources/VerIDCommonTypes/*.swift"
end
