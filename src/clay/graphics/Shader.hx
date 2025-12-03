package clay.graphics;

import clay.Types;

class Shader extends Resource {

    #if clay_shader_from_source
    /**
     * Source code of vertex shader (glsl language on GL targets).
     * Only available when clay_shader_from_source is defined.
     */
    public var vertSource:String = null;

    /**
     * Source code of fragment shader (glsl language on GL targets).
     * Only available when clay_shader_from_source is defined.
     */
    public var fragSource:String = null;
    #else
    /**
     * Identifier for the precompiled shader (e.g., asset path or name).
     * Only available when clay_shader_from_source is NOT defined.
     */
    public var shaderId:String = null;
    #end

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

    #if clay_shader_from_source
    /**
     * Call `init()` after you have set `vertSource` and `fragSource` properties.
     * (and optionally: `attributes` and `textures` properties)
     */
    public function init():Void {

        gpuShader = Clay.app.graphics.createShader(vertSource, fragSource, attributes, textures);

        if (gpuShader == null) {
            throw 'Failed to create shader (id=$id)';
        }

        uniforms = new Uniforms(gpuShader);

    }
    #else
    /**
     * Call `init()` after you have set `shaderId` property.
     * (and optionally: `attributes` and `textures` properties)
     */
    public function init():Void {

        gpuShader = Clay.app.graphics.loadShader(shaderId, attributes, textures);

        if (gpuShader == null) {
            throw 'Failed to load shader (id=$id)';
        }

        uniforms = new Uniforms(gpuShader);

    }
    #end

    public function activate():Void {

        Clay.app.graphics.useShader(gpuShader);

        Clay.app.graphics.synchronizeShaderMatrices(gpuShader);

        if (uniforms != null) {
            uniforms.apply();
        }

    }

    public function destroy():Void {

        Clay.app.graphics.deleteShader(gpuShader);

    }

}
