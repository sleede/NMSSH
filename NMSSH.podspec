Pod::Spec.new do |spec|
  spec.name         = "NMSSH"
  spec.version      = "2.3.3"
  spec.summary      = "NMSSH is a clean, easy-to-use, unit tested framework for iOS and OSX that wraps libssh2."
  spec.homepage     = "https://github.com/NMSSH/NMSSH"
  spec.license      = 'MIT'
  spec.authors      = { "Christoffer Lejdborg" => "hello@9muses.se", "Tommaso Madonia" => "tommaso@madonia.me" }

  spec.source       = { :git => "https://github.com/NMSSH/NMSSH.git", :tag => spec.version.to_s }

  spec.requires_arc = true
  spec.platform = :ios
  spec.platform = :osx

  spec.source_files = 'NMSSH', 'NMSSH/**/*.{h,m}'
  spec.public_header_files  = 'NMSSH/*.h', 'NMSSH/Protocols/*.h', 'NMSSH/Config/NMSSHLogger.h', 'NMSSH/Libraries/libssh2.xcframework/*/Headers/*.h'
  spec.private_header_files = 'NMSSH/Config/NMSSH+Protected.h', 'NMSSH/Config/socket_helper.h'
  spec.libraries    = 'z'
  spec.framework    = 'CFNetwork'

  spec.ios.deployment_target  = '12.0'
  spec.osx.deployment_target  = '11.0'
  
  spec.vendored_frameworks = 'NMSSH/Libraries/libssh2.xcframework', 'NMSSH/Libraries/libssl.xcframework', 'NMSSH/Libraries/libcrypto.xcframework'

  spec.xcconfig = {
    "OTHER_LDFLAGS" => "-ObjC",
    "HEADER_SEARCH_PATHS" => "$(PODS_ROOT)/NMSSH/NMSSH/Libraries/include"
  }

end
