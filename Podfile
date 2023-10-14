use_frameworks!
source 'https://cdn.cocoapods.org/'
platform :ios, '12.0'

target 'Combinestagram' do
    pod 'RxSwift', '5.1.1'
    pod 'RxRelay', '5.1.1'
end

post_install do |installer|
    installer.generated_projects.each do |project|
        project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
            end
        end
    end
end
