/*
 *******************************************************************************************
 * Dgame (a D game framework) - Copyright (c) Randy Schütt
 * 
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not claim
 *    that you wrote the original software. If you use this software in a product,
 *    an acknowledgment in the product documentation would be appreciated but is
 *    not required.
 * 
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 
 * 3. This notice may not be removed or altered from any source distribution.
 *******************************************************************************************
 */
module Dgame.Graphics.Renderer;

private {
	import derelict.sdl2.sdl;
	
	import Dgame.Math.Rect;
	import Dgame.Graphics.Surface;
	import Dgame.Graphics.Color;
	import Dgame.Graphics.RendererTexture;
	import Dgame.Window.Window;
	import Dgame.Internal.Unique;
}

/**
 * Renderer support (hardware) accelerated rendering.
 *
 * Author: rschuett
 */
final class Renderer {
	/**
	 * Supported BlendModes
	 */
	enum BlendMode {
		None  = SDL_BLENDMODE_NONE,	    /** no blending */
		Blend = SDL_BLENDMODE_BLEND,	/** dst = (src * A) + (dst * (1-A)) */
		Add   = SDL_BLENDMODE_ADD,		/** dst = (src * A) + dst */
		Mod   = SDL_BLENDMODE_MOD,		/** dst = src * dst */
	}
	
	/**
	 * Supported Flags
	 */
	enum Flags {
		Software = SDL_RENDERER_SOFTWARE,			/** the renderer is a software fallback */
		HwAccel  = SDL_RENDERER_ACCELERATED,		/** the renderer uses hardware acceleration */
		VSync    = SDL_RENDERER_PRESENTVSYNC,		/** present is synchronized with the refresh rate */
		TargetTexture = SDL_RENDERER_TARGETTEXTURE	/** the renderer supports rendering to texture */
	}
	
	/**
	 * Flags
	 */
	const Flags flags;
	
private:
	unique_ptr!(SDL_Renderer) _target;
	
	ushort _width;
	ushort _height;
	
private:
	/**
	 * CTor
	 */
	this(SDL_Renderer* renderer, ushort w, ushort h) in {
		assert(renderer !is null, "Renderer is null.");
	} body {
		this._target = make_unique(renderer, (SDL_Renderer* re) => SDL_DestroyRenderer(re));
		
		this._width  = w;
		this._height = h;
		
		SDL_RendererInfo renderInfo;
		if (SDL_GetRendererInfo(renderer, &renderInfo) == 0)
			this.flags = cast(Flags) renderInfo.flags;
		else
			throw new Exception("Could not detect Renderer Flags.");
	}
	
	/**
	 * Set a texture as the current rendering target.
	 */
	bool setTarget(SDL_Texture* tex, ushort w, ushort h) {
		this._width  = w;
		this._height = h;
		
		return SDL_SetRenderTarget(this._target, tex) == 0;
	}
	
public:
	/**
	 * Use this function to get the renderer associated with the window.
	 */
	static Renderer getFrom(Window win) {
		SDL_Window* window = SDL_GetWindowFromID(win.id);
		
		return new Renderer(SDL_GetRenderer(window), win.width, win.height);
	}
	
	/**
	 * Use this function to get the number of 2D rendering drivers available for the current display.
	 */
	static int countDrivers() {
		return SDL_GetNumRenderDrivers();
	}
	
	/**
	 * Use this function to create a 2D rendering context for a window.
	 */
	this(Window win, Flags flags) {
		SDL_Window* window = SDL_GetWindowFromID(win.id);
		
		this(SDL_CreateRenderer(window, -1, flags), win.width, win.height);
	}
	
	/**
	 * Use this function to create a 2D software rendering context for a Surface.
	 */
	this(ref Surface srfc) {
		this(SDL_CreateSoftwareRenderer(srfc.ptr), srfc.width, srfc.height);
	}
	
	@disable
	void opAssign(Renderer rhs);
	
	/**
	 * Returns the width
	 */
	@property
	ushort width() const pure nothrow {
		return this._width;
	}
	
	/**
	 * Returns the height
	 */
	@property
	ushort height() const pure nothrow {
		return this.height;
	}
	
	/**
	 * Use this function to update the screen with rendering performed.
	 */
	void present() {
		SDL_RenderPresent(this._target);
	}
	
	/**
	 * Use this function to set the blend mode for a texture, used by 'copy'.
	 */
	void setBlendMode(BlendMode bmode) {
		SDL_SetRenderDrawBlendMode(this._target, bmode);
	}
	
