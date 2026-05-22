#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'sms_autofill'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin to provide SMS code autofill support'
  s.description      = <<-DESC
Flutter plugin to provide SMS code autofill support
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'sms_autofill/Sources/sms_autofill/**/*.{h,m}'
  s.public_header_files = 'sms_autofill/Sources/sms_autofill/include/**/*.h'
  s.dependency 'Flutter'
  s.ios.deployment_target = '12.0'
end

