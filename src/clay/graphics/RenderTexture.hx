package clay.graphics;

import clay.Types;

class RenderTexture extends Texture {

    /**
     * Reference to the actual render target (data may vary depending on the rendering backend)
     */
    public var renderTarget:RenderTarget;

    /**
     * Set to `true` to also allocate a stencil buffer on this render target
     */
    public var stencil:Bool = false;

    /**
     * Antialiasing value. Set it to `2`, `4` or `8` to enable antialiasing/multisampling.
     * Requires OpenGL ES 3 / WebGL 2 or above to work
     * @warning NOT IMPLEMENTED, so this doesn't have any effect for now!
     */
    public var antialiasing:Int = 0;

    public function new() {

        super();

    }

    override function init() {

        super.init();

        // Create render target
        renderTarget = Graphics.createRenderTarget(textureId, width, height, stencil, antialiasing);

    }

    override function destroy() {

        // Delete render target
        if (renderTarget != null) {
            Graphics.deleteRenderTarget(renderTarget);
            renderTarget = null;
        }

        super.destroy();

    }

}
