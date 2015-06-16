Pod::Spec.new do |spec|
  spec.name             = 'Cassette'
  spec.version          = '0.1.0'

  spec.license          =  { :type => 'MIT' }

  spec.homepage         = 'https://github.com/segmentio/cassette'
  spec.authors          = { 'Segment' => 'friends@segment.com' }
  spec.summary          = 'A lightning fast file-based FIFO queue for iOS and OSX.'

  spec.source           =  { :git => 'https://github.com/segmentio/cassette.git', :tag => spec.version }

  s.public_header_files = 'Cassette/*.h'
  spec.source_files     = 'Cassette/*.{h,m}'

  spec.ios.deployment_target = '8.0'
  spec.osx.deployment_target = '10.9'

  spec.requires_arc     = true
end
