#!/usr/bin/env python3
"""Generate a complete Xcode project for Sunset Log."""

from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path("/workspace/SunsetLog")
APP = ROOT / "SunsetLog"
TESTS = ROOT / "SunsetLogTests"
PROJ = ROOT / "SunsetLog.xcodeproj"


def hid(text: str) -> str:
    digest = hashlib.md5(text.encode()).hexdigest()[:24].upper()
    return digest


def collect(folder: Path, suffixes: tuple[str, ...]) -> list[Path]:
    files = [p for p in folder.rglob("*") if p.is_file() and p.suffix in suffixes]
    return sorted(files, key=lambda p: str(p).lower())


swift_app = collect(APP, (".swift",))
swift_tests = collect(TESTS, (".swift",))
resources = collect(APP / "Resources", (".jpg",))
plist = APP / "Info.plist"
privacy = APP / "PrivacyInfo.xcprivacy"
assets = APP / "Assets.xcassets"

# IDs
ids = {
    "project": hid("project"),
    "app_target": hid("app_target"),
    "test_target": hid("test_target"),
    "app_product": hid("app_product"),
    "test_product": hid("test_product"),
    "app_build": hid("app_build"),
    "test_build": hid("test_build"),
    "project_config_list": hid("project_config_list"),
    "app_config_list": hid("app_config_list"),
    "test_config_list": hid("test_config_list"),
    "proj_debug": hid("proj_debug"),
    "proj_release": hid("proj_release"),
    "app_debug": hid("app_debug"),
    "app_release": hid("app_release"),
    "test_debug": hid("test_debug"),
    "test_release": hid("test_release"),
    "sources_phase": hid("sources_phase"),
    "resources_phase": hid("resources_phase"),
    "frameworks_phase": hid("frameworks_phase"),
    "test_sources_phase": hid("test_sources_phase"),
    "test_frameworks_phase": hid("test_frameworks_phase"),
    "main_group": hid("main_group"),
    "app_group": hid("app_group"),
    "test_group": hid("test_group"),
    "products_group": hid("products_group"),
    "assets_file": hid("assets_file"),
    "plist_file": hid("plist_file"),
    "privacy_file": hid("privacy_file"),
}

file_ids = {p: hid(f"file:{p.relative_to(ROOT)}") for p in swift_app + swift_tests + resources}
build_ids = {p: hid(f"build:{p.relative_to(ROOT)}") for p in swift_app + swift_tests + resources}

# Nested groups under app
group_paths = {}
for p in swift_app:
    rel = p.parent.relative_to(APP)
    while True:
        key = str(rel)
        if key not in group_paths:
            group_paths[key] = hid(f"group:{key}")
        if key in (".", ""):
            break
        rel = rel.parent
        if str(rel) == ".":
            if "." not in group_paths:
                group_paths["."] = ids["app_group"]
            break

# resources group
ids["resources_group"] = hid("resources_group")
ids["seed_group"] = hid("seed_group")


def file_ref(path: Path, extra: str = "") -> str:
    name = path.name
    rel = path.relative_to(ROOT)
    fid = file_ids[path]
    return f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};\n'


def resource_ref(path: Path) -> str:
    name = path.name
    fid = file_ids[path]
    return f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = image.jpeg; path = {name}; sourceTree = "<group>"; }};\n'


objects = []

# File refs
for p in swift_app + swift_tests:
    objects.append(file_ref(p))
for p in resources:
    objects.append(resource_ref(p))

objects.append(
    f'\t\t{ids["app_product"]} /* SunsetLog.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SunsetLog.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n'
)
objects.append(
    f'\t\t{ids["test_product"]} /* SunsetLogTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = SunsetLogTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};\n'
)
objects.append(
    f'\t\t{ids["assets_file"]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};\n'
)
objects.append(
    f'\t\t{ids["plist_file"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};\n'
)
objects.append(
    f'\t\t{ids["privacy_file"]} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = "<group>"; }};\n'
)

# Build files
for p in swift_app:
    objects.append(
        f'\t\t{build_ids[p]} /* {p.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[p]} /* {p.name} */; }};\n'
    )
for p in swift_tests:
    objects.append(
        f'\t\t{build_ids[p]} /* {p.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[p]} /* {p.name} */; }};\n'
    )
for p in resources:
    objects.append(
        f'\t\t{build_ids[p]} /* {p.name} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ids[p]} /* {p.name} */; }};\n'
    )
objects.append(
    f'\t\t{hid("assets_build")} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ids["assets_file"]} /* Assets.xcassets */; }};\n'
)
objects.append(
    f'\t\t{hid("privacy_build")} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {ids["privacy_file"]} /* PrivacyInfo.xcprivacy */; }};\n'
)

# Groups — build from leaves
# Map directory -> children file refs
from collections import defaultdict

dir_files: dict[Path, list[str]] = defaultdict(list)
for p in swift_app:
    dir_files[p.parent].append(f'{file_ids[p]} /* {p.name} */')

