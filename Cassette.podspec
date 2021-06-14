Pod::Spec.new do |spec|
  spec.name             = 'Cassette'
  spec.version          = '1.0.0-beta4'

  spec.license          =  { :type => 'BSD-2-Clause' }

  spec.homepage         = 'https://github.com/linkedin/cassette'
  spec.authors          = 'LinkedIn'
  spec.summary          = 'A lightning fast file-based FIFO queue for iOS and OSX.'

  spec.source           =  { :git => 'https://github.com/linkedin/cassette.git', :tag => spec.version }

  spec.public_header_files = 'Cassette/*.h'
  spec.source_files        = 'Cassette/*.{h,m}'

  spec.ios.deployment_target = '8.0'
  spec.osx.deployment_target = '10.11'

  spec.requires_arc     = true
end
