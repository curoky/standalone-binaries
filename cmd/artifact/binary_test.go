package main

import (
	"bytes"
	"debug/macho"
	"encoding/binary"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"testing"
)

const testNixResolv = "/nix/store/0123456789abcdfghijklmnpqrsvwxyz-libresolv-96/lib/libresolv.9.dylib"

const testDarwinCGOSettings = "build\tGOOS=darwin\nbuild\tGOARCH=arm64\nbuild\tCGO_ENABLED=1\nbuild\t-compiler=gc\nbuild\t-buildmode=exe\n"

func TestDarwinCGOResolvDependencies(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name       string
		settings   string
		dependency string
		cpu        macho.Cpu
		fileType   macho.Type
		want       bool
	}{
		{name: "darwin cgo resolver", want: true},
		{name: "pie", settings: strings.ReplaceAll(testDarwinCGOSettings, "=exe", "=pie"), want: true},
		{name: "system resolver", dependency: "/usr/lib/libresolv.9.dylib"},
		{name: "other library", dependency: strings.ReplaceAll(testNixResolv, "libresolv", "libiconv")},
		{name: "other ABI", dependency: strings.ReplaceAll(testNixResolv, ".9.dylib", ".8.dylib")},
		{name: "other package", dependency: strings.ReplaceAll(testNixResolv, "-libresolv-96/", "-helper-96/")},
		{name: "malformed hash", dependency: strings.ReplaceAll(testNixResolv, "012345", "oooooo")},
		{name: "path suffix", dependency: testNixResolv + ".backup"},
		{name: "path traversal", dependency: strings.ReplaceAll(testNixResolv, "/lib/", "/lib/../lib/")},
		{name: "pure go", settings: strings.ReplaceAll(testDarwinCGOSettings, "CGO_ENABLED=1", "CGO_ENABLED=0")},
		{name: "missing cgo", settings: strings.ReplaceAll(testDarwinCGOSettings, "build\tCGO_ENABLED=1\n", "")},
		{name: "missing metadata", settings: "\n"},
		{name: "linux metadata", settings: strings.ReplaceAll(testDarwinCGOSettings, "GOOS=darwin", "GOOS=linux")},
		{name: "ios metadata", settings: strings.ReplaceAll(testDarwinCGOSettings, "GOOS=darwin", "GOOS=ios")},
		{name: "other compiler", settings: strings.ReplaceAll(testDarwinCGOSettings, "-compiler=gc", "-compiler=gccgo")},
		{name: "plugin", settings: strings.ReplaceAll(testDarwinCGOSettings, "-buildmode=exe", "-buildmode=plugin")},
		{name: "other arch metadata", settings: strings.ReplaceAll(testDarwinCGOSettings, "GOARCH=arm64", "GOARCH=amd64")},
		{name: "other cpu", cpu: macho.CpuAmd64},
		{name: "dylib", fileType: macho.TypeDylib},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			settings, dependency, cpu, fileType := test.settings, test.dependency, test.cpu, test.fileType
			if settings == "" {
				settings = testDarwinCGOSettings
			}
			if dependency == "" {
				dependency = testNixResolv
			}
			if cpu == 0 {
				cpu = macho.CpuArm64
			}
			if fileType == 0 {
				fileType = macho.TypeExec
			}
			path := writeGoMachOFixture(t, settings, cpu, fileType)
			before := fileHash(t, path)
			info := machOInfo{dependencies: []string{dependency, dependency}}
			got := darwinCGOResolvDependencies(path, info)
			var want []string
			if test.want {
				want = []string{dependency}
			}
			if !reflect.DeepEqual(got, want) {
				t.Fatalf("dependencies=%q want=%q", got, want)
			}
			if before != fileHash(t, path) {
				t.Fatal("candidate inspection changed the file")
			}
		})
	}
	t.Run("unreadable file", func(t *testing.T) {
		if got := darwinCGOResolvDependencies(filepath.Join(t.TempDir(), "missing"), machOInfo{dependencies: []string{testNixResolv}}); len(got) != 0 {
			t.Fatalf("dependencies=%q", got)
		}
	})
	t.Run("non go", func(t *testing.T) {
		path := writeGoMachOFixture(t, testDarwinCGOSettings, macho.CpuArm64, macho.TypeExec)
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		data = bytes.ReplaceAll(data, []byte(" Go buildinf:"), []byte(" no buildinf:"))
		mustWriteFile(t, path, string(data), 0o755)
		if got := darwinCGOResolvDependencies(path, machOInfo{dependencies: []string{testNixResolv}}); len(got) != 0 {
			t.Fatalf("dependencies=%q", got)
		}
	})
	t.Run("fat file", func(t *testing.T) {
		path := filepath.Join(t.TempDir(), "fat")
		mustWriteFile(t, path, "\xca\xfe\xba\xbe"+strings.Repeat("\x00", 28), 0o755)
		if got := darwinCGOResolvDependencies(path, machOInfo{dependencies: []string{testNixResolv}}); len(got) != 0 {
			t.Fatalf("dependencies=%q", got)
		}
	})
}

