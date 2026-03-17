package backend;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class CustomFadeTransition extends MusicBeatSubstate {
    public static var finishCallback:Void->Void;
    var isTransIn:Bool = false;
    var duration:Float = 0.6;
    var overlay:FlxSprite;

    public function new(duration:Float, isTransIn:Bool) {
        this.isTransIn = isTransIn;
        this.duration = duration;
        super();
    }

    override function create() {
        // Ensure this substate uses its own camera or stays on top
        var cam = FlxG.cameras.list[FlxG.cameras.list.length - 1];
        cameras = [cam];

        // 1. Create the Black Overlay
        overlay = new FlxSprite().makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
        overlay.screenCenter();
        overlay.scrollFactor.set(); // Stop the overlay from moving with the camera!
        add(overlay);

        if (isTransIn) {
            // TRANSITION IN (Revealing the state)
            overlay.alpha = 1;
            FlxG.camera.zoom = 5.0; // Start really zoomed in

            // Fade Out Alpha (1.0 -> 0.0)
            FlxTween.tween(overlay, {alpha: 0}, duration, {ease: FlxEase.expoOut});
            // Zoom Out Camera (5.0 -> 1.0)
            FlxTween.tween(FlxG.camera, {zoom: 1.0}, duration, {
                ease: FlxEase.expoOut,
                onComplete: function(twn:FlxTween) {
                    close();
                }
            });
        } else {
            // TRANSITION OUT (Covering the state)
            overlay.alpha = 0;
            FlxG.camera.zoom = 1.0; // Start at normal zoom

            // Fade In Alpha (0.0 -> 1.0)
            FlxTween.tween(overlay, {alpha: 1}, duration, {ease: FlxEase.expoIn});
            // Zoom In Camera (1.0 -> 5.0)
            FlxTween.tween(FlxG.camera, {zoom: 5.0}, duration, {
                ease: FlxEase.expoIn,
                onComplete: function(twn:FlxTween) {
                    if (finishCallback != null) finishCallback();
                }
            });
        }

        super.create();
    }
}