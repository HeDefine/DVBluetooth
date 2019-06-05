Pod::Spec.new do |s|
  s.name         = "DVBluetooth"
  s.version      = "0.2.0"
  s.summary      = "Bluetooth manager for iOS."

  s.description  = "The DVBluetooth help us easier connect and control bluetooth peripheral. 
  It depends on CoreBluetooth."

  s.homepage     = "https://github.com/HeDefine/DVBluetooth"
  # s.screenshots  = "www.example.com/screenshots_1.gif", "www.example.com/screenshots_2.gif"

  s.license      = "MIT"

  s.author             = { "Devine He" => "hedingfei1993@126.com" }

  #s.platform     = :ios
  s.platform     = :ios, "9.0"

  s.source       = { :git => "https://github.com/HeDefine/DVBluetooth.git", :tag => "0.2.0" }
  s.source_files  = "DVBluetooth/**/*.{h,m}"
  s.exclude_files = "DVBluetoothExample"
  # s.public_header_files = "Classes/**/*.h"


  s.frameworks = "Foundation", "CoreBluetooth"

end
