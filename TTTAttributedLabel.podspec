Pod::Spec.new do |s|
  s.name         = 'TTTAttributedLabel'
  s.version      = '1.13.4-quizlet'
  s.authors      = { 'Mattt Thompson' => 'm@mattt.me' }
  s.homepage     = 'https://github.com/TTTAttributedLabel/TTTAttributedLabel'
  s.platform     = :ios
  s.summary      = 'A drop-in replacement for UILabel that supports attributes, data detectors, links, and more.'
  s.source       = { :git => 'https://github.com/quizlet/TTTAttributedLabel.git', :tag => s.version }
  s.license      = 'MIT'
  s.frameworks   = 'UIKit', 'CoreText', 'CoreGraphics', 'QuartzCore'
  s.source_files = 'TTTAttributedLabel'
  s.requires_arc = true
  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '9.0'
  s.social_media_url = 'https://twitter.com/mattt'
end
