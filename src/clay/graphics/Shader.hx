package clay.graphics;

import clay.Types;

class Shader extends Resource {

    /**
     * Source code of vertex shader (glsl language on GL targets)
     */
    public var vertSource:String = null;

    /**
     * Source code of fragment shader (glsl language on GL targets)
     */
    public var fragSource:String = null;

    /**
     * A list of ordered attribute names that will
     * be assigned indexes in the order of the array.
     * (GL.bindAttribLocation() or similar)
     */
    public var attributes:Array<String> = null;

    /**
     * A list of ordered texture uniform names that will
     * be assigned indexes in the order of the array.
     * (GL.uniform1i() or similar)
     */
    public var textures:Array<String> = null;

    /**
     * Shader uniforms / named parameters.
     */
    public var uniforms:Uniforms = null;

    /**
     * Reference to the actual GPU shader
     */
    public var gpuShader:GpuShader = null;

    public function new() {

    }

    /**
     * Call `init()` after you have set `vertSource` and `fragSource` properties.
     * (and optionally: `attributes` and `textures` properties)
     */
    public function init():Void {

        gpuShader = Graphics.createShader(vertSource, fragSource, attributes, textures);

        if (gpuShader == null) {
            throw 'Failed to create shader (id=$id)';
        }

    }

    public function activate():Void {

        Graphics.useShader(gpuShader);

        if (uniforms != null) {
            uniforms.apply();
        }

    }

    public function destroy():Void {

        Graphics.deleteShader(gpuShader);

    }

}