	/**
	 * Use this function to get the blend mode used for texture copy operations.
	 */
	BlendMode getBlendMode() {
		SDL_BlendMode blendMode;
		SDL_GetRenderDrawBlendMode(this._target, &blendMode);
		
		return cast(BlendMode) blendMode;
	}
	
	/**
	 * Use this function to set the color used for drawing operations (clear).
	 */
	void setDrawColor(ref const Color col) {
		this.setDrawColor(col.red, col.green, col.blue, col.alpha);
	}
	
	/**
	 * Rvalue version
	 */
	void setDrawColor(const Color col) {
		this.setDrawColor(col);
	}
	
	/**
	 * Use this function to set the color used for drawing operations (clear).
	 */
	void setDrawColor(ubyte r, ubyte g, ubyte b, ubyte a) {
		SDL_SetRenderDrawColor(this._target, r, g, b, a);
	}
	
	/**
	 * Use this function to create a texture for a rendering context.
	 */
	RendererTexture createSoftTexture(ushort width, ushort height, RendererTexture.Access access) {
		SDL_Texture* tex = SDL_CreateTexture(this._target, SDL_PIXELFORMAT_UNKNOWN, access, width, height);
		
		return RendererTexture(tex, access);
	}
	
	/**
	 * Use this function to create a texture from an existing surface.
	 */
	RendererTexture createRendererTexture(ref Surface srfc, bool release = false,
	                                      RendererTexture.Access access = RendererTexture.Access.Static)
	{
		scope(exit) {
			if (release)
				srfc.free();
		}
		
		if (access & RendererTexture.Access.Static) {
			SDL_Texture* tex = SDL_CreateTextureFromSurface(this._target, srfc.ptr);
			
			return RendererTexture(tex, access);
		}
		
		RendererTexture hw = this.createSoftTexture(srfc.width, srfc.height, access);
		hw.update(srfc.pixels, null);
		
		return hw;
	}
	
	/**
	 * Rvalue version
	 */
	RendererTexture createRendererTexture(Surface srfc, bool release = false,
	                                      RendererTexture.Access access = RendererTexture.Access.Static)
	{
		return this.createRendererTexture(srfc, release, access);
	}
	
	/**
	 * Set a Surface as the current rendering target.
	 */
	bool setTarget(ref Surface srfc) {
		SDL_Texture* tex = SDL_CreateTextureFromSurface(this._target, srfc.ptr);
		
		return this.setTarget(tex, srfc.width, srfc.height);
	}
	
	/**
	 * Set a SoftTexture as the current rendering target.
	 */
	bool setTarget(ref RendererTexture hw) {
		return this.setTarget(hw.ptr, hw.width, hw.height);
	}
	
	/**
	 * Use this function to copy a portion of the texture to the current rendering target.
	 */
	bool copy(ref RendererTexture hw, const ShortRect* src = null, const ShortRect *dst = null) {
		SDL_Rect a = void;
		SDL_Rect b = void;

		const SDL_Rect* _src = transfer(src, &a);
		const SDL_Rect* _dst = transfer(dst, &b);
		
		return SDL_RenderCopy(this._target, hw.ptr, _src, _dst) == 0;
	}
	
	/**
	 * Use this function to clear the current rendering target with the drawing color.
	 */
	void clear() {
		SDL_RenderClear(this._target);
	}
	
	/**
	 * Use this function to set the drawing area for rendering on the current target.
	 */
	void setViewport(ref const ShortRect view) {
		SDL_Rect a = void;
		view.transferTo(&a);

		SDL_RenderSetViewport(this._target, &a);
	}
	
	/**
	 * Rvalue version
	 */
	void setViewport(const ShortRect view) {
		this.setViewport(view);
	}
	
	/**
	 * Use this function to get the drawing area for the current target.
	 */
	ShortRect getViewport() {
		SDL_Rect a = void;
		SDL_RenderGetViewport(this._target, &a);
		
		return ShortRect(a);
	}
	
	/**
	 * Use this function to read pixels from the current rendering target.
	 * Note: This is a very slow operation, and should not be used frequently.
	 * Note: This method <b>allocates</b> GC memory.
	 *
	 * rect represents the area to read, or null for the entire render target
	 */
	void* readPixels(const ShortRect* rect) {
		void[] pixels = new void[rect.width * rect.height * 4];

		SDL_Rect a = void;
		const SDL_Rect* area = transfer(rect, &a);

		SDL_RenderReadPixels(this._target, area, 0, &pixels[0], this._width * 4);
		
		return &pixels[0];
	}
}
