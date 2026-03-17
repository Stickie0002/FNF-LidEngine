package options;

class CheatsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Cheats (if you want)';
		rpcTitle = 'Cheats (if you want)'; //for Discord Rich Presence

		// --- ALWAYS PERFECT RANK ---
		var option:Option = new Option(
			'Always Perfect Rank', // Name in menu
			"If checked, you'll always have a 100% Perfect score. (LID ENGINE EXCLUSIVE)", // Description
			'alwaysPerfect', // Variable in ClientPrefs
			'bool' // Type of option
		);
		addOption(option);

		var option:Option = new Option(
    'God Mode',
    "You literally cannot die. Boyfriend is immortal. (YOU CHEATER)",
    'godMode',
    'bool'
);
addOption(option);

		super();
	}

	function onChangeHitsoundVolume()
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);

	function onChangeAutoPause()
		FlxG.autoPause = ClientPrefs.data.autoPause;
}