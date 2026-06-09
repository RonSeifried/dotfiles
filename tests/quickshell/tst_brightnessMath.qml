import QtQuick
import QtTest
import "../../.config/quickshell/services/brightness/lib/brightnessMath.js" as B

TestCase {
    name: "brightnessMath"

    function test_frac_basic() { compare(B.frac(120, 240), 0.5) }
    function test_frac_zero_max() { compare(B.frac(50, 0), 0.0) }
    function test_frac_clamps() { compare(B.frac(500, 240), 1.0) }
    function test_clampFrac_floor() { compare(B.clampFrac(0.0), 0.05) }
    function test_clampFrac_ceil() { compare(B.clampFrac(2.0), 1.0) }
    function test_clampFrac_passthrough() { compare(B.clampFrac(0.5), 0.5) }
    function test_pct_from_frac() { compare(B.pct(0.5), 50) }
    function test_pct_rounds() { compare(B.pct(0.333), 33) }
}
