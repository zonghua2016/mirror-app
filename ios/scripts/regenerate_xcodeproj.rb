require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'LockScreenMirror.xcodeproj')
BUNDLE_BASE = 'com.tongzonghua.lockscreenmirror.dev'

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)

app_target = project.new_target(:application, 'LockScreenMirror', :ios, '17.0')
widget_target = project.new_target(:app_extension, 'LockScreenMirrorWidgetsExtension', :ios, '17.0')
capture_target = project.new_target(:app_extension, 'LockScreenMirrorCaptureExtension', :ios, '18.0')
capture_target.product_type = 'com.apple.product-type.extensionkit-extension'

[app_target, widget_target, capture_target].each do |target|
  target.build_configurations.each do |config|
    config.build_settings['SWIFT_VERSION'] = '6.0'
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
    config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  end
end

app_target.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_BASE
  config.build_settings['INFOPLIST_FILE'] = 'LockScreenMirror/Info.plist'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'LockScreenMirror/LockScreenMirror.entitlements'
end

widget_target.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{BUNDLE_BASE}.widgets"
  config.build_settings['INFOPLIST_FILE'] = 'LockScreenMirrorWidgets/Info.plist'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
end

capture_target.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{BUNDLE_BASE}.capture"
  config.build_settings['INFOPLIST_FILE'] = 'LockScreenMirrorCaptureExtension/Info.plist'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'LockScreenMirrorCaptureExtension/LockScreenMirrorCaptureExtension.entitlements'
end

app_group = project.main_group.new_group('LockScreenMirror', 'LockScreenMirror')
widget_group = project.main_group.new_group('LockScreenMirrorWidgets', 'LockScreenMirrorWidgets')
capture_group = project.main_group.new_group('LockScreenMirrorCaptureExtension', 'LockScreenMirrorCaptureExtension')
shared_group = project.main_group.new_group('Shared', 'Shared')

app_sources = %w[
  AppDelegate.swift
  SceneDelegate.swift
  AppCoordinator.swift
  MirrorViewModel.swift
  CameraSessionController.swift
  CameraPreviewView.swift
  FaceTrackingManager.swift
  MirrorOverlay.swift
  MirrorScreenView.swift
  MirrorIntents.swift
  MirrorLiveActivityManager.swift
]

app_refs = {}
app_sources.each do |path|
  app_refs[path] = app_group.new_file(path)
end
app_target.add_file_references(app_refs.values)

assets_ref = app_group.new_file('Assets.xcassets')
app_target.resources_build_phase.add_file_reference(assets_ref, true)

widget_ref = widget_group.new_file('MirrorWidgets.swift')
widget_target.add_file_references([widget_ref])

capture_sources = %w[
  LockScreenMirrorCaptureExtension.swift
  MirrorCaptureView.swift
]
capture_refs = capture_sources.map { |path| capture_group.new_file(path) }
capture_target.add_file_references(capture_refs)

# Reuse app camera pipeline files in capture extension target.
capture_shared_from_app = %w[
  CameraSessionController.swift
  CameraPreviewView.swift
  FaceTrackingManager.swift
  MirrorOverlay.swift
]
capture_target.add_file_references(capture_shared_from_app.map { |path| app_refs.fetch(path) })

shared_sources = %w[
  MirrorShapeStyle.swift
  MirrorSharedConfig.swift
  MirrorLiveActivityModels.swift
  StartMirrorCaptureIntent.swift
]
shared_refs = {}
shared_sources.each do |path|
  shared_refs[path] = shared_group.new_file(path)
end

app_target.add_file_references([
  shared_refs['MirrorShapeStyle.swift'],
  shared_refs['MirrorSharedConfig.swift'],
  shared_refs['MirrorLiveActivityModels.swift'],
  shared_refs['StartMirrorCaptureIntent.swift']
])

widget_target.add_file_references([
  shared_refs['MirrorShapeStyle.swift'],
  shared_refs['MirrorLiveActivityModels.swift'],
  shared_refs['StartMirrorCaptureIntent.swift']
])

capture_target.add_file_references([
  shared_refs['MirrorShapeStyle.swift'],
  shared_refs['MirrorSharedConfig.swift'],
  shared_refs['StartMirrorCaptureIntent.swift']
])

def add_framework(project, target, framework)
  frameworks = project.frameworks_group
  path = "System/Library/Frameworks/#{framework}.framework"
  ref = frameworks.find_file_by_path(path) || frameworks.new_file(path)
  target.frameworks_build_phase.add_file_reference(ref, true)
end

%w[AVFoundation Vision ActivityKit AppIntents].each { |fw| add_framework(project, app_target, fw) }
%w[WidgetKit ActivityKit AppIntents].each { |fw| add_framework(project, widget_target, fw) }
%w[AVFoundation Vision LockedCameraCapture AppIntents].each { |fw| add_framework(project, capture_target, fw) }

app_target.add_dependency(widget_target)
app_target.add_dependency(capture_target)
embed_plugin_phase = app_target.copy_files_build_phases.find { |phase| phase.name == 'Embed App Extensions' }
embed_plugin_phase ||= app_target.new_copy_files_build_phase('Embed App Extensions')
embed_plugin_phase.symbol_dst_subfolder_spec = :plug_ins
embed_plugin_phase.dst_subfolder_spec = '13'
embed_plugin_phase.add_file_reference(widget_target.product_reference, true)

embed_extensionkit_phase = app_target.copy_files_build_phases.find { |phase| phase.name == 'Embed ExtensionKit Extensions' }
embed_extensionkit_phase ||= app_target.new_copy_files_build_phase('Embed ExtensionKit Extensions')
embed_extensionkit_phase.dst_subfolder_spec = '16'
embed_extensionkit_phase.add_file_reference(capture_target.product_reference, true)

project.save

def create_shared_scheme(project, build_target:, launch_target:, name:)
  scheme = Xcodeproj::XCScheme.new
  scheme.configure_with_targets(build_target, nil, launch_target: launch_target)
  scheme.save_as(project.path, name, true)
end

create_shared_scheme(project, build_target: app_target, launch_target: app_target, name: 'LockScreenMirror')
create_shared_scheme(project, build_target: widget_target, launch_target: app_target, name: 'LockScreenMirrorWidgetsExtension')
create_shared_scheme(project, build_target: capture_target, launch_target: app_target, name: 'LockScreenMirrorCaptureExtension')
