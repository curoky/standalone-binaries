package main

import (
	"bytes"
	"debug/buildinfo"
	"debug/elf"
	"debug/macho"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"regexp"
	"strings"
)

const (
	loadDylib       = uint32(0xc)
	idDylib         = uint32(0xd)
	loadWeakDylib   = uint32(0x80000018)
	loadRpath       = uint32(0x8000001c)
	reexportDylib   = uint32(0x8000001f)
	lazyLoadDylib   = uint32(0x20)
	loadUpwardDylib = uint32(0x80000023)
	codeSignature   = uint32(0x1d)
)

var nixDarwinResolv = regexp.MustCompile(`^/nix/store/[0-9abcdfghijklmnpqrsvwxyz]{32}-libresolv-[0-9]+(\.[0-9]+)*/lib/libresolv\.9\.dylib$`)

type elfInfo struct {
	interpreter string
	libraries   []string
	rpaths      []string
	isDynamic   bool
}

type machOInfo struct {
	dependencies []string
	rpaths       []string
	hasNixLoad   bool
	hasSignature bool
}

func isELFMagic(magic [8]byte) bool {
	return magic[0] == 0x7f && magic[1] == 'E' && magic[2] == 'L' && magic[3] == 'F'
}

func isMachOMagic(magic [8]byte) bool {
	const magicFat64 = uint32(0xcafebabf)
	valueBE := binary.BigEndian.Uint32(magic[:4])
	valueLE := binary.LittleEndian.Uint32(magic[:4])
	// The big-endian 0xcafebabe magic is shared with Java .class files. A
	// Mach-O fat header stores a small architecture count at offset 4, while a
	// class file stores its version there (major version >= 45), so a large
	// value at that offset means the file is a Java class, not a Mach-O binary.
	if valueBE == macho.MagicFat && binary.BigEndian.Uint32(magic[4:8]) >= maxFatArchCount {
		return false
	}
	return valueBE == macho.MagicFat ||
		valueLE == macho.MagicFat ||
		valueBE == magicFat64 ||
		valueLE == magicFat64 ||
		valueBE == macho.Magic32 ||
		valueBE == macho.Magic64 ||
		valueLE == macho.Magic32 ||
		valueLE == macho.Magic64
}

// maxFatArchCount bounds the plausible number of architectures in a Mach-O fat
// binary. Any value at or above this at offset 4 of a 0xcafebabe file is a Java
// class file version (major version >= 45), not a fat-arch count.
const maxFatArchCount = uint32(45)

func validateELF(path, artifactName string, allowDynamic bool) error {
	info, err := inspectELF(path)
	if err != nil {
		return fmt.Errorf("inspect ELF %s: %w", path, err)
	}
	if info.isDynamic && !allowDynamic {
		return fmt.Errorf("%s is dynamically linked; Linux artifact %s must contain only statically linked ELF files", path, artifactName)
	}
	for _, value := range append(append([]string(nil), info.libraries...), info.rpaths...) {
		if strings.Contains(value, "/nix") {
			return fmt.Errorf("%s has a dynamic path under /nix: %s", path, value)
		}
	}
	if strings.Contains(info.interpreter, "/nix") {
		return fmt.Errorf("%s has an interpreter under /nix: %s", path, info.interpreter)
	}
	return nil
}

func inspectELF(path string) (elfInfo, error) {
	file, err := elf.Open(path)
	if err != nil {
		return elfInfo{}, err
	}
	defer file.Close()

	info := elfInfo{}
	for _, program := range file.Progs {
		switch program.Type {
		case elf.PT_INTERP:
			data, err := io.ReadAll(program.Open())
			if err != nil {
				return elfInfo{}, err
			}
			info.interpreter = strings.TrimRight(string(data), "\x00")
		}
	}
	info.libraries, err = file.ImportedLibraries()
	if err != nil {
		return elfInfo{}, err
	}
	flags, err := file.DynValue(elf.DT_FLAGS_1)
	if err != nil {
		return elfInfo{}, err
	}
	info.isDynamic = isDynamicallyLinkedELF(file.Type, info.interpreter, info.libraries, flags)
	for _, tag := range []elf.DynTag{elf.DT_RPATH, elf.DT_RUNPATH} {
		values, err := file.DynString(tag)
		if err != nil {
			return elfInfo{}, err
		}
		info.rpaths = append(info.rpaths, values...)
	}
	return info, nil
}

