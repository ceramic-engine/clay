package sample;

import clay.opengl.GL;
import clay.buffers.Float32Array;
import clay.graphics.Shader;
import clay.graphics.Graphics;
import clay.Clay;

using StringTools;

class SampleVertexEvents extends clay.Events {

    public function new() {}

    override function tick(delta:Float) {
        
        SampleVertex.draw();

    }

    override function ready():Void {

        SampleVertex.ready();

    }

}

@:allow(sample.SampleVertexEvents)
class SampleVertex {

    static var events:SampleVertexEvents;

    static var vertShaderData:String ='
attribute vec3 vertexPosition;
attribute vec4 vertexColor;

varying vec4 color;

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

void main(void) {

    gl_Position = vec4(vertexPosition, 1.0);
    color = vertexColor;
    gl_PointSize = 1.0;

}
'.trim();

    static var fragShaderData:String = '
#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

varying vec4 color;

void main() {
    gl_FragColor = color;
}
'.trim();

    static var shader:Shader;

    public static function main():Void {

        events = @:privateAccess new SampleVertexEvents();
        @:privateAccess new Clay(configure, events);
        
    }

    static function configure(config:clay.Config) {

        config.window.resizable = true;

        config.render.stencil = 2;
        config.render.depth = 16;

    }

    static function ready():Void {

        trace('Create shader');
        shader = new Shader();
        shader.vertSource = vertShaderData;
        shader.fragSource = fragShaderData;
        shader.attributes = ['vertexPosition', 'vertexColor'];
        shader.init();
        trace('Did init shader');
        shader.activate();

    }

    static function draw():Void {

        Graphics.clear(0.25, 0.25, 0.25, 1);
        Graphics.setViewport(
            0, 0,
            Std.int(Clay.app.screenWidth * Clay.app.screenDensity),
            Std.int(Clay.app.screenHeight * Clay.app.screenDensity)
        );

        var vertices = Float32Array.fromArray([
            -0.8, -0.8, 0.0, 1.0,
             0.0,  0.8, 0.0, 1.0,
             0.8, -0.8, 0.0, 1.0
        ]);

        var colors = Float32Array.fromArray([
            1.0, 0.0, 0.0, 1.0,
            0.0, 1.0, 0.0, 1.0,
            0.0, 0.0, 1.0, 1.0
        ]);

        GL.enableVertexAttribArray(0);
        GL.enableVertexAttribArray(1);

        var verticesBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ARRAY_BUFFER, verticesBuffer);
        GL.bufferData(GL.ARRAY_BUFFER, vertices, GL.STREAM_DRAW);
        GL.vertexAttribPointer(0, 4, GL.FLOAT, false, 0, 0);

        var colorsBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ARRAY_BUFFER, colorsBuffer);
        GL.bufferData(GL.ARRAY_BUFFER, colors, GL.STREAM_DRAW);
        GL.vertexAttribPointer(1, 4, GL.FLOAT, false, 0, 0);

        GL.drawArrays(GL.TRIANGLES, 0, 3);

        GL.deleteBuffer(verticesBuffer);
        GL.deleteBuffer(colorsBuffer);

        GL.disableVertexAttribArray(0);
        GL.disableVertexAttribArray(1);

        Graphics.ensureNoError();

    }

}
