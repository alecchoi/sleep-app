#!/usr/bin/env python3
"""Generate a deterministic, dependency-free Xcode project from the source tree."""
from pathlib import Path
import hashlib
import json
import plistlib
import subprocess

root = Path(__file__).resolve().parents[1]
existing_configs = {}
existing_attributes = {}
old_project_path = root / "SleepApp.xcodeproj" / "project.pbxproj"
if old_project_path.exists():
    old_project = json.loads(subprocess.check_output(
        ["plutil", "-convert", "json", "-o", "-", str(old_project_path)], text=True
    ))
    old_objects = old_project["objects"]
    existing_attributes = old_objects[old_project["rootObject"]].get("attributes", {})
    for old_target in old_objects.values():
        if old_target.get("isa") == "PBXNativeTarget":
            for config_id in old_objects[old_target["buildConfigurationList"]]["buildConfigurations"]:
                old_config = old_objects[config_id]
                existing_configs[(old_target["name"], old_config["name"])] = old_config["buildSettings"]
objects = {}
def key(label):
    return hashlib.sha1(label.encode()).hexdigest()[:24].upper()
def quoted(value):
    return json.dumps(str(value), ensure_ascii=False)
def obj(label, isa, **props):
    identifier = key(label)
    objects[identifier] = {"isa": isa, **props}
    return identifier
class Ref(str):
    pass
def ref(identifier):
    return Ref(identifier)
def encode(value, indent=0):
    if isinstance(value, Ref):
        return value
    if isinstance(value, dict):
        return "{\n" + "".join("\t"*(indent+1)+quoted(k)+" = "+encode(v,indent+1)+";\n" for k,v in value.items()) + "\t"*indent+"}"
    if isinstance(value, list):
        return "(" + ", ".join(encode(v, indent) for v in value) + ")"
    if isinstance(value, int):
        return str(value)
    return quoted(value)

config = obj("file:xcconfig", "PBXFileReference", lastKnownFileType="text.xcconfig",
             path="Config/Project.xcconfig", sourceTree="<group>")
source_files = sorted([*root.glob("App/*.swift"), *root.glob("Native/*.swift"), *root.glob("Extensions/**/*.swift")])
file_refs = {}
for path in source_files:
    rel = path.relative_to(root).as_posix()
    file_refs[rel] = obj("file:"+rel, "PBXFileReference", lastKnownFileType="sourcecode.swift",
                         path=rel, sourceTree="<group>")
asset_ref = obj("assets", "PBXFileReference", lastKnownFileType="folder.assetcatalog",
                path="App/Assets.xcassets", sourceTree="<group>")
privacy_refs = {}
for rel in ["App/PrivacyInfo.xcprivacy", "Extensions/ActivityMonitor/PrivacyInfo.xcprivacy"]:
    privacy_refs[rel] = obj("file:"+rel, "PBXFileReference", lastKnownFileType="text.xml",
                           path=rel, sourceTree="<group>")