# Add assets/plist/privacy to APP root
dir_files[APP].append(f'{ids["assets_file"]} /* Assets.xcassets */')
dir_files[APP].append(f'{ids["plist_file"]} /* Info.plist */')
dir_files[APP].append(f'{ids["privacy_file"]} /* PrivacyInfo.xcprivacy */')

# Subgroup IDs — include every ancestor so nested Views/ folders stay in the tree
dir_ids = {APP: ids["app_group"]}
folders = {p.parent for p in swift_app} | {APP / "Resources", APP / "Resources" / "SeedPhotos"}
expanded: set[Path] = set()
for folder in folders:
    current = folder
    while current != APP and APP in current.parents or current == APP:
        expanded.add(current)
        if current == APP:
            break
        current = current.parent
for folder in sorted(expanded):
    if folder == APP:
        continue
    dir_ids[folder] = hid(f"group:{folder.relative_to(APP)}")

# Resources
dir_files[APP / "Resources" / "SeedPhotos"] = [f'{file_ids[p]} /* {p.name} */' for p in resources]
dir_files[APP / "Resources"] = []

# Children groups
dir_children: dict[Path, list[Path]] = defaultdict(list)
for folder in dir_ids:
    if folder == APP:
        continue
    parent = folder.parent
    if parent in dir_ids or parent == APP:
        dir_children[parent].append(folder)

# Ensure Resources attached to app
if APP / "Resources" not in dir_children[APP]:
    dir_children[APP].append(APP / "Resources")

for folder, gid in sorted(dir_ids.items(), key=lambda kv: str(kv[0])):
    name = "SunsetLog" if folder == APP else folder.name
    kids = []
    for child in sorted(dir_children.get(folder, []), key=lambda p: p.name.lower()):
        kids.append(f'{dir_ids[child]} /* {child.name} */')
    for ref in sorted(dir_files.get(folder, [])):
        kids.append(ref)
    children = "".join(f"\n\t\t\t\t{k}," for k in kids)
    path_line = f"\n\t\t\tpath = {folder.name};"
    objects.append(
        f"""\t\t{gid} /* {name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ({children}
\t\t\t);{path_line}
\t\t\tsourceTree = "<group>";
\t\t}};
"""
    )

# Test group
test_children = "".join(f'\n\t\t\t\t{file_ids[p]} /* {p.name} */,' for p in swift_tests)
objects.append(
    f"""\t\t{ids["test_group"]} /* SunsetLogTests */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ({test_children}
\t\t\t);
\t\t\tpath = SunsetLogTests;
\t\t\tsourceTree = "<group>";
\t\t}};
"""
)

objects.append(
    f"""\t\t{ids["products_group"]} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ids["app_product"]} /* SunsetLog.app */,
\t\t\t\t{ids["test_product"]} /* SunsetLogTests.xctest */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
"""
)

objects.append(
    f"""\t\t{ids["main_group"]} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ids["app_group"]} /* SunsetLog */,
\t\t\t\t{ids["test_group"]} /* SunsetLogTests */,
\t\t\t\t{ids["products_group"]} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
"""
)

# Sources / resources phases
src_list = "".join(f'\n\t\t\t\t{build_ids[p]} /* {p.name} in Sources */,' for p in swift_app)
objects.append(
    f"""\t\t{ids["sources_phase"]} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = ({src_list}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
)

res_list = "".join(f'\n\t\t\t\t{build_ids[p]} /* {p.name} in Resources */,' for p in resources)
res_list += f'\n\t\t\t\t{hid("assets_build")} /* Assets.xcassets in Resources */,'
res_list += f'\n\t\t\t\t{hid("privacy_build")} /* PrivacyInfo.xcprivacy in Resources */,'
objects.append(
    f"""\t\t{ids["resources_phase"]} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = ({res_list}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
)

objects.append(
    f"""\t\t{ids["frameworks_phase"]} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
)

test_src = "".join(f'\n\t\t\t\t{build_ids[p]} /* {p.name} in Sources */,' for p in swift_tests)
objects.append(
    f"""\t\t{ids["test_sources_phase"]} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = ({test_src}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
)
objects.append(
    f"""\t\t{ids["test_frameworks_phase"]} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
)

# Targets
objects.append(
    f"""\t\t{ids["app_target"]} /* SunsetLog */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ids["app_config_list"]} /* Build configuration list for PBXNativeTarget "SunsetLog" */;
\t\t\tbuildPhases = (
\t\t\t\t{ids["sources_phase"]} /* Sources */,
\t\t\t\t{ids["frameworks_phase"]} /* Frameworks */,
\t\t\t\t{ids["resources_phase"]} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = SunsetLog;
\t\t\tproductName = SunsetLog;
\t\t\tproductReference = {ids["app_product"]} /* SunsetLog.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
"""
)

objects.append(
    f"""\t\t{ids["test_target"]} /* SunsetLogTests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ids["test_config_list"]} /* Build configuration list for PBXNativeTarget "SunsetLogTests" */;
\t\t\tbuildPhases = (
\t\t\t\t{ids["test_sources_phase"]} /* Sources */,
\t\t\t\t{ids["test_frameworks_phase"]} /* Frameworks */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{hid("test_dep")} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = SunsetLogTests;
\t\t\tproductName = SunsetLogTests;
\t\t\tproductReference = {ids["test_product"]} /* SunsetLogTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t}};
"""
)

objects.append(
    f"""\t\t{hid("test_proxy")} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {ids["project"]} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {ids["app_target"]};
\t\t\tremoteInfo = SunsetLog;
\t\t}};
"""
)
objects.append(
    f"""\t\t{hid("test_dep")} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {ids["app_target"]} /* SunsetLog */;
\t\t\ttargetProxy = {hid("test_proxy")} /* PBXContainerItemProxy */;
\t\t}};
"""
)

objects.append(
    f"""\t\t{ids["project"]} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1540;
\t\t\t\tLastUpgradeCheck = 1540;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{ids["app_target"]} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;
\t\t\t\t\t}};
\t\t\t\t\t{ids["test_target"]} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;
\t\t\t\t\t\tTestTargetID = {ids["app_target"]};
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {ids["project_config_list"]} /* Build configuration list for PBXProject "SunsetLog" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {ids["main_group"]};
\t\t\tproductRefGroup = {ids["products_group"]} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{ids["app_target"]} /* SunsetLog */,
\t\t\t\t{ids["test_target"]} /* SunsetLogTests */,
\t\t\t);
\t\t}};
"""
)

common_proj = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
"""

