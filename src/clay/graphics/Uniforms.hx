package clay.graphics;

import clay.Types;
import clay.buffers.Float32Array;
import clay.buffers.Int32Array;

using clay.Extensions;

class Uniforms {

#if web
    // On web, we identify uniforms by their name

    var ints        :Map<String,Int> = new Map();
    var intArrays   :Map<String,Int32Array> = new Map();
    var floats      :Map<String,Float> = new Map();
    var floatArrays :Map<String,Float32Array> = new Map();
    var vector2s    :Map<String,Vector2> = new Map();
    var vector3s    :Map<String,Vector3> = new Map();
    var vector4s    :Map<String,Vector4> = new Map();
    var matrix4s    :Map<String,Float32Array> = new Map();
    var colors      :Map<String,Color> = new Map();
    var textures    :Map<String,TextureAndSlot> = new Map();

    var dirtyInts          :Array<String> = [];
    var dirtyIntArrays     :Array<String> = [];
    var dirtyFloats        :Array<String> = [];
    var dirtyFloatArrays   :Array<String> = [];
    var dirtyVector2s      :Array<String> = [];
    var dirtyVector3s      :Array<String> = [];
    var dirtyVector4s      :Array<String> = [];
    var dirtyMatrix4s      :Array<String> = [];
    var dirtyColors        :Array<String> = [];
    var dirtyTextures      :Array<String> = [];
#else
    // On native, we can identify uniforms with integers: better

    var ints        :IntMap<Int> = new IntMap();
    var intArrays   :IntMap<Int32Array> = new IntMap();
    var floats      :IntMap<Float> = new IntMap();
    var floatArrays :IntMap<Float32Array> = new IntMap();
    var vector2s    :IntMap<Vector2> = new IntMap();
    var vector3s    :IntMap<Vector3> = new IntMap();
    var vector4s    :IntMap<Vector4> = new IntMap();
    var matrix4s    :IntMap<Float32Array> = new IntMap();
    var colors      :IntMap<Color> = new IntMap();
    var textures    :IntMap<TextureAndSlot> = new IntMap();

    var dirtyInts          :Array<Int> = [];
    var dirtyIntArrays     :Array<Int> = [];
    var dirtyFloats        :Array<Int> = [];
    var dirtyFloatArrays   :Array<Int> = [];
    var dirtyVector2s      :Array<Int> = [];
    var dirtyVector3s      :Array<Int> = [];
    var dirtyVector4s      :Array<Int> = [];
    var dirtyMatrix4s      :Array<Int> = [];
    var dirtyColors        :Array<Int> = [];
    var dirtyTextures      :Array<Int> = [];
#end

    public var gpuShader(default, null):GpuShader;

    public function new(gpuShader:GpuShader) {

        this.gpuShader = gpuShader;

    }

    public function setInt(name:String, value:Int):Void {

        var location = Graphics.getUniformLocation(gpuShader, name);
        
        #if web
        ints.set(name, value);
        dirtyInts.push(name);
        #else
        ints.set(location, value);
        dirtyInts.push(location);
        #end

    }

    public function setIntArray(name:String, value:Int32Array):Void {

        var location = Graphics.getUniformLocation(gpuShader, name);
        
        #if web
        intArrays.set(name, value);
        dirtyIntArrays.push(name);
        #else
        intArrays.set(location, value);
        dirtyIntArrays.push(location);
        #end

    }

    public function setFloat(name:String, value:Float):Void {

        var location = Graphics.getUniformLocation(gpuShader, name);
        
        #if web
        floats.set(name, value);
        dirtyFloats.push(name);
        #else
        floats.set(location, value);
        dirtyFloats.push(location);
        #end

    }

    public function setFloatArray(name:String, value:Float32Array):Void {

        var location = Graphics.getUniformLocation(gpuShader, name);
        
        #if web
        floatArrays.set(name, value);
        dirtyFloatArrays.push(name);
        #else
        floatArrays.set(location, value);
        dirtyFloatArrays.push(location);
        #end

    }