func isDynamicallyLinkedELF(fileType elf.Type, interpreter string, libraries []string, flags []uint64) bool {
	if interpreter != "" || len(libraries) > 0 {
		return true
	}
	if fileType != elf.ET_DYN {
		return false
	}
	for _, value := range flags {
		if elf.DynFlag1(value)&elf.DF_1_PIE != 0 {
			return false
		}
	}
	return true
}

func normalizeMachO(path string) (machOInfo, error) {
	info, err := inspectMachO(path)
	if err != nil {
		return machOInfo{}, fmt.Errorf("inspect Mach-O %s: %w", path, err)
	}
	var arguments []string
	for _, dependency := range darwinCGOResolvDependencies(path, info) {
		arguments = append(arguments, "-change", dependency, "/usr/lib/libresolv.9.dylib")
	}
	seen := make(map[string]bool)
	for _, rpath := range info.rpaths {
		if !strings.HasPrefix(rpath, "/nix/") || seen[rpath] {
			continue
		}
		seen[rpath] = true
		arguments = append(arguments, "-delete_rpath", rpath)
	}
	if len(arguments) == 0 {
		return info, nil
	}
	command := exec.Command("install_name_tool", append(arguments, path)...)
	if output, err := command.CombinedOutput(); err != nil {
		return machOInfo{}, fmt.Errorf("normalize Mach-O %s: %w: %s", path, err, bytes.TrimSpace(output))
	}

	// Load-command edits invalidate code signatures. Use Apple's codesign:
	// nixpkgs sigtool 0.1.3 cannot preserve metadata, notably Lima's
	// virtualization entitlement. Do not re-sign an unchanged file.
	arguments = []string{"--force", "--sign", "-", "--timestamp=none"}
	if info.hasSignature {
		arguments = append(arguments, "--preserve-metadata=identifier,entitlements,flags,runtime")
	}
	command = exec.Command("/usr/bin/codesign", append(arguments, path)...)
	if output, err := command.CombinedOutput(); err != nil {
		return machOInfo{}, fmt.Errorf("sign normalized Mach-O %s: %w: %s", path, err, bytes.TrimSpace(output))
	}
	info, err = inspectMachO(path)
	if err != nil {
		return machOInfo{}, fmt.Errorf("reinspect Mach-O %s: %w", path, err)
	}
	return info, nil
}

// Temporary workaround tracked as artifact-darwin-cgo-resolv in
// docs/regression/darwin.md. Reassess without this rewrite after nixpkgs
// updates; a successful patched artifact/probe is not removal evidence.
func darwinCGOResolvDependencies(path string, info machOInfo) []string {
	var dependencies []string
	seen := make(map[string]bool)
	for _, dependency := range info.dependencies {
		if nixDarwinResolv.MatchString(dependency) && !seen[dependency] {
			dependencies = append(dependencies, dependency)
			seen[dependency] = true
		}
	}
	if len(dependencies) == 0 {
		return nil
	}

	// normalizeFile calls us only for Darwin Mach-O files. Narrow this
	// workaround further to thin arm64 executables (the supported Darwin
	// target); ReadFile alone would inspect only the first slice of a fat file.
	file, err := macho.Open(path)
	if err != nil {
		return nil
	}
	defer file.Close()
	if file.Magic != macho.Magic64 || file.Cpu != macho.CpuArm64 || file.Type != macho.TypeExec {
		return nil
	}
	build, err := buildinfo.ReadFile(path)
	if err != nil {
		return nil
	}
	settings := make(map[string]string)
	for _, setting := range build.Settings {
		settings[setting.Key] = setting.Value
	}
	// Only Go's Darwin CGO build is known to use this Nix-packaged Apple
	// resolver with the system libresolv.9 ABI. Missing metadata, pure Go,
	// other dylibs/ABIs and non-Go programs are NOT candidates. Their Nix
	// dependencies remain untouched and must still pass validateMachO.
	if settings["GOOS"] != "darwin" || settings["GOARCH"] != "arm64" ||
		settings["CGO_ENABLED"] != "1" || settings["-compiler"] != "gc" ||
		(settings["-buildmode"] != "exe" && settings["-buildmode"] != "pie") {
		return nil
	}
	return dependencies
}

