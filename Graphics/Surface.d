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
module Dgame.Graphics.Surface;

private {
	debug import std.stdio : writefln, writeln;
	import std.string : format, toStringz;
	import std.file : exists;
	import std.conv : to;
	import std.algorithm : reverse;
	import std.exception : enforce;
	import core.stdc.string : memcpy;
	
	import derelict.sdl2.sdl;
	import derelict.sdl2.image;
	
	import Dgame.Internal.Shared;
	
	import Dgame.Math.Rect;
	import Dgame.Math.Vector2;
	import Dgame.Graphics.Color;
}

/**
 * Surface is a wrapper for a SDL_Surface.
 *
 * Author: rschuett
 */
struct Surface {
	/**
	 * Supported BlendModes
	 */
	enum BlendMode : ubyte {
		None   = SDL_BLENDMODE_NONE,	/** no blending */
		Blend  = SDL_BLENDMODE_BLEND,	/** dst = (src * A) + (dst * (1-A)) */
		Add    = SDL_BLENDMODE_ADD,		/** dst = (src * A) + dst */
		Mod    = SDL_BLENDMODE_MOD		/** dst = src * dst */
	}
	
	/**
	 * Supported Color Masks
	 */
	enum Mask : ubyte {
		Red   = 1,	/** Red Mask */
		Green = 2,	/** Green Mask */
		Blue  = 4,	/** Blue Mask */
		Alpha = 8	/** Alpha Mask */
	}
	
	enum RMask = 0; /** Default Red Mask. */
	enum GMask = 0; /** Default Green Mask. */
	enum BMask = 0; /** Default Blue Mask. */
	
	version(LittleEndian) {
		enum AMask = 0xff000000;
	} else {
		enum AMask = 0x000000ff;
	}
	
	/**
	 * Flip mode
	 */
	enum Flip : ubyte {
		Vertical   = 1, /** Vertical Flip */
		Horizontal = 2  /** Horizontal Flip */
	}
	
private:
	shared_ptr!(SDL_Surface) _target;
	string _filename;
	
private:
	/**
	 * Create a new SDL_Surface* of the given width, height and depth.
	 */
	static SDL_Surface* create(ushort width, ushort height, ubyte depth = 32) in {
		assert(depth >= 8 && depth <= 32, "Invalid depth.");
	} body {
		return SDL_CreateRGBSurface(0, width, height, depth, RMask, GMask, BMask, AMask);
	}
	
	/**
	 * Create a new SDL_Surface* of the given memory, width, height and depth.
	 */
	static SDL_Surface* create(void* memory, ushort width, ushort height, ubyte depth = 32) in {
		assert(memory !is null, "Memory is empty.");
		assert(depth >= 8 && depth <= 32, "Invalid depth.");
	} body {
		return SDL_CreateRGBSurfaceFrom(memory, width, height, depth, (depth / 8) * width,
		                                RMask, GMask, BMask, AMask);
	}
	
	/**
	 * CTor
	 */
	this(SDL_Surface* srfc) in {
		assert(srfc !is null, "Invalid SDL_Surface.");
		assert(srfc.pixels !is null, "Invalid pixel data.");
	} body {
		debug writeln("CTor Surface with SDL_Surface: ", srfc);
		this._target = make_shared(srfc, (SDL_Surface* ptr) => SDL_FreeSurface(ptr));
	}
	
public:
	/**
	 * CTor
	 */
	this(string filename) {
		debug writeln("CTor Surface : ", filename);
		this.loadFromFile(filename);
	}
	
	debug(Dgame)
	this(this) {
		writeln("Postblit Surface: ", this._target.usage, ':', this.filename);
	}
	
	debug(Dgame)
	~this() {
		writeln("DTor Surface", ':', this.filename, "::",this._target.usage);
	}
	
	/**
	 * Destroy the current Surface <b>and all</b>, which are linked to this Surface</b>.
	 */
	void free() {
		debug writeln("Free Surface:", this.filename);
		this._target.terminate();
	}
	
	/**
	 * Returns the current use count
	 */
	int useCount() const pure nothrow {
		return this._target.usage;
	}
	