    public function setVector2(name:String, x:Float, y:Float):Void {

        var location = Graphics.getUniformLocation(gpuShader, name);
        
        #if web
        var existing = vector2s.get(name);
        if (existing != null) {
            existing.x = x;
            existing.y = y;
        }
        else {
            vector2s.set(name, { x: x, y: y });
        }
        dirtyVector2s.push(name);
        #else
        var existing = vector2s.get(location);
        if (existing != null) {
            existing.x = x;
            existing.y = y;
        }
        else {
            vector2s.set(location, { x: x, y: y });
        }
        dirtyVector2s.push(location);
        #end

    }

    public function setVector3(name:String, x:Float, y:Float, z:Float):Void {

        var location = Graphics.getUniformLocation(gpuShader, name);
        
        #if web
        var existing = vector3s.get(name);
        if (existing != null) {
            existing.x = x;
            existing.y = y;
            existing.z = z;
        }
        else {
            vector3s.set(name, { x: x, y: y, z: z });
        }
        dirtyVector3s.push(name);
        #else
        var existing = vector3s.get(location);
        if (existing != null) {
            existing.x = x;
            existing.y = y;
            existing.z = z;
        }
        else {
            vector3s.set(location, { x: x, y: y, z: z });
        }
        dirtyVector3s.push(location);
        #end

    }

    public function setVector4(name:String, x:Float, y:Float, z:Float, w:Float):Void {

        var location = Graphics.getUniformLocation(gpuShader, name);
        
        #if web
        var existing = vector4s.get(name);
        if (existing != null) {
            existing.x = x;
            existing.y = y;
            existing.z = z;
            existing.w = w;
        }
        else {
            vector4s.set(name, { x: x, y: y, z: z, w: w });
        }
        dirtyVector4s.push(name);
        #else
        var existing = vector4s.get(location);
        if (existing != null) {
            existing.x = x;
            existing.y = y;
            existing.z = z;
            existing.w = w;
        }
        else {
            vector4s.set(location, { x: x, y: y, z: z, w: w });
        }
        dirtyVector4s.push(location);
        #end

    }

    public function setMatrix4(name:String, value:Float32Array):Void {

        var location = Graphics.getUniformLocation(gpuShader, name);
        
        #if web
        var existing = matrix4s.get(name);
        if (existing == null) {
            existing = new Float32Array(16);
            matrix4s.set(name, existing);
        }
        for (i in 0...16) {
            existing[i] = value[i];
        }
        dirtyMatrix4s.push(name);
        #else
        var existing = matrix4s.get(location);
        if (existing == null) {
            existing = new Float32Array(16);
            matrix4s.set(location, existing);
        }
        for (i in 0...16) {
            existing[i] = value[i];
        }
        dirtyMatrix4s.push(location);
        #end

    }

    public function setColor(name:String, r:Float, g:Float, b:Float, a:Float):Void {

        var location = Graphics.getUniformLocation(gpuShader, name);
        
        #if web
        var existing = colors.get(name);
        if (existing != null) {
            existing.r = r;
            existing.g = g;
            existing.b = b;
            existing.a = a;
        }
        else {
            colors.set(name, { r: r, g: g, b: b, a: a });
        }
        dirtyColors.push(name);
        #else
        var existing = colors.get(location);
        if (existing != null) {
            existing.r = r;
            existing.g = g;
            existing.b = b;
            existing.a = a;
        }
        else {
            colors.set(location, { r: r, g: g, b: b, a: a });
        }
        dirtyColors.push(location);
        #end

    }

    public function setTexture(name:String, slot:Int, texture:Texture):Void {

        var location = Graphics.getUniformLocation(gpuShader, name);

        #if web
        var existing = textures.get(name);
        if (existing != null) {
            existing.texture = texture;
            existing.slot = slot;
        }
        else {
            textures.set(name, { texture: texture, slot: slot });
        }
        if (dirtyTextures.indexOf(name) == -1)
            dirtyTextures.push(name);
        #else
        var existing = textures.get(location);
        if (existing != null) {
            existing.texture = texture;
            existing.slot = slot;
        }
        else {
            textures.set(location, { texture: texture, slot: slot });
        }
        if (dirtyTextures.indexOf(location) == -1)
            dirtyTextures.push(location);
        #end

    }