// A minimal thin Mach-O with the standard inline Go build-info encoding.
// The fixture is parsed, never executed, so policy tests run on Linux as well.
func writeGoMachOFixture(t *testing.T, settings string, cpu macho.Cpu, fileType macho.Type) string {
	t.Helper()
	data := append([]byte("\xff Go buildinf:\x08\x02"), make([]byte, 16)...)
	for _, text := range []string{"go1.26.0", strings.Repeat("x", 16) + settings + strings.Repeat("x", 16)} {
		data = binary.AppendUvarint(data, uint64(len(text)))
		data = append(data, text...)
	}
	const offset = 4096
	const addr = 0x100001000
	var header bytes.Buffer
	write := func(value any) {
		t.Helper()
		if err := binary.Write(&header, binary.LittleEndian, value); err != nil {
			t.Fatal(err)
		}
	}
	write(macho.FileHeader{Magic: macho.Magic64, Cpu: cpu, Type: fileType, Ncmd: 1, Cmdsz: 72 + 80})
	write(uint32(0))
	segment := macho.Segment64{Cmd: macho.LoadCmdSegment64, Len: 72 + 80, Addr: addr, Memsz: uint64(len(data)), Offset: offset, Filesz: uint64(len(data)), Nsect: 1}
	copy(segment.Name[:], "__DATA")
	write(segment)
	section := macho.Section64{Addr: addr, Size: uint64(len(data)), Offset: offset}
	copy(section.Name[:], "__go_buildinfo")
	copy(section.Seg[:], "__DATA")
	write(section)
	result := append(header.Bytes(), make([]byte, offset-header.Len())...)
	result = append(result, data...)
	path := filepath.Join(t.TempDir(), "fixture")
	mustWriteFile(t, path, string(result), 0o755)
	return path
}

func TestInspectMachOFile(t *testing.T) {
	t.Parallel()
	for _, signed := range []bool{false, true} {
		t.Run(map[bool]string{false: "unsigned", true: "signed"}[signed], func(t *testing.T) {
			file := &macho.File{ByteOrder: binary.LittleEndian}
			if signed {
				raw := make([]byte, 16)
				binary.LittleEndian.PutUint32(raw, codeSignature)
				file.Loads = append(file.Loads, macho.LoadBytes(raw))
			}
			if got := inspectMachOFile(file); got.hasSignature != signed {
				t.Fatalf("hasSignature=%v want=%v", got.hasSignature, signed)
			}
		})
	}
}

func TestMachOInfoMerge(t *testing.T) {
	t.Parallel()
	info := machOInfo{}
	info.merge(machOInfo{hasSignature: true, hasNixLoad: true, dependencies: []string{testNixResolv}})
	info.merge(machOInfo{})
	if !info.hasSignature || !info.hasNixLoad || !reflect.DeepEqual(info.dependencies, []string{testNixResolv}) {
		t.Fatalf("lost merged state: %+v", info)
	}
}