proj_release = common_proj.replace("ENABLE_TESTABILITY = YES;", "ENABLE_NS_ASSERTIONS = NO;").replace(
    'DEBUG_INFORMATION_FORMAT = dwarf;', 'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
).replace(
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";', "SWIFT_COMPILATION_MODE = wholemodule;"
).replace(
    'SWIFT_OPTIMIZATION_LEVEL = "-Onone";', 'SWIFT_OPTIMIZATION_LEVEL = "-O";'
).replace(
    "MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;", "MTL_ENABLE_DEBUG_INFO = NO;"
)

objects.append(
    f"""\t\t{ids["proj_debug"]} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{common_proj}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
"""
)
objects.append(
    f"""\t\t{ids["proj_release"]} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{proj_release}
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
"""
)

app_settings = """
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = SunsetLog/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = "Sunset Log";
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.lifestyle";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.sunsetlog.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_STRICT_CONCURRENCY = targeted;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
"""

objects.append(
    f"""\t\t{ids["app_debug"]} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{app_settings}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
"""
)
objects.append(
    f"""\t\t{ids["app_release"]} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{app_settings}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
"""
)

test_settings = """
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.sunsetlog.app.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/SunsetLog.app/SunsetLog";
"""

objects.append(
    f"""\t\t{ids["test_debug"]} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{test_settings}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
"""
)
objects.append(
    f"""\t\t{ids["test_release"]} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{{test_settings}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
"""
)

def config_list(cid: str, debug: str, release: str, title: str) -> str:
    return f"""\t\t{cid} /* {title} */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug} /* Debug */,
\t\t\t\t{release} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""

objects.append(config_list(ids["project_config_list"], ids["proj_debug"], ids["proj_release"], 'Build configuration list for PBXProject "SunsetLog"'))
objects.append(config_list(ids["app_config_list"], ids["app_debug"], ids["app_release"], 'Build configuration list for PBXNativeTarget "SunsetLog"'))
objects.append(config_list(ids["test_config_list"], ids["test_debug"], ids["test_release"], 'Build configuration list for PBXNativeTarget "SunsetLogTests"'))

body = "".join(objects)
pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{
{body}	}};
	rootObject = {ids["project"]} /* Project object */;
}}
"""

PROJ.mkdir(parents=True, exist_ok=True)
(PROJ / "project.pbxproj").write_text(pbx)
scheme_dir = PROJ / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / "SunsetLog.xcscheme").write_text(
    f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1540"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids["app_target"]}"
               BuildableName = "SunsetLog.app"
               BlueprintName = "SunsetLog"
               ReferencedContainer = "container:SunsetLog.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids["test_target"]}"
               BuildableName = "SunsetLogTests.xctest"
               BlueprintName = "SunsetLogTests"
               ReferencedContainer = "container:SunsetLog.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{ids["app_target"]}"
            BuildableName = "SunsetLog.app"
            BlueprintName = "SunsetLog"
            ReferencedContainer = "container:SunsetLog.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{ids["app_target"]}"
            BuildableName = "SunsetLog.app"
            BlueprintName = "SunsetLog"
            ReferencedContainer = "container:SunsetLog.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
)

print(f"Wrote project with {len(swift_app)} app sources, {len(swift_tests)} tests, {len(resources)} photos")
