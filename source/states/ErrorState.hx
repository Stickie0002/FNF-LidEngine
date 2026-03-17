package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class ErrorState extends FlxState
{
    var errorMessage:String;
    public function new(message:String)
    {
        super();
        this.errorMessage = message;
    }

    override public function create()
    {
        super.create();
        
        var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.6;
        add(bg);

        var title:FlxText = new FlxText(0, 100, FlxG.width, "LID ENGINE CRASHED!", 64);
        title.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(title);

        var errorTxt:FlxText = new FlxText(50, 250, FlxG.width - 100, errorMessage, 24);
        errorTxt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
        add(errorTxt);

        var tip:FlxText = new FlxText(0, FlxG.height - 100, FlxG.width, "Press ESCAPE to return to Main Menu", 32);
        tip.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(tip);
    }

    override public function update(elapsed:Float)
    {
        if (FlxG.keys.justPressed.ESCAPE)
            MusicBeatState.switchState(new MainMenuState());
        super.update(elapsed);
    }
}