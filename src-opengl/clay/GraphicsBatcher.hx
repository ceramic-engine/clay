package clay;

/**
 * Platform-specific graphics batcher for batched rendering.
 *
 * On OpenGL platforms, this resolves to GLGraphicsBatcher which provides
 * optimized vertex batching and draw call submission using GL APIs.
 */
typedef GraphicsBatcher = clay.opengl.GLGraphicsBatcher;