package_ref = obj("package:root", "XCLocalSwiftPackageReference", relativePath=".")
target_specs = [
    ("SleepApp", "application", [str(p.relative_to(root)) for p in source_files if p.parent.name in ["App", "Native"]], True),
    ("SleepAppPreview", "application", [str(p.relative_to(root)) for p in source_files if p.parent.name == "App"], True),
    ("ActivityMonitor", "app-extension", ["Extensions/ActivityMonitor/SleepActivityMonitor.swift", "Native/SharedDeviceStore.swift"], True),
    ("ShieldConfiguration", "app-extension", ["Extensions/ShieldConfiguration/SleepShieldConfiguration.swift"], False),
    ("ShieldAction", "app-extension", ["Extensions/ShieldAction/SleepShieldAction.swift"], False)
]
target_ids = {name:key("target:"+name) for name,_,_,_ in target_specs}
products, targets = [], []
for name, kind, sources, needs_core in target_specs:
    is_app = kind == "application"
    is_preview = name == "SleepAppPreview"
    product = obj("product:"+name, "PBXFileReference",
                  explicitFileType="wrapper.application" if is_app else "wrapper.app-extension",
                  includeInIndex=0, path=name+(".app" if is_app else ".appex"), sourceTree="BUILT_PRODUCTS_DIR")
    products.append(ref(product))
    build_files = []
    for source in sources:
        build_files.append(ref(obj("build:"+name+":"+source, "PBXBuildFile", fileRef=ref(file_refs[source]))))
    phase_sources = obj("sources:"+name, "PBXSourcesBuildPhase", buildActionMask=2147483647,
                        files=build_files, runOnlyForDeploymentPostprocessing=0)
    deps, frameworks = [], []
    if needs_core:
        dep = obj("pkgdep:"+name, "XCSwiftPackageProductDependency", package=ref(package_ref), productName="SleepCore")
        deps.append(ref(dep))
        frameworks.append(ref(obj("framework:"+name, "PBXBuildFile", productRef=ref(dep))))
    phase_frameworks = obj("frameworks:"+name, "PBXFrameworksBuildPhase", buildActionMask=2147483647,
                           files=frameworks, runOnlyForDeploymentPostprocessing=0)
    resources = [ref(obj("assetbuild" if not is_preview else "assetbuild:preview", "PBXBuildFile", fileRef=ref(asset_ref)))] if is_app else []
    privacy_path = "App/PrivacyInfo.xcprivacy" if is_app else f"Extensions/{name}/PrivacyInfo.xcprivacy"
    if privacy_path in privacy_refs:
        resources.append(ref(obj("privacybuild:"+name, "PBXBuildFile", fileRef=ref(privacy_refs[privacy_path]))))
    phase_resources = obj("resources:"+name, "PBXResourcesBuildPhase", buildActionMask=2147483647,
                          files=resources, runOnlyForDeploymentPostprocessing=0)
    build_phases = [ref(phase_sources),ref(phase_frameworks),ref(phase_resources)]
    dependencies = []
    if is_app and not is_preview:
        embedded = []
        for extension in ["ActivityMonitor","ShieldConfiguration","ShieldAction"]:
            embedded.append(ref(obj("embed:"+extension, "PBXBuildFile",
                                    fileRef=ref(key("product:"+extension)),
                                    settings={"ATTRIBUTES":["RemoveHeadersOnCopy"]})))
            proxy = obj("proxy:"+extension, "PBXContainerItemProxy", containerPortal=ref(key("project")),
                        proxyType=1, remoteGlobalIDString=ref(target_ids[extension]), remoteInfo=extension)
            dependencies.append(ref(obj("dep:"+extension, "PBXTargetDependency",
                                        target=ref(target_ids[extension]), targetProxy=ref(proxy))))
        build_phases.append(ref(obj("embedphase", "PBXCopyFilesBuildPhase", buildActionMask=2147483647,
                                     dstPath="", dstSubfolderSpec=13, files=embedded,
                                     name="Embed App Extensions", runOnlyForDeploymentPostprocessing=0)))
    configurations = []
    for mode in ["Debug", "Release"]:
        settings = {
            "PRODUCT_NAME":name,
            "PRODUCT_BUNDLE_IDENTIFIER":"$(APP_BUNDLE_ID)" + ("" if is_app else "."+name),
            "SDKROOT":"iphoneos",
            "SUPPORTED_PLATFORMS":"iphoneos iphonesimulator",
            "TARGETED_DEVICE_FAMILY":"1",
            "SWIFT_OPTIMIZATION_LEVEL":"-Onone" if mode=="Debug" else "-O",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS":"$(inherited) DEBUG" if mode=="Debug" else "$(inherited)",
            "INFOPLIST_FILE":"App/Info.plist" if is_app else f"Extensions/{name}/Info.plist",
            "CODE_SIGN_ENTITLEMENTS":"App/SleepApp.entitlements" if is_app else f"Extensions/{name}/{name}.entitlements",
            "GENERATE_INFOPLIST_FILE":"NO",
            "LD_RUNPATH_SEARCH_PATHS":["$(inherited)","@executable_path/Frameworks"] +
                ([] if is_app else ["@executable_path/../../Frameworks"]),
            "SKIP_INSTALL":"NO" if is_app else "YES",
            "APPLICATION_EXTENSION_API_ONLY":"NO" if is_app else "YES"
        }
        # Keep the developer's signing choices and SDK-specific UI overrides.
        settings.update(existing_configs.get((name, mode), {}))
        settings["ONLY_ACTIVE_ARCH"] = "YES" if mode == "Debug" else "NO"
        if is_preview:
            settings["PRODUCT_BUNDLE_IDENTIFIER"] = "$(APP_BUNDLE_ID).preview"
            settings["CODE_SIGN_ENTITLEMENTS"] = ""
            settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) SLEEPAPP_PREVIEW" + (" DEBUG" if mode == "Debug" else "")
            settings["INFOPLIST_FILE"] = "Config/Preview-Info.plist"
            settings["DEVELOPMENT_TEAM"] = existing_configs.get(
                (name, mode), existing_configs.get(("SleepApp", mode), {})
            ).get("DEVELOPMENT_TEAM", "")
        if is_app:
            settings["ASSETCATALOG_COMPILER_APPICON_NAME"]="AppIcon"
            settings["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"]="AccentColor"
        configurations.append(ref(obj("config:"+name+mode,"XCBuildConfiguration",
                                       baseConfigurationReference=ref(config), buildSettings=settings,name=mode)))
    config_list=obj("configlist:"+name,"XCConfigurationList",buildConfigurations=configurations,
                    defaultConfigurationIsVisible=0,defaultConfigurationName="Release")
    obj("target:"+name,"PBXNativeTarget",name=name,productName=name,productReference=ref(product),
        productType="com.apple.product-type."+kind,buildConfigurationList=ref(config_list),
        buildPhases=build_phases,buildRules=[],dependencies=dependencies,packageProductDependencies=deps)
    targets.append(ref(target_ids[name]))

product_group=obj("group:products","PBXGroup",children=products,name="Products",sourceTree="<group>")
source_group=obj("group:sources","PBXGroup",children=[ref(v) for v in file_refs.values()]+[ref(asset_ref)]+[ref(v) for v in privacy_refs.values()],
                 name="Source",sourceTree="<group>")