func validateMachO(path string, info machOInfo) error {
	for _, dependency := range info.dependencies {
		if !isPortableMachODependency(dependency) {
			return fmt.Errorf("%s has a non-portable dynamic dependency: %s", path, dependency)
		}
	}
	if info.hasNixLoad {
		return fmt.Errorf("%s has a Mach-O load command under /nix", path)
	}
	for _, rpath := range info.rpaths {
		if rpath != "@loader_path" && !strings.HasPrefix(rpath, "@loader_path/") {
			return fmt.Errorf("%s has a non-portable LC_RPATH: %s", path, rpath)
		}
	}
	return nil
}

func isPortableMachODependency(path string) bool {
	return strings.HasPrefix(path, "/usr/lib/") ||
		strings.HasPrefix(path, "/System/Library/Frameworks/") ||
		strings.HasPrefix(path, "@loader_path/") ||
		strings.HasPrefix(path, "@rpath/")
}

func inspectMachO(path string) (machOInfo, error) {
	fatFile, err := macho.OpenFat(path)
	if err == nil {
		defer fatFile.Close()
		var result machOInfo
		for _, architecture := range fatFile.Arches {
			result.merge(inspectMachOFile(architecture.File))
		}
		return result, nil
	}
	if !errors.Is(err, macho.ErrNotFat) {
		return machOInfo{}, err
	}

	file, err := macho.Open(path)
	if err != nil {
		return machOInfo{}, err
	}
	defer file.Close()
	return inspectMachOFile(file), nil
}

func inspectMachOFile(file *macho.File) machOInfo {
	var info machOInfo
	for _, load := range file.Loads {
		raw := load.Raw()
		if bytes.Contains(raw, []byte("/nix")) {
			info.hasNixLoad = true
		}
		if len(raw) < 12 {
			continue
		}
		command := file.ByteOrder.Uint32(raw[:4])
		offset := file.ByteOrder.Uint32(raw[8:12])
		name := loadCommandString(raw, offset)
		switch command {
		case loadDylib, loadWeakDylib, reexportDylib, lazyLoadDylib, loadUpwardDylib:
			if name != "" {
				info.dependencies = append(info.dependencies, name)
			}
		case idDylib:
		case codeSignature:
			info.hasSignature = true
		case loadRpath:
			if name != "" {
				info.rpaths = append(info.rpaths, name)
			}
		}
	}
	return info
}

func loadCommandString(raw []byte, offset uint32) string {
	if offset >= uint32(len(raw)) {
		return ""
	}
	value := raw[offset:]
	if index := bytes.IndexByte(value, 0); index >= 0 {
		value = value[:index]
	}
	return string(value)
}

func (info *machOInfo) merge(other machOInfo) {
	info.dependencies = append(info.dependencies, other.dependencies...)
	info.rpaths = append(info.rpaths, other.rpaths...)
	info.hasNixLoad = info.hasNixLoad || other.hasNixLoad
	info.hasSignature = info.hasSignature || other.hasSignature
}
