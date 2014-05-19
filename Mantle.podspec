Pod::Spec.new do |s|
  s.name         = "Mantle"
  s.version      = "1.5-bnr"
  s.summary      = "Model framework for Cocoa and Cocoa Touch."

  s.homepage     = "https://github.com/Mantle/Mantle"
  s.license      = 'MIT'
  s.author       = { "GitHub" => "support@github.com" }

  s.source       = { :git => "https://github.com/bignerdranch/Mantle.git", :branch => "master" }
  s.source_files = 'Mantle/*.{h,m}'
  s.framework    = 'Foundation'

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'
  s.requires_arc = true
end