	/**
	 * Make a new Surface of the given width, height and depth.
	 */
	static Surface make(ushort width, ushort height, ubyte depth = 32) {
		SDL_Surface* srfc = Surface.create(width, height, depth);
		if (srfc is null) {
			const string err = to!string(SDL_GetError());
			throw new Exception("Surface konnte nicht erstellt werden: " ~ err);
		}
		
		return Surface(srfc);
	}
	
	/**
	 * Make an new Surface of the given memory, width, height and depth.
	 */
	static Surface make(void* memory, ushort width, ushort height, ubyte depth = 32) {
		SDL_Surface* srfc = Surface.create(memory, width, height, depth);
		if (srfc is null) {
			const string err = to!string(SDL_GetError());
			throw new Exception("Surface konnte nicht erstellt werden: " ~ err);
		}
		
		return Surface(srfc);
	}
	
	/**
	 * Returns if the Surface is valid. Which means that the Surface has valid data.
	 */
	bool isValid() const pure nothrow {
		return this._target.isValid() && this._target.pixels !is null;
	}
	
	/**
	 * Load from filename. If any data is already stored, the data will be freed.
	 */
	void loadFromFile(string filename) {
		debug writefln("Load Image: %s", filename);
		enforce(filename.length >= 4 && exists(filename),
		        "The file " ~ filename ~ " does not exist.");

		SDL_Surface* srfc = IMG_Load(toStringz(filename));
		debug writefln("Image %s loaded :: %X", filename, srfc);
		if (srfc is null) {
			const string err = to!string(SDL_GetError());
			throw new Exception(.format("Could not load image %s. Error: %s.", filename, err));
		}
		
		this._target = make_shared(srfc, (SDL_Surface* ptr) => SDL_FreeSurface(ptr));
		this._filename = filename;
	}
	
	/**
	 * Load from memory.
	 */
	void loadFromMemory(void* memory, ushort width, ushort height, ubyte depth = 32) in {
		assert(memory !is null, "Memory is empty.");
		assert(depth >= 8 && depth <= 32, "Invalid depth.");
	} body {
		SDL_Surface* srfc = SDL_CreateRGBSurfaceFrom(memory, width, height, depth,
		                                             (depth / 8) * width,
		                                             RMask, GMask, BMask, AMask);
		
		if (srfc is null) {
			const string err = to!string(SDL_GetError());
			throw new Exception("Could not load image. Error: " ~ err);
		}
		
		this._target = make_shared(srfc, (SDL_Surface* ptr) => SDL_FreeSurface(ptr));
	}
	
	/**
	 * Save the current pixel data to the file.
	 */
	void saveToFile(string filename) {
		enforce(filename.length >= 4, "File name is too short.");
		
		if (SDL_SaveBMP(this.ptr, toStringz(filename)) != 0) {
			const string err = to!string(SDL_GetError());
			throw new Exception(.format("Could not save image %s. Error: %s.", filename, err));
		}
	}
	
	/**
	 * Fills a specific area of the surface with the given color.
	 * The second parameter is a pointer to the area.
	 * If it's null, the whole Surface is filled.
	 */
	void fill(ref const Color col, const ShortRect* rect = null) {
		SDL_Rect a = void;
		const SDL_Rect* ptr = transfer(rect, &a);

		const uint key = SDL_MapRGBA(this._target.format, col.red, col.green, col.blue, col.alpha);
		
		SDL_FillRect(this._target, ptr, key);
	}
	
	/**
	 * Rvalue version
	 */
	void fill(const Color col, const ShortRect* rect = null) {
		this.fill(col, rect);
	}
	
	/**
	 * Fills multiple areas of the Surface with the given color.
	 */
	void fillAreas(ref const Color col, const ShortRect[] rects) {
		SDL_Rect a = void;
		const SDL_Rect* ptr_start = (rects.length > 0) ? transfer(&rects[0], &a) : null;
		const uint key = SDL_MapRGBA(this._target.format, col.red, col.green, col.blue, col.alpha);
		
		SDL_FillRects(this._target, ptr_start, cast(uint) rects.length, key);
	}
	
