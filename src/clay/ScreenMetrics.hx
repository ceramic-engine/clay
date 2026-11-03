package clay;

/**
 * Size computations shared by the runtimes and `Clay.updateScreen()`,
 * kept pure so that they can be tested on their own (see test/ScreenMetricsTest.hx).
 */
class ScreenMetrics {

    /**
     * Logical size covering `pixels` pixels at `density`: rounded up (with a
     * small tolerance for density values that are not exact as floats, like
     * 1.100000023841858) so that the logical area covers every pixel of the
     * window, slightly overflowing it if needed, rather than stopping before
     * its last row or column.
     */
    public static inline function logicalSize(pixels:Int, density:Float):Int {

        return Math.ceil(pixels / density - 0.0001);

    }

    /**
     * Number of pixels a canvas needs along one axis to cover its box exactly.
     *
     * `reportedPixels` is the size of the box in device pixels as reported by
     * the browser (`ResizeObserver` with `device-pixel-content-box`), or -1 when
     * not supported (Safari). That report comes asynchronously, after layout:
     * right after a resize or a change of device pixel ratio, it is still the
     * size of the previous box. It is only used when it matches the box read
     * now: `cssSize` times `dpr`, within the snapping of its edges to device
     * pixels, which moves the size by less than one pixel (each edge is
     * rounded to the nearest pixel). A report one pixel or more away is the
     * size of another box (a stale one, by one pixel after a resize of half
     * a css pixel at 2x for instance): the size is then computed from the
     * (non rounded) css size.
     */
    public static function canvasPixelSize(reportedPixels:Int, cssSize:Float, dpr:Float):Int {

        if (reportedPixels > 0 && Math.abs(reportedPixels - cssSize * dpr) < 1.0)
            return reportedPixels;

        return Math.round(cssSize * dpr);

    }

}
