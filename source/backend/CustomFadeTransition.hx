package backend; // This fixes the 'package states.editors' error

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class CustomFadeTransition extends MusicBeatSubstate {
    public static var finishCallback:Void->Void;
    var isTransIn:Bool = false;
    var transBlack:FlxSprite;

    public function new(duration:Float, isTransIn:Bool) {
        super();
        this.isTransIn = isTransIn;

        // Create a black bar that is slightly taller than the screen for a clean sweep
        transBlack = new FlxSprite().makeGraphic(FlxG.width, FlxG.height + 400, FlxColor.BLACK);
        transBlack.scrollFactor.set();
        transBlack.screenCenter(X);
        add(transBlack);

        if(!isTransIn) {
            // SLIDE DOWN: Transitioning out of the current state
            transBlack.y = -transBlack.height;
            FlxTween.tween(transBlack, {y: 0}, duration, {
                ease: FlxEase.expoInOut,
                onComplete: function(twn:FlxTween) {
                    if(finishCallback != null) finishCallback();
                }
            });
        } else {
            // SLIDE DOWN FURTHER: Transitioning into the new state
            transBlack.y = 0;
            FlxTween.tween(transBlack, {y: transBlack.height}, duration, {
                ease: FlxEase.expoInOut,
                onComplete: function(twn:FlxTween) {
                    close();
                }
            });
        }
    }

    override function destroy() {
        if(finishCallback != null) finishCallback();
        super.destroy();
    }
}