	/**
	 * Rvalue version
	 */
	void fillAreas(const Color col, const ShortRect[] rects) {
		this.fillAreas(col, rects);
	}
	
	/**
	 * Use this function to set the RLE acceleration hint for a surface.
	 * RLE (Run-Length-Encoding) is a way of compressing data.
	 * If RLE is enabled, color key and alpha blending blits are much faster, 
	 * but the surface must be locked before directly accessing the pixels.
	 *
	 * Returns: whether the call succeeded or not
	 */
	bool optimizeRLE(bool enable) {
		return SDL_SetSurfaceRLE(this._target, enable) == 0;
	}
	
	/**
	 * Use this function to set up a surface for directly accessing the pixels.
	 *
	 * Returns: whether the call succeeded or not
	 */
	bool lock() {
		if (SDL_LockSurface(this._target) == 0)
			return true;
		return false;
	}
	
	/**
	 * Use this function to release a surface after directly accessing the pixels.
	 */
	void unlock() {
		SDL_UnlockSurface(this._target);
	}
	
	/**
	 * Returns whether this Surface is locked or not.
	 */
	bool isLocked() const pure nothrow {
		return this._target.locked != 0;
	}
	
	/**
	 * Use this function to determine whether a surface must be locked for access.
	 */
	bool mustLock() {
		return SDL_MUSTLOCK(this._target) == SDL_TRUE;
	}
	
	/**
	 * Use this function to adapt the format of another Surface to this surface.
	 * Works like <code>SDL_DisplayFormat</code>.
	 */
	void adaptTo(ref Surface srfc) in {
		assert(srfc.isValid(), "Could not adapt to invalid surface.");
		assert(this.isValid(), "Could not adapt a invalid surface.");
	} body {
		this.adaptTo(srfc.ptr.format);
	}
	
	/**
	 * Use this function to adapt the format of another Surface to this surface.
	 * Works like <code>SLD_DisplayFormat</code>.
	 */
	void adaptTo(SDL_PixelFormat* fmt) in {
		assert(fmt !is null, "Null format is invalid.");
	} body {
		SDL_Surface* adapted = SDL_ConvertSurface(this._target, fmt, 0);
		enforce(adapted !is null, "Could not adapt surface.");
		
		this._target = make_shared(adapted, (SDL_Surface* ptr) => SDL_FreeSurface(ptr));
	}
	
	/**
	 * Set the colorkey.
	 */
	void setColorkey(ref const Color col) {
		this.setColorkey(col.red, col.green, col.blue, col.alpha);
	}
	
	/**
	 * Rvalue version
	 */
	void setColorkey(const Color col) {
		this.setColorkey(col);
	}
	
	/**
	 * Set the colorkey.
	 */
	void setColorkey(ubyte red, ubyte green, ubyte blue) {
		const uint key = SDL_MapRGB(this._target.format, red, green, blue);
		SDL_SetColorKey(this._target, SDL_TRUE, key);
	}
	
	/**
	 * Set the colorkey.
	 */
	void setColorkey(ubyte red, ubyte green, ubyte blue, ubyte alpha) {
		const uint key = SDL_MapRGBA(this._target.format, red, green, blue, alpha);
		SDL_SetColorKey(this._target, SDL_TRUE, key);
	}
	
	/**
	 * Returns the current colorkey.
	 */
	Color getColorkey() {
		uint key = 0;
		SDL_GetColorKey(this._target, &key);
		
		ubyte r, g, b, a;
		SDL_GetRGBA(key, this._target.format, &r, &g, &b, &a);
		
		return Color(r, g, b, a);
	}
	
	/**
	 * Set the Alpha mod.
	 */
	void setAlphaMod(ubyte alpha) {
		SDL_SetSurfaceAlphaMod(this._target, alpha);
	}
	
	/**
	 * Returns the current Alpha mod.
	 */
	ubyte getAlphaMod() {
		ubyte alpha;
		SDL_GetSurfaceAlphaMod(this._target, &alpha);
		
		return alpha;
	}
	
	/**
	 * Set the Blendmode.
	 */
	void setBlendMode(BlendMode mode) {
		SDL_SetSurfaceBlendMode(this._target, mode);
	}
	
