Pod::Spec.new do |s|
  s.name             = 'vosk_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin for Vosk speech recognition'
  s.description      = 'A Flutter plugin to integrate Vosk offline speech recognition.'
  s.homepage         = 'https://github.com/alphacep/vosk-flutter'
  s.license          = { :type => 'Apache 2.0' }
  s.author           = { 'Nickolay Shmyrev' => 'nshmyrev@alphacephei.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end