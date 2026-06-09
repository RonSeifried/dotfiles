import QtQuick
import QtTest
import "../../.config/quickshell/components/lib/sliderMath.js" as M

TestCase {
    name: "sliderMath"

    function test_frac_midpoint() {
        compare(M.frac(0.5, 1.0), 0.5)
    }
    function test_frac_clamps_high() {
        compare(M.frac(2.0, 1.0), 1.0)
    }
    function test_frac_clamps_low() {
        compare(M.frac(-1.0, 1.0), 0.0)
    }
    function test_frac_zero_max_is_zero() {
        compare(M.frac(0.5, 0.0), 0.0)
    }
    function test_valueAt_maps_pixel_to_value() {
        compare(M.valueAt(50, 200, 1.0), 0.25)
    }
    function test_valueAt_clamps_overshoot() {
        compare(M.valueAt(300, 200, 1.0), 1.0)
    }
    function test_valueAt_respects_max() {
        compare(M.valueAt(100, 200, 1.5), 0.75)
    }
    function test_valueAt_zero_width_is_zero() {
        compare(M.valueAt(50, 0, 1.0), 0.0)
    }
}
