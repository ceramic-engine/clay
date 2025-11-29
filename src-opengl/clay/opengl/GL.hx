package clay.opengl;

#if clay_web

    typedef GL                  = clay.opengl.web.GL;
    typedef GLActiveInfo        = clay.opengl.web.GL.GLActiveInfo;
    typedef GLBuffer            = clay.opengl.web.GL.GLBuffer;
    typedef GLContextAttributes = clay.opengl.web.GL.GLContextAttributes;
    typedef GLFramebuffer       = clay.opengl.web.GL.GLFramebuffer;
    typedef GLProgram           = clay.opengl.web.GL.GLProgram;
    typedef GLRenderbuffer      = clay.opengl.web.GL.GLRenderbuffer;
    typedef GLShader            = clay.opengl.web.GL.GLShader;
    typedef GLTexture           = clay.opengl.web.GL.GLTexture;
    typedef GLUniformLocation   = clay.opengl.web.GL.GLUniformLocation;

#elseif (clay_native && linc_opengl)

    typedef GL                  = opengl.WebGL;
    typedef GLActiveInfo        = opengl.WebGL.GLActiveInfo;
    typedef GLBuffer            = opengl.WebGL.GLBuffer;
    typedef GLContextAttributes = opengl.WebGL.GLContextAttributes;
    typedef GLFramebuffer       = opengl.WebGL.GLFramebuffer;
    typedef GLProgram           = opengl.WebGL.GLProgram;
    typedef GLRenderbuffer      = opengl.WebGL.GLRenderbuffer;
    typedef GLShader            = opengl.WebGL.GLShader;
    typedef GLTexture           = opengl.WebGL.GLTexture;
    typedef GLUniformLocation   = opengl.WebGL.GLUniformLocation;

#end
