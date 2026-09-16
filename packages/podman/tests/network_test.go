package netavark

import (
	"os"
	"testing"
)

// Exercise the actual loader, including validation and silent-default fallback.
func TestStandaloneNetwork(t *testing.T) {
	dir := os.Getenv("PODMAN_TEST_NETWORK_DIR")
	n := &netavarkNetwork{networkConfigDir: dir, defaultNetwork: "podman"}
	if err := n.loadNetworks(); err != nil {
		t.Fatal(err)
	}
	net := n.networks["podman"]
	if net == nil || !net.IPv6Enabled || !net.DNSEnabled || net.NetworkInterface != "podman0" {
		t.Fatalf("incorrect network: %+v", net)
	}
	ipv4, ipv6 := 0, 0
	for _, subnet := range net.Subnets {
		if subnet.Subnet.IP.To4() != nil {
			ipv4++
		} else {
			ipv6++
		}
	}
	if ipv4 != 1 || ipv6 != 1 {
		t.Fatalf("IPv4=%d IPv6=%d", ipv4, ipv6)
	}
}
