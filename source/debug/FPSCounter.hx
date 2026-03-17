package debug;

import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
class FPSCounter extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	/**
		The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Float;

	@:noCompletion private var times:Array<Float>;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 14, color);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		times = [];
	}

	var deltaTimeout:Float = 0.0;

	// Event Handlers
	private override function __enterFrame(deltaTime:Float):Void
	{
		// prevents the overlay from updating every frame, why would you need to anyways
		if (deltaTimeout > 1000) {
			deltaTimeout = 0.0;
			return;
		}

		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000) times.shift();

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;		
		updateText();
		deltaTimeout += deltaTime;
	}

	public dynamic function updateText():Void {
        // 1. Create the full string
        var fpsPart:String = 'FPS: ${currentFPS}';
        var detailsPart:String = '\nMemory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}\nLID ENGINE [B1.0.3]';
        
        text = fpsPart + detailsPart;

        // 2. Define our formats
        var bigFormat = new TextFormat("_sans", 18, 0xFFFFFFFF, true); // Size 18, Bold
        var smallFormat = new TextFormat("_sans", 12, 0xFFFFFFFF, false); // Size 12, Normal

        // 3. Apply the big format ONLY to the FPS line
        setTextFormat(bigFormat, 0, fpsPart.length);

        // 4. Apply the small format to everything after the FPS line
        setTextFormat(smallFormat, fpsPart.length, text.length);

        // 5. Still keep the "Red for lag" logic, but only for the FPS part
        if (currentFPS < FlxG.drawFramerate * 0.5) {
            var redFormat = new TextFormat("_sans", 18, 0xFFFF0000, true);
            setTextFormat(redFormat, 0, fpsPart.length);
        }
    }

	inline function get_memoryMegas():Float
		return cast(System.totalMemory, UInt);
}
