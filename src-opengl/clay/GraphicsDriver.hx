package clay;

/**
 * Platform-specific graphics driver for GPU resource management.
 *
 * On OpenGL platforms, this resolves to GLGraphicsDriver which provides
 * texture, shader, and render target management using GL APIs.
 *
 * Access the driver instance via Clay.app.graphics.
 */
typedef GraphicsDriver = clay.opengl.GLGraphicsDriver;
