Pod::Spec.new do |spec|
  spec.name = "VerIDCommonTypes"
  spec.version = "1.0.0"
  spec.summary = "Common types for Ver-ID SDK classes"
  spec.homepage = "https://github.com/AppliedRecognition/Ver-ID-Common-Types-Apple"
  spec.license = { :type => "Commercial", :file => "LICENCE.txt" }
  spec.author = "Jakub Dolejs"
  spec.platform = :ios, "13.0"
  spec.swift_versions = ["5.5", "5.6", "5.7", "5.8", "5.9", "5.10"]
  spec.source = { :git => "https://github.com/AppliedRecognition/Ver-ID-Common-Types-Apple.git", :tag => "#{spec.version}" }
  spec.source_files = "Sources/VerIDCommonTypes/*.swift"
end
