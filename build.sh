set -e
scheme=VerIDCommonTypes
archivePath="archives"
iphoneArchivePath="${archivePath}/${scheme}.xcarchive"
simulatorArchivePath="${archivePath}/${scheme}Simulator.xcarchive"
outputFrameworkPath="${scheme}.xcframework"
rm -rf "${archivePath}"
xcodebuild archive -scheme ${scheme} -destination "platform=iOS,OS=13.0,name=iPhone 15" \
    -archivePath "${iphoneArchivePath}" -configuration Release SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=YES OTHER_SWIFT_FLAGS=-no-verify-emitted-module-interface
xcodebuild archive -scheme ${scheme} -destination "platform=iOS simulator,OS=13.0,name=iPhone 15" \
    -archivePath "${simulatorArchivePath}" -configuration Release SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=YES OTHER_SWIFT_FLAGS=-no-verify-emitted-module-interface
rm -rf "${outputFrameworkPath}"
xcodebuild -create-xcframework \
    -framework "${iphoneArchivePath}/Products/usr/local/lib/${scheme}.framework" \
    -framework "${simulatorArchivePath}/Products/usr/local/lib/${scheme}.framework" \
    -output "${outputFrameworkPath}"
rm -rf "${archivePath}"