main_group=obj("group:main","PBXGroup",children=[ref(source_group),ref(config),ref(product_group)],sourceTree="<group>")
project_configs=[]
for mode in ["Debug","Release"]:
    project_configs.append(ref(obj("projectconfig:"+mode,"XCBuildConfiguration",name=mode,
        buildSettings={"CLANG_ENABLE_MODULES":"YES","CLANG_ENABLE_OBJC_ARC":"YES",
                       "SWIFT_VERSION":"5.0","IPHONEOS_DEPLOYMENT_TARGET":"17.0",
                       "DEBUG_INFORMATION_FORMAT":"dwarf" if mode=="Debug" else "dwarf-with-dsym"})))
project_configlist=obj("projectconfiglist","XCConfigurationList",buildConfigurations=project_configs,
                        defaultConfigurationIsVisible=0,defaultConfigurationName="Release")
project=obj("project","PBXProject",attributes={
    **existing_attributes,
    "BuildIndependentTargetsInParallel":"YES","LastUpgradeCheck":"1640",
    "TargetAttributes":{ref(v):{
        **existing_attributes.get("TargetAttributes", {}).get(v, {}),
        "CreatedOnToolsVersion":"16.4",
        "SystemCapabilities":({} if name == "SleepAppPreview" else {
            "com.apple.ApplicationGroups.iOS":{"enabled":1},
            "com.apple.FamilyControls":{"enabled":1}
        })}
        for name,v in target_ids.items()}
},buildConfigurationList=ref(project_configlist),compatibilityVersion="Xcode 14.0",
   developmentRegion="en",hasScannedForEncodings=0,knownRegions=["en","Base"],
   mainGroup=ref(main_group),productRefGroup=ref(product_group),projectDirPath="",
   projectRoot="",targets=targets,packageReferences=[ref(package_ref)])
project_dir=root/"SleepApp.xcodeproj"
project_dir.mkdir(exist_ok=True)
(project_dir/"project.pbxproj").write_text("// !$*UTF8*$!\n"+encode({
    "archiveVersion":1,"classes":{},"objectVersion":56,
    "objects":{Ref(k):v for k,v in objects.items()},"rootObject":ref(project)
})+"\n")
schemes=project_dir/"xcshareddata"/"xcschemes"
schemes.mkdir(parents=True,exist_ok=True)
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
   <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids["SleepApp"]}" BuildableName="SleepApp.app" BlueprintName="SleepApp" ReferencedContainer="container:SleepApp.xcodeproj"/>
  </BuildActionEntry>
 </BuildActionEntries></BuildAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES">
  <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids["SleepApp"]}" BuildableName="SleepApp.app" BlueprintName="SleepApp" ReferencedContainer="container:SleepApp.xcodeproj"/></BuildableProductRunnable>
 </LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(schemes/"SleepApp.xcscheme").write_text(scheme)
preview_scheme = scheme.replace(target_ids["SleepApp"], target_ids["SleepAppPreview"]).replace(
    'BuildableName="SleepApp.app"', 'BuildableName="SleepAppPreview.app"'
).replace('BlueprintName="SleepApp"', 'BlueprintName="SleepAppPreview"')
(schemes/"SleepAppPreview.xcscheme").write_text(preview_scheme)
preview_info = plistlib.loads((root/"App"/"Info.plist").read_bytes())
preview_info.pop("SleepAppGroupIdentifier", None)
preview_info["CFBundleDisplayName"] = "Sleep App"
(root/"Config"/"Preview-Info.plist").write_bytes(plistlib.dumps(preview_info))
for name,point,principal in [
    ("ActivityMonitor","com.apple.deviceactivity.monitor-extension","SleepActivityMonitor"),
    ("ShieldConfiguration","com.apple.ManagedSettingsUI.shield-configuration-service","SleepShieldConfiguration"),
    ("ShieldAction","com.apple.ManagedSettings.shield-action-service","SleepShieldAction")
]:
    folder=root/"Extensions"/name
    info={
        "CFBundleDisplayName":"Sleep App "+name,
        "CFBundleIdentifier":"$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleExecutable":"$(EXECUTABLE_NAME)",
        "CFBundleName":"$(PRODUCT_NAME)","CFBundlePackageType":"XPC!",
        "CFBundleShortVersionString":"$(MARKETING_VERSION)","CFBundleVersion":"$(CURRENT_PROJECT_VERSION)",
        "SleepAppGroupIdentifier":"$(APP_GROUP_IDENTIFIER)",
        "NSExtension":{"NSExtensionPointIdentifier":point,
                       "NSExtensionPrincipalClass":"$(PRODUCT_MODULE_NAME)."+principal}
    }
    if not (folder/"Info.plist").exists():
        (folder/"Info.plist").write_bytes(plistlib.dumps(info))
    if not (folder/(name+".entitlements")).exists():
        (folder/(name+".entitlements")).write_bytes((root/"App"/"SleepApp.entitlements").read_bytes())
print(f"Generated {project_dir.name}: {len(targets)} targets; {len(objects)} project objects")