func TestNormalizeMachO(t *testing.T) {
	t.Run("unchanged needs no tools", func(t *testing.T) {
		t.Setenv("PATH", t.TempDir())
		path := writeGoMachOFixture(t, testDarwinCGOSettings, macho.CpuArm64, macho.TypeExec)
		before := fileHash(t, path)
		if _, err := normalizeMachO(path); err != nil {
			t.Fatal(err)
		}
		if before != fileHash(t, path) {
			t.Fatal("unchanged Mach-O was rewritten")
		}
	})
	t.Run("malformed", func(t *testing.T) {
		path := filepath.Join(t.TempDir(), "invalid")
		mustWriteFile(t, path, "\xcf\xfa\xed\xfe", 0o755)
		if _, err := normalizeMachO(path); err == nil {
			t.Fatal("malformed Mach-O was accepted")
		}
	})
	t.Run("native tools", func(t *testing.T) {
		if runtime.GOOS != "darwin" || runtime.GOARCH != "arm64" {
			t.Skip("requires Darwin arm64 signing and linker tools")
		}
		for _, tool := range []string{"go", "clang", "install_name_tool"} {
			if _, err := exec.LookPath(tool); err != nil {
				t.Skipf("%s unavailable: %v", tool, err)
			}
		}
		root := t.TempDir()
		source := filepath.Join(root, "main.go")
		mustWriteFile(t, source, `package main
/*
#cgo LDFLAGS: -lresolv
*/
import "C"
import ("net"; "os")
func main() {
	addrs, err := net.LookupHost("localhost")
	if err != nil || len(addrs) == 0 { os.Exit(1) }
}
`, 0o644)
		original := filepath.Join(root, "resolver")
		command := exec.Command("go", "build", "-ldflags=-linkmode=external -extldflags=-Wl,-headerpad_max_install_names", "-o", original, source)
		command.Env = append(os.Environ(), "CGO_ENABLED=1", "GOOS=darwin", "GOARCH=arm64")
		runTestCommand(t, command)

		entitlements := filepath.Join(root, "entitlements.plist")
		mustWriteFile(t, entitlements, `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>com.apple.security.virtualization</key><true/></dict></plist>
`, 0o644)
		for _, name := range []string{"unsigned", "entitlements", "unknown dependency", "pure go metadata", "linux artifact", "rpath only", "tool failure"} {
			t.Run(name, func(t *testing.T) {
				path := filepath.Join(t.TempDir(), "resolver")
				data, err := os.ReadFile(original)
				if err != nil {
					t.Fatal(err)
				}
				if name == "pure go metadata" {
					data = bytes.ReplaceAll(data, []byte("CGO_ENABLED=1"), []byte("CGO_ENABLED=0"))
				}
				mustWriteFile(t, path, string(data), 0o755)
				runTestCommand(t, exec.Command("/usr/bin/codesign", "--remove-signature", path))
				dependency := testNixResolv
				if name == "unknown dependency" {
					dependency = strings.ReplaceAll(testNixResolv, "-libresolv-96/", "-other-96/")
				}
				if name != "rpath only" {
					runTestCommand(t, exec.Command("install_name_tool", "-change", "/usr/lib/libresolv.9.dylib", dependency, path))
					info, err := inspectMachO(path)
					if err != nil || !strings.Contains(strings.Join(info.dependencies, "\n"), dependency) {
						t.Fatalf("fixture did not acquire dependency %s: %+v, %v", dependency, info, err)
					}
				} else {
					runTestCommand(t, exec.Command("install_name_tool", "-add_rpath", "/nix/store/test/lib", path))
				}
				if name == "entitlements" {
					runTestCommand(t, exec.Command("/usr/bin/codesign", "--force", "--sign", "-", "--identifier", "artifact.fixture", "--entitlements", entitlements, path))
				}
				before := fileHash(t, path)
				cfg := config{platform: platformDarwin}
				if name == "linux artifact" {
					cfg.platform = platformLinux
				}
				if name == "tool failure" {
					t.Setenv("PATH", t.TempDir())
				}
				err = normalizeFile(path, cfg)
				switch name {
				case "unknown dependency", "pure go metadata", "tool failure":
					if err == nil {
						t.Fatal("expected rejected dependency or failed tool")
					}
					if before != fileHash(t, path) {
						t.Fatal("ineligible or failed rewrite changed the binary")
					}
					return
				case "linux artifact":
					if err != nil || before != fileHash(t, path) {
						t.Fatalf("Linux artifact changed Mach-O: %v", err)
					}
					return
				}
				if err != nil {
					t.Fatal(err)
				}
				runTestCommand(t, exec.Command("/usr/bin/codesign", "--verify", "--strict", path))
				if name == "entitlements" {
					got := runTestCommand(t, exec.Command("/usr/bin/codesign", "--display", "--entitlements", ":-", path))
					if !bytes.Contains(got, []byte("com.apple.security.virtualization")) {
						t.Fatalf("entitlement lost: %s", got)
					}
					got = runTestCommand(t, exec.Command("/usr/bin/codesign", "--display", "--verbose", path))
					if !bytes.Contains(got, []byte("Identifier=artifact.fixture")) {
						t.Fatalf("identifier lost: %s", got)
					}
				}
				command := exec.Command(path)
				command.Env = append(os.Environ(), "GODEBUG=netdns=cgo")
				runTestCommand(t, command)
				after := fileHash(t, path)
				if err := normalizeFile(path, cfg); err != nil || after != fileHash(t, path) {
					t.Fatalf("normalization is not idempotent: %v", err)
				}
			})
		}
	})
}

func runTestCommand(t *testing.T, command *exec.Cmd) []byte {
	t.Helper()
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("%v: %v\n%s", command.Args, err, output)
	}
	return output
}