    public function apply():Void {

        Graphics.useShader(gpuShader);

        while (dirtyInts.length > 0) {
            #if web
            var name = dirtyInts.pop();
            var location = Graphics.getUniformLocation(gpuShader, name);
            Graphics.setIntUniform(gpuShader, location, ints.get(name));
            #else
            var location = dirtyInts.pop();
            Graphics.setIntUniform(gpuShader, location, ints.get(location));
            #end
        }

        while (dirtyIntArrays.length > 0) {
            #if web
            var name = dirtyIntArrays.pop();
            var location = Graphics.getUniformLocation(gpuShader, name);
            Graphics.setIntArrayUniform(gpuShader, location, intArrays.get(name));
            #else
            var location = dirtyIntArrays.pop();
            Graphics.setIntArrayUniform(gpuShader, location, intArrays.get(location));
            #end
        }

        while (dirtyFloats.length > 0) {
            #if web
            var name = dirtyFloats.pop();
            var location = Graphics.getUniformLocation(gpuShader, name);
            Graphics.setFloatUniform(gpuShader, location, floats.get(name));
            #else
            var location = dirtyFloats.pop();
            Graphics.setFloatUniform(gpuShader, location, floats.get(location));
            #end
        }

        while (dirtyFloatArrays.length > 0) {
            #if web
            var name = dirtyFloatArrays.pop();
            var location = Graphics.getUniformLocation(gpuShader, name);
            Graphics.setFloatArrayUniform(gpuShader, location, floatArrays.get(name));
            #else
            var location = dirtyFloatArrays.pop();
            Graphics.setFloatArrayUniform(gpuShader, location, floatArrays.get(location));
            #end
        }

        while (dirtyVector2s.length > 0) {
            #if web
            var name = dirtyVector2s.pop();
            var location = Graphics.getUniformLocation(gpuShader, name);
            var value = vector2s.get(name);
            Graphics.setVector2Uniform(gpuShader, location, value.x, value.y);
            #else
            var location = dirtyVector2s.pop();
            var value = vector2s.get(location);
            Graphics.setVector2Uniform(gpuShader, location, value.x, value.y);
            #end
        }

        while (dirtyVector3s.length > 0) {
            #if web
            var name = dirtyVector3s.pop();
            var location = Graphics.getUniformLocation(gpuShader, name);
            var value = vector3s.get(name);
            Graphics.setVector3Uniform(gpuShader, location, value.x, value.y, value.z);
            #else
            var location = dirtyVector3s.pop();
            var value = vector3s.get(location);
            Graphics.setVector3Uniform(gpuShader, location, value.x, value.y, value.z);
            #end
        }

        while (dirtyVector4s.length > 0) {
            #if web
            var name = dirtyVector4s.pop();
            var location = Graphics.getUniformLocation(gpuShader, name);
            var value = vector4s.get(name);
            Graphics.setVector4Uniform(gpuShader, location, value.x, value.y, value.z, value.w);
            #else
            var location = dirtyVector4s.pop();
            var value = vector4s.get(location);
            Graphics.setVector4Uniform(gpuShader, location, value.x, value.y, value.z, value.w);
            #end
        }

        while (dirtyMatrix4s.length > 0) {
            #if web
            var name = dirtyMatrix4s.pop();
            var location = Graphics.getUniformLocation(gpuShader, name);
            Graphics.setMatrix4Uniform(gpuShader, location, matrix4s.get(name));
            #else
            var location = dirtyMatrix4s.pop();
            Graphics.setMatrix4Uniform(gpuShader, location, matrix4s.get(location));
            #end
        }

        while (dirtyColors.length > 0) {
            #if web
            var name = dirtyColors.pop();
            var location = Graphics.getUniformLocation(gpuShader, name);
            var value = colors.get(name);
            #else
            var location = dirtyColors.pop();
            var value = colors.get(location);
            #end
            Graphics.setColorUniform(gpuShader, location, value.r, value.g, value.b, value.a);
        }

        // Textures are always kept 'dirty' as they should always be bound to the correct slot again
        for (i in 0...dirtyTextures.length) {
            #if web
            var name = dirtyTextures.unsafeGet(i);
            var location = Graphics.getUniformLocation(gpuShader, name);
            var value = textures.get(name);
            #else
            var location = dirtyTextures.unsafeGet(i);
            var value = textures.get(location);
            #end
            switch value.texture.type {
                case TEXTURE_2D:
                    Graphics.setTexture2dUniform(gpuShader, location, value.slot, value.texture.textureId);
            }
        }

    }

    public function clone():Uniforms {

        var uniforms = new Uniforms(gpuShader);
        return uniforms;

    }

}
