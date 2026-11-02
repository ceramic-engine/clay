package;

import clay.ScreenMetrics;

/**
 * Tests of `clay.ScreenMetrics`. Run from the clay folder:
 * `haxe test/test-screen.hxml` (interpreter), or `haxe test/test-screen-js.hxml && node test/out/test-screen.js`.
 */
class ScreenMetricsTest {

    static var failures:Int = 0;

    static var checks:Int = 0;

    static function main() {

        testLogicalSizeCoversEveryPixel();
        testLogicalSizeToleratesInexactDensities();
        testReportedSizeIsUsedWhenItMatchesTheBox();
        testStaleReportAfterResizeIsIgnored();
        testStaleReportAfterDprChangeIsIgnored();
        testUnsupportedReport();

        trace('ScreenMetricsTest: ' + checks + ' checks, ' + failures + ' failed');
        #if sys
        Sys.exit(failures > 0 ? 1 : 0);
        #elseif js
        js.Syntax.code("process.exit({0})", failures > 0 ? 1 : 0);
        #end

    }

    static function check(cond:Bool, what:String) {
        checks++;
        if (!cond) {
            failures++;
            trace('FAILED: ' + what);
        }
    }

    static function equals(expected:Int, actual:Int, what:String) {
        check(expected == actual, '$what: expected $expected, got $actual');
    }

    static function testLogicalSizeCoversEveryPixel() {

        equals(1024, ScreenMetrics.logicalSize(1024, 1), 'exact at 1x');
        equals(512, ScreenMetrics.logicalSize(1024, 2), 'exact at 2x');
        // 1001 / 1.5 = 667.33: 668 logical units cover the last pixel column
        equals(668, ScreenMetrics.logicalSize(1001, 1.5), 'rounded up at 1.5x');
        equals(801, ScreenMetrics.logicalSize(1001, 1.25), 'rounded up at 1.25x');
        for (pixels in 1...3000) {
            for (density in [1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 3.0]) {
                final logical = ScreenMetrics.logicalSize(pixels, density);
                check(logical * density >= pixels - 0.001, 'covers $pixels pixels at $density ($logical)');
                check((logical - 1) * density < pixels, 'no extra unit for $pixels pixels at $density ($logical)');
            }
        }

    }

    static function testLogicalSizeToleratesInexactDensities() {

        // devicePixelRatio of 110% zoom as reported by browsers (float32)
        final density = 1.100000023841858;
        equals(1000, ScreenMetrics.logicalSize(1100, density), '1100 pixels at 1.1 (float32)');
        equals(1000, ScreenMetrics.logicalSize(1100, 1.0999999), '1100 pixels at slightly less than 1.1');

    }

    static function testReportedSizeIsUsedWhenItMatchesTheBox() {

        // 801 css pixels at 1.5x cover 1201.5 device pixels: the browser knows
        // which one, from the position of the box
        equals(1201, ScreenMetrics.canvasPixelSize(1201, 801, 1.5), 'exact size 1201');
        equals(1202, ScreenMetrics.canvasPixelSize(1202, 801, 1.5), 'exact size 1202');
        equals(2048, ScreenMetrics.canvasPixelSize(2048, 1024, 2), 'exact size at 2x');
        // fractional css size (zoom)
        equals(69, ScreenMetrics.canvasPixelSize(69, 42.998046875, 1.600000023841858), 'fractional css size');

    }

    static function testStaleReportAfterResizeIsIgnored() {

        // The window went from 1024x740 css pixels to 1024x1024 at 2x: until the
        // observer reports the new box, its report is still 1480 pixels high
        equals(2048, ScreenMetrics.canvasPixelSize(1480, 1024, 2), 'stale height after resize');
        // css 800 -> 801 at 1.5x: the stale 1200 is 1.5 away from 1201.5
        equals(1202, ScreenMetrics.canvasPixelSize(1200, 801, 1.5), 'stale width after a 1 css pixel resize');

    }

    static function testStaleReportAfterDprChangeIsIgnored() {

        // Window moved from a 2x display to a 1x display (or unplugged): same css
        // size, the report is still the one at 2x until the observer catches up
        equals(1024, ScreenMetrics.canvasPixelSize(2048, 1024, 1), 'stale report at the previous dpr');
        equals(2048, ScreenMetrics.canvasPixelSize(1024, 1024, 2), 'stale report from 1x to 2x');
        // Browser zoom 100% -> 150% on a 2x display: css size shrinks, dpr grows
        equals(192, ScreenMetrics.canvasPixelSize(128, 64, 3), 'stale report after zoom');

    }

    static function testUnsupportedReport() {

        // Safari: no device-pixel-content-box, computed from the css size
        equals(1202, ScreenMetrics.canvasPixelSize(-1, 801, 1.5), 'no report at 1.5x');
        equals(855, ScreenMetrics.canvasPixelSize(-1, 777, 1.100000023841858), 'no report at 1.1x');
        equals(2048, ScreenMetrics.canvasPixelSize(-1, 1024, 2), 'no report at 2x');

    }

}