	/**
	 * Returns the current Blendmode.
	 */
	BlendMode getBlendMode() {
		SDL_BlendMode mode;
		SDL_GetSurfaceBlendMode(this._target, &mode);
		
		return cast(BlendMode) mode;
	}
	
	/**
	 * Returns the clip rect of this surface.
	 * The clip rect is the area of the surface which is drawn.
	 */
	ShortRect getClipRect() {
		SDL_Rect clip = void;
		SDL_GetClipRect(this._target, &clip);

		return ShortRect(clip);
	}
	
	/**
	 * Set the clip rect.
	 */
	void setClipRect(ref const ShortRect clip) {
		SDL_Rect a = void;
		clip.transferTo(&a);

		SDL_SetClipRect(this._target, &a);
	}
	
	/**
	 * Rvalue version
	 */
	void setClipRect(const ShortRect clip) {
		this.setClipRect(clip);
	}
	
	@property {
		/**
		 * Returns the current filename, if any
		 */
		string filename() const pure nothrow {
			return this._filename;
		}
		
		/**
		 * Returns the width.
		 */
		ushort width() const pure nothrow {
			return this._target.isValid() ? cast(ushort) this._target.w : 0;
		}
		
		/**
		 * Returns the height.
		 */
		ushort height() const pure nothrow {
			return this._target.isValid() ? cast(ushort) this._target.h : 0;
		}
		
		/**
		 * Returns the pixel data of this surface.
		 */
		inout(void*) pixels() inout {
			return this._target.isValid() ? this._target.pixels : null;
		}
		
		/**
		 * Count the bits of this surface.
		 * Could be 32, 24, 16, 8, 0.
		 */
		ubyte bits() const pure nothrow {
			return this._target.isValid() ? this._target.format.BitsPerPixel : 0;
		}
		
		/**
		 * Count the bytes of this surface.
		 * Could be 4, 3, 2, 1, 0. (countBits / 8)
		 */
		ubyte bytes() const pure nothrow {
			return this._target.isValid() ? this._target.format.BytesPerPixel : 0;
		}
		
		/**
		 * Returns the Surface pitch or 0.
		 */
		int pitch() const pure nothrow {
			return this._target.isValid() ? this._target.pitch : 0;
		}
		
		/**
		 * Returns the PixelFormat
		 */
		const(SDL_PixelFormat*) pixelFormat() const pure nothrow {
			return this._target.format;
		}
	}
	
	/**
	 * Returns if the given color match the color of the given mask of the surface.
	 *
	 * See: Surface.Mask enum.
	 */
	bool isMask(Mask mask, ref const Color col) const {
		const uint map = SDL_MapRGBA(this._target.format, col.red, col.green, col.blue, col.alpha);
		
		return this.isMask(mask, map);
	}
	
	/**
	 * Rvalue version
	 */
	bool isMask(Mask mask, const Color col) const {
		return this.isMask(mask, col);
	}
	
	/**
	 * Returns if the given converted color match the color of the given mask of the surface.
	 *
	 * See: Surface.Mask enum.
	 */
	bool isMask(Mask mask, uint col) const pure nothrow {
		bool[4] result = void;
		ubyte index = 0;
		
		if (mask & Mask.Red)
			result[index++] = this._target.format.Rmask == col;
		if (mask & Mask.Green)
			result[index++] = this._target.format.Gmask == col;
		if (mask & Mask.Blue)
			result[index++] = this._target.format.Bmask == col;
		if (mask & Mask.Alpha)
			result[index++] = this._target.format.Amask == col;
		
		for (ubyte i = 0; i < index; ++i) {
			if (!result[i])
				return false;
		}
		
		return true;
	}
	
	/**
	 * Returns the pixel at the given coordinates.
	 */
	uint getPixelAt(ref const Vector2s pos) const {
		return this.getPixelAt(pos.x, pos.y);
	}
	
	/**
	 * Returns the pixel at the given coordinates.
	 */
	uint getPixelAt(ushort x, ushort y) const {
		uint* pixels = cast(uint*) this.pixels;
		enforce(pixels !is null, "No pixel at this point.");
		
		return pixels[(y * this._target.w) + x];
	}
	
