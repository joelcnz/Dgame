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
module Dgame.Window.Event;

private import derelict.sdl2.types;

public {
	import Dgame.System.Keyboard;
	import Dgame.System.Mouse;
}

/**
 * Specific Window Events.
 */
enum WindowEventId : ubyte {
	None,           /** Nothing happens */
	Shown,          /** Window has been shown */
	Hidden,         /** Window has been hidden */
	Exposed,        /** Window has been exposed and should be redrawn */
	Moved,          /** Window has been moved to data1, data2  */
	Resized,        /** Window has been resized to data1Xdata2 */
	SizeChanged,    /** The window size has changed, 
	                 * either as a result of an API call or through 
	                 * the system or user changing the window size. */
	Minimized,      /** Window has been minimized. */
	Maximized,      /** Window has been maximized. */
	Restored,       /** Window has been restored to normal size and position. */
	Enter,          /** Window has gained mouse focus. */
	Leave,          /** Window has lost mouse focus. */
	FocusGained,    /** Window has gained keyboard focus. */
	FocusLost,      /** Window has lost keyboard focus. */
	Close           /** The window manager requests that the window be closed. */
}

enum TextSize = 32;

/**
 * The Event structure.
 * Event defines a system event and it's parameters
 *
 * Author: rschuett
 */
struct Event {
	/**
	 * All supported Event Types.
	 */
	enum Type {
		Quit = SDL_QUIT,			/** Quit Event. Time to close the window. */
		Window  = SDL_WINDOWEVENT,	/** Something happens with the window. */
		KeyDown = SDL_KEYDOWN,		/** A key is pressed. */
		KeyUp = SDL_KEYUP,		/** A key is released. */
		MouseMotion = SDL_MOUSEMOTION,	/** The mouse has moved. */
		MouseButtonDown = SDL_MOUSEBUTTONDOWN,	/** A mouse button is pressed. */
		MouseButtonUp = SDL_MOUSEBUTTONUP,	/** A mouse button is released. */
		MouseWheel = SDL_MOUSEWHEEL,		/** The mouse wheel has scolled. */
		TextEdit   = SDL_TEXTEDITING,            /**< Keyboard text editing (composition) */
		TextInput  = SDL_TEXTINPUT              /**< Keyboard text input */
	}
	
	Type type; /** The Event Type. */
	
	uint timestamp; /** Milliseconds since the app is running. */
	uint windowId;   /** The window which has raised this event. */
	
	/**
	 * The Keyboard Event structure.
	 */
	static struct KeyboardEvent {
		Keyboard.State state;	/** Keyboard State. See: Dgame.Input.Keyboard. */
		Keyboard.Code code;	/** The Key which is released or pressed. */
		Keyboard.ScanCode scancode;	/** The Key which is released or pressed. */
		Keyboard.Mod mod;	/** The Key modifier. */
		
		alias key = code; /** An alias */
		
		bool repeat;	/** true, if this is a key repeat. */
	}
	
	/**
	 * Keyboard text editing event structure
	 */
	static struct TextEditEvent {
		char[TextSize] text = void; /**< The editing text */
		short start; /**< The start cursor of selected editing text */
		ushort length; /**< The length of selected editing text */
	}
	
	/**
	 * Keyboard text input event structure
	 */
	static struct TextInputEvent {
		char[TextSize] text = void; /**< The input text */
	}
	
	/**
	 * The Window Event structure.
	 */
	static struct WindowEvent {
		WindowEventId eventId; /** < The Window Event id. */
	}
	
	/**
	 * The Mouse button Event structure.
	 */
	static struct MouseButtonEvent {
		Mouse.Button button; /** The mouse button which is pressed or released. */
		
		short x; /** Current x position. */
		short y; /** Current y position. */
	}
	
	/**
	 * The Mouse motion Event structure.
	 */
	static struct MouseMotionEvent {
		Mouse.State state; /** Mouse State. See: Dgame.Input.Mouse. */
		
		short x; /** Current x position. */
		short y; /** Current y position. */
		
		short rel_x; /** Relative motion in the x direction. */
		short rel_y; /** Relative motion in the y direction. */
	}
	
	/**
	 * The Mouse wheel Event structure.
	 */
	static struct MouseWheelEvent {
		short x; /** Current x position. */
		short y; /** Current y position. */
		
		short delta_x; /** The amount scrolled horizontally. */
		short delta_y; /** The amount scrolled vertically. */
	}
	
	union {
		KeyboardEvent keyboard; /** Keyboard Event. */
		WindowEvent	  window;	/** Window Event. */
		MouseButtonEvent mouseButton; /** Mouse button Event. */
		MouseMotionEvent mouseMotion; /** Mouse motion Event. */
		MouseWheelEvent  mouseWheel;  /** Mouse wheel Event. */
		TextEditEvent	 textEdit;	  /** Text edit Event. */
		TextInputEvent	 textInput;	  /** Text input Event. */
	}
}