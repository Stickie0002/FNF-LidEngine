package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class ResultsScreen extends MusicBeatState
{
	var score:Int = 0;
    var misses:Int = 0;
    var rating:String = '';
    var songName:String = '';
    var difficulty:String = '';

    public function new(score:Int, misses:Int, rating:String, songName:String, difficulty:String)
    {
        super();
        this.score = score;
        this.misses = misses;
        this.rating = rating;
        this.songName = songName;
        this.difficulty = difficulty;
    }

	override function create()
	{
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuBG'));
		bg.color = 0xFF222222; // Darken the background
		add(bg);

		// Calculate Rank based on rating name
		var rank:String = "F";
		if (rating == "Perfect!!") rank = "S+";
		else if (rating == "Sick!") rank = "S";
		else if (rating == "Great") rank = "A";
		else if (rating == "Good") rank = "B";
		else if (rating == "Meh") rank = "C";
		else if (rating == "Bruh") rank = "D";

		var titleText:FlxText = new FlxText(0, 40, FlxG.width, "SONG COMPLETED", 48);
		titleText.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
		add(titleText);

		var rankText:FlxText = new FlxText(0, 150, FlxG.width, rank, 120);
		rankText.setFormat(Paths.font("vcr.ttf"), 120, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(rankText);

		var stats:FlxText = new FlxText(0, 350, FlxG.width, 
			"SCORE: " + score + "\n" +
			"MISSES: " + misses + "\n" +
			"RATING: " + rating, 32);
		stats.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		add(stats);

		var continueText:FlxText = new FlxText(0, 620, FlxG.width, "Press ACCEPT to Continue", 24);
		continueText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
		add(continueText);

        var songText:FlxText = new FlxText(0, 90, FlxG.width, songName + " [" + difficulty.toUpperCase() + "]", 24);
        songText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(songText);

		super.create();
	}

	override function update(elapsed:Float)
	{
		if (controls.ACCEPT)
		{
			MusicBeatState.switchState(new states.FreeplayState());
		}
		super.update(elapsed);
	}
}