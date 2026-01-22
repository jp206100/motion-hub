#!/usr/bin/env python3
"""
generate-xcode-project.py
Generates a working Xcode project for Motion Hub
"""

import os
import uuid
import json
from pathlib import Path

def generate_uuid():
    """Generate a 24-character hex ID for Xcode"""
    return uuid.uuid4().hex[:24].upper()

class XcodeProjectGenerator:
    def __init__(self, project_path):
        self.project_path = Path(project_path)
        self.project_name = "MotionHub"

        # Generate UUIDs for all objects
        self.uuids = {
            'project': generate_uuid(),
            'main_group': generate_uuid(),
            'products_group': generate_uuid(),
            'app_target': generate_uuid(),
            'app_product': generate_uuid(),
            'sources_phase': generate_uuid(),
            'frameworks_phase': generate_uuid(),
            'resources_phase': generate_uuid(),
            'headers_phase': generate_uuid(),
            'debug_config': generate_uuid(),
            'release_config': generate_uuid(),
            'config_list_project': generate_uuid(),
            'config_list_target': generate_uuid(),
        }

        self.file_refs = {}
        self.groups = {}
        self.build_files = {}

    def scan_source_files(self):
        """Scan the MotionHub directory and create file references"""
        motion_hub_dir = self.project_path / "MotionHub" / "MotionHub"

        file_groups = {
            'App': [],
            'Models': [],
            'Views': [],
            'Views/Components': [],
            'Views/Modals': [],
            'Services': [],
            'Rendering': [],
            'Rendering/Shaders': [],
            'Resources': [],
        }

        for group_path in file_groups.keys():
            full_path = motion_hub_dir / group_path
            if full_path.exists():
                for file in full_path.iterdir():
                    if file.is_file() and not file.name.startswith('.'):
                        rel_path = file.relative_to(self.project_path)
                        file_groups[group_path].append({
                            'name': file.name,
                            'path': str(rel_path),
                            'type': self.get_file_type(file.suffix)
                        })

        return file_groups

    def get_file_type(self, extension):
        """Get Xcode file type for extension"""
        types = {
            '.swift': 'sourcecode.swift',
            '.metal': 'sourcecode.metal',
            '.h': 'sourcecode.c.h',
            '.plist': 'text.plist.xml',
            '.md': 'net.daringfireball.markdown',
        }
        return types.get(extension, 'text')

    def generate_file_reference(self, file_info):
        """Generate a file reference entry"""
        file_uuid = generate_uuid()
        self.file_refs[file_info['name']] = file_uuid

        return f"""\t\t{file_uuid} /* {file_info['name']} */ = {{isa = PBXFileReference; lastKnownFileType = {file_info['type']}; path = {file_info['name']}; sourceTree = "<group>"; }};"""

    def generate_group(self, name, children, path=None):
        """Generate a group entry"""
        group_uuid = generate_uuid()
        self.groups[name] = group_uuid

        children_refs = ' '.join([self.file_refs.get(c['name'], generate_uuid()) for c in children])
        path_attr = f'path = {path}; ' if path else ''

        return f"""\t\t{group_uuid} /* {name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join([f"\t\t\t\t{self.file_refs[c['name']]} /* {c['name']} */," for c in children])}
\t\t\t);
\t\t\t{path_attr}sourceTree = "<group>";
\t\t}};"""

    def generate_build_file(self, file_name):
        """Generate a build file entry"""
        build_uuid = generate_uuid()
        file_uuid = self.file_refs.get(file_name)
        if file_uuid:
            self.build_files[file_name] = build_uuid
            return f"""\t\t{build_uuid} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {file_name} */; }};"""
        return ""

    def generate(self):
        """Generate the complete project.pbxproj file"""
        file_groups = self.scan_source_files()

        # Generate all file references
        file_ref_entries = []
        all_files = []
        for group_files in file_groups.values():
            for file_info in group_files:
                file_ref_entries.append(self.generate_file_reference(file_info))
                all_files.append(file_info)

        # Generate build files for source files
        build_file_entries = []
        for file_info in all_files:
            if file_info['type'] in ['sourcecode.swift', 'sourcecode.metal']:
                entry = self.generate_build_file(file_info['name'])
                if entry:
                    build_file_entries.append(entry)

        # Product reference
        product_uuid = self.uuids['app_product']
        product_ref = f"""\t\t{product_uuid} /* MotionHub.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MotionHub.app; sourceTree = BUILT_PRODUCTS_DIR; }};"""

        # Build the project file
        project_content = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_file_entries)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{product_ref}
{chr(10).join(file_ref_entries)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{self.uuids['frameworks_phase']} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{self.uuids['main_group']} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{self.groups.get('MotionHub', generate_uuid())} /* MotionHub */,
\t\t\t\t{self.uuids['products_group']} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{self.uuids['products_group']} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{product_uuid} /* MotionHub.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{self.uuids['app_target']} /* MotionHub */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {self.uuids['config_list_target']} /* Build configuration list for PBXNativeTarget "MotionHub" */;
\t\t\tbuildPhases = (
\t\t\t\t{self.uuids['sources_phase']} /* Sources */,
\t\t\t\t{self.uuids['frameworks_phase']} /* Frameworks */,
\t\t\t\t{self.uuids['resources_phase']} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = MotionHub;
\t\t\tproductName = MotionHub;
\t\t\tproductReference = {product_uuid} /* MotionHub.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{self.uuids['project']} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{self.uuids['app_target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {self.uuids['config_list_project']} /* Build configuration list for PBXProject "MotionHub" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {self.uuids['main_group']};
\t\t\tproductRefGroup = {self.uuids['products_group']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{self.uuids['app_target']} /* MotionHub */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{self.uuids['resources_phase']} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{self.uuids['sources_phase']} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join([f"\t\t\t\t{self.build_files.get(f['name'], generate_uuid())} /* {f['name']} in Sources */," for f in all_files if f['type'] in ['sourcecode.swift', 'sourcecode.metal']])}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{self.uuids['debug_config']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{self.uuids['release_config']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{generate_uuid()} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MotionHub/MotionHub.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_HARDENED_RUNTIME = YES;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = MotionHub/MotionHub/Info.plist;
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "Copyright © 2026 Motion Hub. All rights reserved.";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.motionhub.MotionHub;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{generate_uuid()} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MotionHub/MotionHub.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_HARDENED_RUNTIME = YES;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = MotionHub/MotionHub/Info.plist;
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "Copyright © 2026 Motion Hub. All rights reserved.";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.motionhub.MotionHub;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{self.uuids['config_list_project']} /* Build configuration list for PBXProject "MotionHub" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{self.uuids['debug_config']} /* Debug */,
\t\t\t\t{self.uuids['release_config']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{self.uuids['config_list_target']} /* Build configuration list for PBXNativeTarget "MotionHub" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{generate_uuid()} /* Debug */,
\t\t\t\t{generate_uuid()} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {self.uuids['project']} /* Project object */;
}}
"""

        return project_content

    def write_project(self):
        """Write the project file to disk"""
        # Create .xcodeproj directory
        xcodeproj_dir = self.project_path / f"{self.project_name}.xcodeproj"
        xcodeproj_dir.mkdir(exist_ok=True)

        # Write project.pbxproj
        pbxproj_path = xcodeproj_dir / "project.pbxproj"
        content = self.generate()
        pbxproj_path.write_text(content)

        print(f"✅ Created {xcodeproj_dir}")
        print(f"✅ Generated {pbxproj_path}")

        # Create xcscheme (optional but helpful)
        self.create_scheme(xcodeproj_dir)

    def create_scheme(self, xcodeproj_dir):
        """Create a default scheme"""
        schemes_dir = xcodeproj_dir / "xcshareddata" / "xcschemes"
        schemes_dir.mkdir(parents=True, exist_ok=True)

        scheme_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
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
               BlueprintIdentifier = "{self.uuids['app_target']}"
               BuildableName = "MotionHub.app"
               BlueprintName = "MotionHub"
               ReferencedContainer = "container:MotionHub.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
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
            BlueprintIdentifier = "{self.uuids['app_target']}"
            BuildableName = "MotionHub.app"
            BlueprintName = "MotionHub"
            ReferencedContainer = "container:MotionHub.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
</Scheme>
"""

        scheme_path = schemes_dir / "MotionHub.xcscheme"
        scheme_path.write_text(scheme_content)
        print(f"✅ Created scheme {scheme_path}")


if __name__ == "__main__":
    project_dir = Path(__file__).parent
    generator = XcodeProjectGenerator(project_dir)
    generator.write_project()

    print("\n" + "="*60)
    print("Xcode project created successfully!")
    print("="*60)
    print("\nNext steps:")
    print("1. Open MotionHub.xcodeproj in Xcode")
    print("2. Review and organize source files in the project navigator")
    print("3. Add any missing files to the project")
    print("4. Build and run with ⌘R")
    print("\nNote: You may need to:")
    print("- Create an entitlements file (MotionHub.entitlements)")
    print("- Add Resources/Assets.xcassets")
    print("- Configure code signing")