	/**
	 * Put a new pixel at the given coordinates.
	 */
	void putPixelAt(ref const Vector2s pos, uint pixel) {
		this.putPixelAt(pos.x, pos.y, pixel);
	}
	
	/**
	 * Put a new pixel at the given coordinates.
	 */
	void putPixelAt(ushort x, ushort y, uint pixel) {
		uint* pixels = cast(uint*) this.pixels;
		enforce(pixels !is null, "No pixel at this point.");
		
		pixels[(y * this._target.w) + x] = pixel;
	}
	
	/**
	 * Returns the color on the given position.
	 */
	Color getColorAt(ref const Vector2s pos) const {
		return this.getColorAt(pos.x, pos.y);
	}
	
	/**
	 * Returns the color on the given position.
	 */
	Color getColorAt(ushort x, ushort y) const {
		const uint len = this.width * this.height;
		
		if ((x * y) <= len) {
			const uint pixel = this.getPixelAt(x, y);
			
			ubyte r, g, b, a;
			SDL_GetRGBA(pixel, this._target.format, &r, &g, &b, &a);
			
			return Color(r, g, b, a);
		}
		
		enforce(len != 0, "Invalid Surface for getColorAt.");
		
		throw new Exception("No color at this position.");
	}
	
	/**
	 * Returns a pointer to the SDL_Surface
	 */
	@property
	inout(SDL_Surface)* ptr() inout pure nothrow {
		return this._target.ptr;
	}
	
	/**
	 * Use this function to perform a fast, low quality,
	 * stretch blit between two surfaces of the same pixel format.
	 * src is the a pointer to a Rect structure which represents the rectangle to be copied, 
	 * or null to copy the entire surface.
	 * dst is a pointer to a Rect structure which represents the rectangle that is copied into.
	 * null means, that the whole srfc is copied to (0|0).
	 */
	bool blitScaled(ref Surface srfc, const ShortRect* src = null, ShortRect* dst = null) {
		return this.blitScaled(srfc.ptr, src, dst);
	}
	
	/**
	 * Same as above, but with a SDL_Surface* instead of a Surface.
	 */
	bool blitScaled(SDL_Surface* srfc, const ShortRect* src = null, ShortRect* dst = null) in {
		assert(srfc !is null, "Null surface cannot be blit.");
	} body {
		SDL_Rect a = void;
		SDL_Rect b = void;

		const SDL_Rect* src_ptr = transfer(src, &a);
		SDL_Rect* dst_ptr = transfer(dst, &b);
		
		return SDL_BlitScaled(srfc, src_ptr, this._target, dst_ptr) == 0;
	}
	
	/**
	 * Use this function to perform low-level surface blitting only.
	 */
	bool lowerBlit(ref Surface srfc, ShortRect* src = null, ShortRect* dst = null) {
		return this.lowerBlit(srfc.ptr, src, dst);
	}
	
	/**
	 * Same as above, but with a SDL_Surface* instead of a Surface.
	 */
	bool lowerBlit(SDL_Surface* srfc, ShortRect* src = null, ShortRect* dst = null) in {
		assert(srfc !is null, "Null surface cannot be blit.");
	} body {
		SDL_Rect a = void;
		SDL_Rect b = void;

		SDL_Rect* src_ptr = transfer(src, &a);
		SDL_Rect* dst_ptr = transfer(dst, &b);
		
		return SDL_LowerBlit(srfc, src_ptr, this._target, dst_ptr) == 0;
	}
	
	/**
	 * Use this function to perform a fast blit from the source surface to the this surface.
	 * src is the a pointer to a Rect structure which represents the rectangle to be copied, 
	 * or null to copy the entire surface.
	 * dst is a pointer to a Rect structure which represents the rectangle that is copied into.
	 * null means, that the whole srfc is copied to (0|0).
	 */
	bool blit(ref Surface srfc, const ShortRect* src = null, ShortRect* dst = null) {
		return this.blit(srfc.ptr, src, dst);
	}
	
