require 'xcodeproj'
project = Xcodeproj::Project.new('TV2Safari.xcodeproj')
target = project.new_target(:ui_test_bundle, 'TV2SafariTests', :ios, '15.0')
target.add_file_references([project.main_group.new_file('scripts/safari_xcui/TV2SafariTests.swift')])
target.build_configurations.each do |config|
  config.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>'org.example.TV2SafariFeasibilityTests', 'GENERATE_INFOPLIST_FILE'=>'YES', 'SWIFT_VERSION'=>'5.0', 'CODE_SIGNING_ALLOWED'=>'NO', 'TARGETED_DEVICE_FAMILY'=>'1', 'SDKROOT'=>'iphonesimulator'})
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.save_as(project.path, 'TV2Safari', true)
