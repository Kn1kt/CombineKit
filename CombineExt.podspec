Pod::Spec.new do |s|
  s.name             = 'CombineExtensions'
  s.version          = '1.0.0'
  s.summary          = 'A collection of operators, publishers and schedulers for Combine'
  s.description      = 'A collection of operators, publishers and schedulers for Combine'
  s.homepage         = 'https://github.com/Kn1kt/CombineExtensions'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Nikita Konashenko' => 'https://github.com/Kn1kt' }
  s.source           = { :git => 'https://github.com/Kn1kt/CombineExtensions', :tag => s.version }
  
  s.ios.deployment_target = '13.0'

  s.source_files = 'Sources/**/*.swift'
  s.frameworks = 'Combine'
  s.swift_version = '5'
end
