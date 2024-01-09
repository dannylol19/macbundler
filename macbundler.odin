package main
import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/slashpath"
import "core:c/libc"

Args :: struct {
	app_or_bundle: string,
	bundle_or_app_name: string,
	output_dir: string,
	binary_path: string,
	bundle_identifier: string,
	icon_dir: Maybe(string),
	assets_dir: Maybe(string),
	frameworks_dir: Maybe(string),
}

fix_spaces :: #force_inline proc(path: string) -> string {
	return strings.concatenate({"\"", path, "\""})
}

main :: proc() {
	if len(os.args) < 3 || (os.args[1] != "app" && os.args[1] != "bundle") {
		fmt.println("Usage: macbundler <app-or-bundle> [options]")
		os.exit(0)
	}

	args: Args
	parse_args(&args)

	if args.bundle_or_app_name == "" || args.binary_path == "" || args.bundle_identifier == "" {
		fmt.eprintln("Error: bundle/application name, binary path, and bundle identifier are required.")
		os.exit(1)
	}

	if args.output_dir != "" && !os.exists(args.output_dir) {
		fmt.eprintf("Error: output directory '{}' does not exist.\n", args.output_dir)
		os.exit(1)
	}

	// create base .app or .bundle folder
	extension := strings.concatenate({".", args.app_or_bundle})
	base_path := slashpath.join({args.output_dir, strings.concatenate({args.bundle_or_app_name, extension})})
	os.make_directory(base_path)

	// create default directories
	contents_path := slashpath.join({base_path, "Contents"})
	os.make_directory(contents_path)

	resources_path := slashpath.join({contents_path, "Resources"})
	os.make_directory(resources_path)

	macos_path := slashpath.join({contents_path, "MacOS"})
	os.make_directory(macos_path)

	// create Info.plist
	info_plist, _ := strings.replace(info_plist_template, "{{.BundleName}}", args.bundle_or_app_name, 1)
	info_plist, _ = strings.replace(info_plist, "{{.AppName}}", slashpath.name(args.binary_path), 1)
	info_plist, _ = strings.replace(info_plist, "{{.BundleIdentifier}}", args.bundle_identifier, 1)
	os.write_entire_file(slashpath.join({contents_path, "Info.plist"}), transmute([]u8)info_plist)

	// copy the icon
	if args.icon_dir != nil {
		icon_path := slashpath.join({resources_path, "icon.icns"})
		libc.system(strings.clone_to_cstring(strings.concatenate({"cp ", fix_spaces(args.icon_dir.?), " ", fix_spaces(icon_path)})))
	}

	// copy the assets
	if args.assets_dir != nil {
		libc.system(strings.clone_to_cstring(strings.concatenate({"cp -r ", slashpath.join({fix_spaces(args.assets_dir.?), "*"}), " ", fix_spaces(resources_path)})))
	}

	// copy the frameworks
	if args.frameworks_dir != nil {
		libc.system(strings.clone_to_cstring(strings.concatenate({"cp -r ", fix_spaces(args.frameworks_dir.?), " ", fix_spaces(slashpath.join({contents_path, "Frameworks"}))})))
	}

	// copy the binary
	libc.system(strings.clone_to_cstring(strings.concatenate({"cp ", fix_spaces(args.binary_path), " ", fix_spaces(macos_path)})))

	fmt.println("All done! Output:", base_path)
}

get_next_arg :: proc(idx: int, arg: string) -> string {
	if idx + 1 >= len(os.args) {
		fmt.eprintln("Missing value for argument:", arg)
		os.exit(1)
	}

	return os.args[idx + 1]
}

parse_args :: proc(args: ^Args) {
	args.app_or_bundle = os.args[1]
	reading_value := false

	for arg, idx in os.args[2:] {
		if !reading_value {
			if arg == "-name" {
				args.bundle_or_app_name = get_next_arg(idx+2, arg)
			}
			else if arg == "-binary" {
				args.binary_path = get_next_arg(idx+2, arg)
			}
			else if arg == "-o" {
				args.output_dir = get_next_arg(idx+2, arg)
			}
			else if arg == "-bundle-identifier" {
				args.bundle_identifier = get_next_arg(idx+2, arg)
			}
			else if arg == "-assets" {
				args.assets_dir = get_next_arg(idx+2, arg)
			}
			else if arg == "-icon" {
				args.icon_dir = get_next_arg(idx+2, arg)
			}
			else if arg == "-frameworks" {
				args.frameworks_dir = get_next_arg(idx+2, arg)
			}
			else {
				fmt.eprintln("Unknown argument:", arg)
				os.exit(1)
			}

			reading_value = true
			continue
		}

		reading_value = false
	}
}

info_plist_template :: `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>{{.BundleName}}</string>
	<key>CFBundleExecutable</key>
	<string>{{.AppName}}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleIconFile</key>
	<string>icon.icns</string>
	<key>CFBundleIdentifier</key>
	<string>{{.BundleIdentifier}}</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
`