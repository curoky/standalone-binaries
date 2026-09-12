package libpod

import "testing"

func TestStandaloneSeccomp(t *testing.T) {
	path, err := DefaultSeccompPath()
	if err != nil {
		t.Fatal(err)
	}
	if path != "" {
		t.Fatalf("expected built-in seccomp profile, got %q", path)
	}
}
