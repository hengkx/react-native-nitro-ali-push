require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-nitro-ali-push"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "https://github.com/hengkx/react-native-nitro-ali-push"
  s.license      = "MIT"
  s.authors      = { "hengkx" => "ycxzhkx@gmail.com" }

  s.platforms    = { :ios => "13.0", :tvos => "13.0" }
  s.source       = { :git => "https://github.com/hengkx/react-native-nitro-ali-push.git", :tag => "v#{s.version}" }

  s.source_files = "ios/**/*.{swift}"
  s.requires_arc = true
  s.swift_version = "5.0"

  # 引入 Nitro 生成的原生文件与构建配置（C++ 互操作、NitroModules 依赖等）。
  load 'nitrogen/generated/ios/NitroAliPush+autolinking.rb'
  add_nitrogen_files(s)

  # 阿里云推送 SDK（CloudPushSDK.framework）。
  # 推荐方式：放到本库 ios/ 目录下，并取消下面注释；或改为你自己的引入方式。
  # s.vendored_frameworks = 'ios/CloudPushSDK.framework'

  s.dependency "React-Core"
end