	/**
	 * Same as above, but with a SDL_Surface* instead of a Surface.
	 */
	bool blit(SDL_Surface* srfc, const ShortRect* src = null, ShortRect* dst = null) in {
		assert(srfc !is null, "Null surface cannot be blit.");
	} body {
		SDL_Rect a = void;
		SDL_Rect b = void;

		const SDL_Rect* src_ptr = transfer(src, &a);
		SDL_Rect* dst_ptr = transfer(dst, &b);
		
		return SDL_BlitSurface(srfc, src_ptr, this._target, dst_ptr) == 0;
	}
	
	/**
	 * Returns a subsurface from this surface. rect represents the viewport.
	 * The subsurface is a separate Surface object.
	 */
	Surface subSurface(ref const ShortRect rect) {
		SDL_Surface* sub = this.create(rect.width, rect.height);
		enforce(sub !is null, "Failed to construct a sub surface.");

		SDL_Rect clip = void;
		rect.transferTo(&clip);

		if (SDL_BlitSurface(this._target, &clip, sub, null) != 0)
			throw new Exception("An error occured by blitting the subsurface.");
		
		return Surface(sub);
	}
	
	/**
	 * Rvalue version
	 */
	Surface subSurface(const ShortRect rect) {
		return this.subSurface(rect);
	}
	
	/**
	 * Returns an new flipped Surface
	 * The current Surface is not modified.
	 *
	 * Note: This function may be slow
	 */
	Surface flip(Flip flip) {
		ubyte* pixels = cast(ubyte*) this.pixels;
		
		const ubyte bytes = this.bytes;
		const uint memSize = this.width * this.height * bytes;
		
		Surface flipped = Surface.make(this.width, this.height);
		ubyte* newPixels = cast(ubyte*) flipped.pixels;
		
		final switch (flip) {
			case Flip.Vertical:
				const uint rowSize = this.width * bytes;
				
				ubyte* source = &pixels[this.width * (this.height - 1) * bytes];
				ubyte* dest = &newPixels[0];
				
				for (ushort y = 0; y < this.height; ++y) {
					.memcpy(dest, source, rowSize);
					//std.algorithm.reverse(dest[0 .. rowSize]);
					source -= rowSize;
					dest += rowSize;
				}
				break;
			case Flip.Horizontal:
				for (ushort y = 0; y < this.height; ++y) {
					ubyte* source = &pixels[y * this.width * bytes];
					ubyte* dest = &newPixels[(y + 1) * this.width * bytes - bytes];
					
					for (ushort x = 0; x < this.width; ++x) {
						dest[0] = source[0];
						dest[1] = source[1];
						dest[2] = source[2];
						if (bytes == 4)
							dest[3] = source[3];
						
						source += bytes;
						dest -= bytes;
					}
				}
				break;
			case Flip.Vertical | Flip.Horizontal:
				newPixels[0 .. memSize] = pixels[0 .. memSize];
				.reverse(newPixels[0 .. memSize]);
				break;
		}
		
		return flipped;
	}
} unittest {
	writeln("<Surface unittest>");
	
	Surface s1 = Surface.make(64, 64, 32);
	
	assert(s1.useCount() == 1, to!string(s1.useCount()));
	{
		Surface s2 = s1;
		
		assert(s1.useCount() == 2, to!string(s1.useCount()));
		assert(s2.useCount() == 2, to!string(s2.useCount()));
		
		s2 = s1;
		
		assert(s1.useCount() == 2, to!string(s1.useCount()));
		assert(s2.useCount() == 2, to!string(s2.useCount()));
		
		{
			Surface s3 = s2;
			
			assert(s1.useCount() == 3, to!string(s1.useCount()));
			assert(s2.useCount() == 3, to!string(s2.useCount()));
			assert(s3.useCount() == 3, to!string(s3.useCount()));
		}
		
		assert(s1.useCount() == 2, to!string(s1.useCount()));
		assert(s2.useCount() == 2, to!string(s2.useCount()));
	}
	assert(s1.useCount() == 1, to!string(s1.useCount()));
	
	writeln("</Surface unittest>");
}