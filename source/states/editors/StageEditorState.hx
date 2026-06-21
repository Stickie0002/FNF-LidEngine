package states.editors;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import backend.Paths;
import backend.StageData;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import openfl.net.FileReference;
import openfl.net.FileFilter;
import openfl.events.Event;

// ── DATA FORMAT STRUCTS ───────────────────────────────────────────────────

typedef StageObject = {
	var name:String;
	var spr:FlxSprite;
	var imagePath:String;
	var defaultX:Float;
	var defaultY:Float;
	var defaultAngle:Float;
	var defaultScaleX:Float;
	var defaultScaleY:Float;
	var scrollX:Float;
	var scrollY:Float;
	var zIndex:Int;
	var danceEvery:Int;
	var animType:String;
	var isPixel:Bool;
}

typedef FullStageJson = {
	var name:String;
	var directory:String;
	var version:String;
	var cameraZoom:Float;
	var props:Array<PropJson>;
	var characters:CharacterSetupJson;
}

typedef PropJson = {
	var name:String;
	var assetPath:String;
	var position:Array<Float>;
	var scale:Array<Float>;
	var scroll:Array<Float>;
	var zIndex:Int;
	var danceEvery:Int;
	var animType:String;
	var isPixel:Bool;
	var animations:Array<Dynamic>;
}

typedef CharacterSetupJson = {
	var bf:CharacterDataJson;
	var dad:CharacterDataJson;
	var gf:CharacterDataJson;
}

typedef CharacterDataJson = {
	var position:Array<Float>;
	var cameraOffsets:Array<Float>;
	var zIndex:Int;
}

// ── EDITOR STATE ──────────────────────────────────────────────────────────

class StageEditorState extends MusicBeatState
{
	// ── CAMERAS ───────────────────────────────────────────────────────────────
	var camGame:FlxCamera;    // World/stage — scrolls and zooms
	var camUI:FlxCamera;      // HUD — never moves
	var camHandles:FlxCamera; // Outline + handles — never moves

	// ── STAGE OBJECTS ─────────────────────────────────────────────────────────
	var stageObjects:Array<StageObject> = [];
	var spriteGroup:FlxTypedGroup<FlxSprite>;

	// ── SELECTION ─────────────────────────────────────────────────────────────
	var selectedIndex:Int = -1;
	var outlineSprite:FlxSprite;

	// ── HANDLES ───────────────────────────────────────────────────────────────
	var handleSprites:Array<FlxSprite> = [];
	static inline var HANDLE_LEFT:Int        = 0;
	static inline var HANDLE_RIGHT:Int       = 1;
	static inline var HANDLE_UP:Int          = 2;
	static inline var HANDLE_DOWN:Int        = 3;
	static inline var HANDLE_TOPLEFT:Int     = 4;
	static inline var HANDLE_TOPRIGHT:Int    = 5;
	static inline var HANDLE_BOTTOMLEFT:Int  = 6;
	static inline var HANDLE_BOTTOMRIGHT:Int = 7;
	static inline var HANDLE_ROTATE:Int      = 8;

	// ── DRAG / RESIZE / ROTATE ────────────────────────────────────────────────
	var isDragging:Bool             = false;
	var activeHandle:Int            = -1;
	var dragOffsetX:Float           = 0;
	var dragOffsetY:Float           = 0;
	var resizeStartX:Float          = 0;
	var resizeStartY:Float          = 0;
	var resizeStartW:Float          = 0;
	var resizeStartH:Float          = 0;
	var resizeOrigX:Float           = 0;
	var resizeOrigY:Float           = 0;
	var rotateStartAngle:Float      = 0;
	var rotateStartMouseAngle:Float = 0;
	var rotateCenterX:Float         = 0;
	var rotateCenterY:Float         = 0;

	// ── TOPBAR MENU SYSTEM ────────────────────────────────────────────────────
	var topbarBg:FlxSprite;
	var topbarButtons:Array<FlxText> = [];
	var topbarMenuNames:Array<String> = ['File', 'Edit', 'Tools', 'Options', 'Help'];

	// ── IN-GAME HELP DIALOG MODAL ─────────────────────────────────────────────
	var helpDialogOpen:Bool = false;
	var helpGroup:FlxGroup;
	var helpBgDim:FlxSprite;
	var helpWindowBg:FlxSprite;
	var helpTitle:FlxText;
	var helpBody:FlxText;
	var helpCloseBtn:FlxText;

	// ── CUSTOM DROPDOWN (MOVED DOWN FOR TOPBAR) ────────────────────────────────
	var dropdownBg:FlxSprite;
	var dropdownLabel:FlxText;
	var dropdownOpen:Bool = false;
	var dropdownItems:Array<FlxText> = [];
	var dropdownItemBgs:Array<FlxSprite> = [];
	var dropdownGroup:FlxGroup;
	static inline var DD_X:Float   = 10;
	static inline var DD_Y:Float   = 38; 
	static inline var DD_W:Float   = 180;
	static inline var DD_H:Float   = 28;
	static inline var DD_IH:Float  = 24;

	// ── UI ────────────────────────────────────────────────────────────────────
	var statusText:FlxText;
	var infoText:FlxText;
	var uiGroup:FlxGroup;
	var uiHidden:Bool = false;

	// ── MISC ──────────────────────────────────────────────────────────────────
	var animPlaying:Bool        = false;
	var errorText:FlxText;
	var errorTimer:Float        = 0;
	var currentStageName:String = "";

	static var STAGES:Array<String> = [
		'stage','spooky','philly','limo',
		'mall','mallEvil','school','schoolEvil','tank'
	];
	static inline var DEFAULT_ZOOM:Float = 0.7;

	// ═════════════════════════════════════════════════════════════════════════
	//  CREATE
	// ═════════════════════════════════════════════════════════════════════════
	override function create()
	{
		super.create();
		FlxG.mouse.visible = true;

		camGame = new FlxCamera();
		camGame.bgColor = 0xFF1a1a2e;
		camGame.zoom = DEFAULT_ZOOM;

		camHandles = new FlxCamera();
		camHandles.bgColor.alpha = 0;

		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHandles, false);
		FlxG.cameras.add(camUI, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		FlxG.cameras.setDefaultDrawTarget(camHandles, false);
		FlxG.cameras.setDefaultDrawTarget(camUI, false);

		spriteGroup = new FlxTypedGroup<FlxSprite>();
		spriteGroup.cameras = [camGame];
		add(spriteGroup);

		outlineSprite = new FlxSprite();
		outlineSprite.cameras = [camHandles];
		outlineSprite.scrollFactor.set(0, 0);
		outlineSprite.visible = false;
		add(outlineSprite);

		var handleNames:Array<String> = [
			'left_handle','right_handle','up_handle','down_handle',
			'topLeft_handle','topRight_handle','bottomLeft_handle','bottomRight_handle',
			'rotate_handle'
		];
		var fallbackColors:Array<Int> = [
			0xFF00BFFF, 0xFF00BFFF, 0xFF00BFFF, 0xFF00BFFF,
			0xFF00FF88, 0xFF00FF88, 0xFF00FF88, 0xFF00FF88,
			0xFFFF6600
		];
		for (i in 0...handleNames.length) {
			var h = new FlxSprite();
			try { h.loadGraphic(Paths.image('stageditor/' + handleNames[i])); }
			catch(e:Dynamic) { h.makeGraphic(16, 16, fallbackColors[i]); }
			h.cameras = [camHandles];
			h.scrollFactor.set(0, 0);
			h.visible = false;
			handleSprites.push(h);
			add(h);
		}

		buildUI();
		buildHelpDialog();
		loadStage('stage');
	}

	function buildUI()
	{
		uiGroup = new FlxGroup();
		add(uiGroup);

		topbarBg = new FlxSprite(0, 0);
		topbarBg.makeGraphic(FlxG.width, 30, 0xFF0B0B14);
		topbarBg.cameras = [camUI];
		topbarBg.scrollFactor.set(0, 0);
		uiGroup.add(topbarBg);

		var currentX:Float = 15;
		for (i in 0...topbarMenuNames.length) {
			var btn = new FlxText(currentX, 6, 0, topbarMenuNames[i], 12);
			btn.setFormat(Paths.font("vcr.ttf"), 13, 0xFFCCCCCC, LEFT);
			btn.cameras = [camUI];
			btn.scrollFactor.set(0, 0);
			topbarButtons.push(btn);
			uiGroup.add(btn);
			currentX += btn.fieldWidth + 25; 
		}

		dropdownBg = new FlxSprite(DD_X, DD_Y);
		dropdownBg.makeGraphic(Std.int(DD_W), Std.int(DD_H), 0xFF333355);
		dropdownBg.cameras = [camUI];
		dropdownBg.scrollFactor.set(0, 0);
		uiGroup.add(dropdownBg);

		dropdownLabel = new FlxText(DD_X + 6, DD_Y + 5, DD_W - 12, "Stage: stage  v", 12);
		dropdownLabel.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, LEFT);
		dropdownLabel.cameras = [camUI];
		dropdownLabel.scrollFactor.set(0, 0);
		uiGroup.add(dropdownLabel);

		dropdownGroup = new FlxGroup();
		for (i in 0...STAGES.length) {
			var bg = new FlxSprite(DD_X, DD_Y + DD_H + i * DD_IH);
			bg.makeGraphic(Std.int(DD_W), Std.int(DD_IH), i % 2 == 0 ? 0xFF2b2b44 : 0xFF232338);
			bg.cameras = [camUI];
			bg.scrollFactor.set(0, 0);
			bg.visible = false;
			dropdownItemBgs.push(bg);
			dropdownGroup.add(bg);

			var txt = new FlxText(DD_X + 6, DD_Y + DD_H + i * DD_IH + 4, DD_W - 12, STAGES[i], 11);
			txt.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.fromRGB(190, 210, 255), LEFT);
			txt.cameras = [camUI];
			txt.scrollFactor.set(0, 0);
			txt.visible = false;
			dropdownItems.push(txt);
			dropdownGroup.add(txt);
		}
		uiGroup.add(dropdownGroup);

		statusText = new FlxText(10, FlxG.height - 22, 700, "", 11);
		statusText.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		statusText.cameras = [camUI];
		statusText.scrollFactor.set(0, 0);
		uiGroup.add(statusText);

		infoText = new FlxText(0, 36, FlxG.width - 10, "", 11);
		infoText.setFormat(Paths.font("vcr.ttf"), 11, FlxColor.fromRGB(200, 200, 200), RIGHT, OUTLINE, FlxColor.BLACK);
		infoText.cameras = [camUI];
		infoText.scrollFactor.set(0, 0);
		uiGroup.add(infoText);

		errorText = new FlxText(10, FlxG.height - 44, FlxG.width - 20, "", 13);
		errorText.setFormat(Paths.font("vcr.ttf"), 13, FlxColor.YELLOW, LEFT, OUTLINE, FlxColor.BLACK);
		errorText.cameras = [camUI];
		errorText.scrollFactor.set(0, 0);
		errorText.visible = false;
		add(errorText);
	}

	function buildHelpDialog()
	{
		helpGroup = new FlxGroup();
		add(helpGroup);

		helpBgDim = new FlxSprite(0, 0);
		helpBgDim.makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		helpBgDim.cameras = [camUI];
		helpBgDim.scrollFactor.set(0, 0);
		helpGroup.add(helpBgDim);

		var w:Int = 640;
		var h:Int = 480;
		helpWindowBg = new FlxSprite((FlxG.width - w) / 2, (FlxG.height - h) / 2);
		helpWindowBg.makeGraphic(w, h, 0xFF141424);
		helpWindowBg.cameras = [camUI];
		helpWindowBg.scrollFactor.set(0, 0);
		helpGroup.add(helpWindowBg);

		var innerBorder = new FlxSprite(helpWindowBg.x + 4, helpWindowBg.y + 4);
		innerBorder.makeGraphic(w - 8, h - 8, 0x00000000);
		drawHollowRect(innerBorder, w - 8, h - 8, 0xFF3A3A5A, 2);
		innerBorder.cameras = [camUI];
		helpGroup.add(innerBorder);

		helpTitle = new FlxText(helpWindowBg.x, helpWindowBg.y + 16, w, "LID ENGINE STAGE EDITOR COMMANDS", 16);
		helpTitle.setFormat(Paths.font("vcr.ttf"), 16, 0xFFFFCC00, CENTER, OUTLINE, FlxColor.BLACK);
		helpTitle.cameras = [camUI];
		helpGroup.add(helpTitle);

		var helpTxt:String = 
			"CAMERA CONTROL:\n" +
			"  I / J / K / L         - Pan Stage Camera View\n" +
			"  Q / E or Mouse Wheel  - Zoom Stage In / Out\n" +
			"  Ctrl + R              - Reset Camera to Center/Default\n" +
			"  F                     - Snap Camera Focus to Selected Asset\n\n" +
			"SELECTION & TRANSFORM:\n" +
			"  Left Mouse Click      - Select Sprite / Grab & Adjust Transform Handles\n" +
			"  Tab                   - Cycle Active Selection Through Assets Forward\n" +
			"  Ctrl + A              - Auto-Select Final Asset Index\n" +
			"  Ctrl + D              - Clear Active Selection Status\n" +
			"  Alt + R               - Reset Selected Object Back to JSON Default\n" +
			"  Delete / Backspace    - Permanently Delete Selected Asset\n\n" +
			"LAYERS & TESTING:\n" +
			"  [ / ] (Brackets)      - Reorder Object Layers (Z-Index Hierarchy Swap)\n" +
			"  Spacebar              - Play/Pause Animation Framerate Trackers\n\n" +
			"FILE IO CONFIG:\n" +
			"  Ctrl + S              - Export & Save Custom Stage Data JSON\n" +
			"  Ctrl + O              - Load Stage File via Native Browser Dialog\n" +
			"  Ctrl + N              - Inject New Asset File Path onto Stage Map\n" +
			"  Ctrl + H              - Toggle Whole Layout Interface Visibility";

		helpBody = new FlxText(helpWindowBg.x + 30, helpWindowBg.y + 55, w - 60, helpTxt, 12);
		helpBody.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, LEFT);
		
		var format = helpBody.textField.defaultTextFormat;
		format.leading = 3;
		helpBody.textField.defaultTextFormat = format;
		helpBody.textField.setTextFormat(format);
		helpBody.text = helpTxt; 

		helpBody.cameras = [camUI];
		helpGroup.add(helpBody);

		helpCloseBtn = new FlxText(helpWindowBg.x, helpWindowBg.y + h - 40, w, "[ CLICK ANYWHERE OR PRESS ESC TO CLOSE ]", 13);
		helpCloseBtn.setFormat(Paths.font("vcr.ttf"), 13, 0xFF8888BB, CENTER);
		helpCloseBtn.cameras = [camUI];
		helpGroup.add(helpCloseBtn);

		helpGroup.visible = false;
	}

	function screenToParallax(screenX:Float, screenY:Float, scrollFactorX:Float, scrollFactorY:Float):FlxPoint
	{
		var zoom = camGame.zoom;
		var px = ((screenX - (FlxG.width * 0.5) * (1 - zoom)) / zoom) + camGame.scroll.x * scrollFactorX;
		var py = ((screenY - (FlxG.height * 0.5) * (1 - zoom)) / zoom) + camGame.scroll.y * scrollFactorY;
		return FlxPoint.get(px, py);
	}

	override function update(elapsed:Float)
	{
		if (FlxG.keys.justPressed.ESCAPE) {
			if (helpDialogOpen) {
				closeHelpDialog();
			} else {
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new states.editors.MasterEditorMenu());
				return;
			}
		}

		super.update(elapsed);

		if (helpDialogOpen) {
			handleHelpDialogInput();
			return;
		}

		handleTopbarMenus();
		handleDropdown();
		handleCamera(elapsed);
		handleZoom();
		handleSelection();
		handleDragAndResize();
		handleKeybinds(elapsed);
		updateOverlay();
		updateStatusText();
		tickError(elapsed);
	}

	function handleTopbarMenus()
	{
		var mp = FlxG.mouse.getScreenPosition(camUI);
		
		for (i in 0...topbarButtons.length) {
			var btn = topbarButtons[i];
			var over = (mp.x >= btn.x && mp.x <= btn.x + btn.fieldWidth && mp.y >= btn.y && mp.y <= btn.y + btn.height);
			
			if (over) {
				btn.color = 0xFFFFCC00;
				if (FlxG.mouse.justPressed) {
					switch (topbarMenuNames[i]) {
						case 'Help':
							openHelpDialog();
						case 'File':
							openLegacyConverterDialog();
						case 'Edit':
							showError("Edit menu options under development!");
						case 'Tools':
							showError("Tools menu options under development!");
						case 'Options':
							showError("Options menu options under development!");
					}
				}
			} else {
				btn.color = 0xFFCCCCCC;
			}
		}
		mp.put();
	}

	function openHelpDialog()
	{
		helpDialogOpen = true;
		helpGroup.visible = true;
		outlineSprite.visible = false;
		for (h in handleSprites) h.visible = false;
	}

	function closeHelpDialog()
	{
		helpDialogOpen = false;
		helpGroup.visible = false;
	}

	function handleHelpDialogInput()
	{
		if (FlxG.mouse.justPressed) {
			closeHelpDialog();
		}
	}

	function handleDropdown()
	{
		if (!FlxG.mouse.justPressed) return;
		var mp = FlxG.mouse.getScreenPosition(camUI);
		var mx = mp.x;
		var my = mp.y;
		mp.put();

		if (mx >= DD_X && mx <= DD_X + DD_W && my >= DD_Y && my <= DD_Y + DD_H) {
			dropdownOpen = !dropdownOpen;
			for (i in 0...STAGES.length) {
				dropdownItems[i].visible   = dropdownOpen;
				dropdownItemBgs[i].visible = dropdownOpen;
			}
			return;
		}

		if (dropdownOpen) {
			for (i in 0...STAGES.length) {
				var iy = DD_Y + DD_H + i * DD_IH;
				if (mx >= DD_X && mx <= DD_X + DD_W && my >= iy && my <= iy + DD_IH) {
					loadStage(STAGES[i]);
					dropdownLabel.text = "Stage: " + STAGES[i] + "  v";
					closeDropdown();
					return;
				}
			}
			closeDropdown();
		}
	}

	function closeDropdown()
	{
		dropdownOpen = false;
		for (i in 0...STAGES.length) {
			dropdownItems[i].visible   = false;
			dropdownItemBgs[i].visible = false;
		}
	}

	function handleCamera(elapsed:Float)
	{
		var shift = FlxG.keys.pressed.SHIFT;
		var ctrl  = FlxG.keys.pressed.CONTROL;
		var speed = elapsed * 700;
		if (shift) speed *= 3.0;
		if (ctrl)  speed *= 0.1;

		if (FlxG.keys.pressed.I) camGame.scroll.y -= speed;
		if (FlxG.keys.pressed.K) camGame.scroll.y += speed;
		if (FlxG.keys.pressed.J) camGame.scroll.x -= speed;
		if (FlxG.keys.pressed.L) camGame.scroll.x += speed;
	}

	function handleZoom()
	{
		if (FlxG.mouse.wheel != 0)
			camGame.zoom = Math.max(0.1, Math.min(camGame.zoom + FlxG.mouse.wheel * 0.05, 8.0));
		if (FlxG.keys.justPressed.Q) camGame.zoom = Math.min(camGame.zoom + 0.1, 8.0);
		if (FlxG.keys.justPressed.E) camGame.zoom = Math.max(camGame.zoom - 0.1, 0.1);
	}

	function handleSelection()
	{
		if (!FlxG.mouse.justPressed) return;
		if (isOverDropdown() || isOverTopbar()) return;
		for (h in handleSprites)
			if (h.visible && FlxG.mouse.overlaps(h, camHandles)) return;
		
		var hit = -1;
		var i = stageObjects.length - 1;
		while (i >= 0) {
			if (FlxG.mouse.overlaps(stageObjects[i].spr, camGame)) { hit = i; break; }
			i--;
		}

		selectedIndex = hit;
		isDragging = false;

		if (selectedIndex >= 0) {
			var spr = stageObjects[selectedIndex].spr;
			var mouseScreen = FlxG.mouse.getScreenPosition(camUI);
			
			var parallaxPos = screenToParallax(mouseScreen.x, mouseScreen.y, spr.scrollFactor.x, spr.scrollFactor.y);
			dragOffsetX = parallaxPos.x - spr.x;
			dragOffsetY = parallaxPos.y - spr.y;
			
			parallaxPos.put();
			mouseScreen.put();
			isDragging = true;
		}
	}

	function handleDragAndResize()
	{
		if (FlxG.mouse.justPressed && selectedIndex >= 0) {
			activeHandle = -1;
			for (i in 0...handleSprites.length) {
				if (!handleSprites[i].visible) continue;
				if (!FlxG.mouse.overlaps(handleSprites[i], camHandles)) continue;
				
				activeHandle = i;
				isDragging   = false;
				
				var spr = stageObjects[selectedIndex].spr;
				var mouseScreen = FlxG.mouse.getScreenPosition(camUI);
				
				resizeStartX = mouseScreen.x;
				resizeStartY = mouseScreen.y;
				resizeStartW = spr.scale.x;
				resizeStartH = spr.scale.y;
				resizeOrigX  = spr.x;
				resizeOrigY  = spr.y;
				
				if (i == HANDLE_ROTATE) {
					var zoom = camGame.zoom;
					var sx = (spr.x - camGame.scroll.x * spr.scrollFactor.x) * zoom + (FlxG.width * 0.5) * (1 - zoom);
					var sy = (spr.y - camGame.scroll.y * spr.scrollFactor.y) * zoom + (FlxG.height * 0.5) * (1 - zoom);
					var sw = spr.width * zoom;
					var sh = spr.height * zoom;
					
					rotateCenterX = sx + sw * 0.5;
					rotateCenterY = sy + sh * 0.5;
					rotateStartAngle = spr.angle;
					rotateStartMouseAngle = Math.atan2(mouseScreen.y - rotateCenterY, mouseScreen.x - rotateCenterX) * (180 / Math.PI);
				}
				mouseScreen.put();
				break;
			}
		}

		if (FlxG.mouse.pressed && selectedIndex >= 0) {
			var spr = stageObjects[selectedIndex].spr;
			var mouseScreen = FlxG.mouse.getScreenPosition(camUI);
			var mx = mouseScreen.x;
			var my = mouseScreen.y;
			mouseScreen.put();

			if (activeHandle == -1 && isDragging) {
				var parallaxPos = screenToParallax(mx, my, spr.scrollFactor.x, spr.scrollFactor.y);
				spr.x = parallaxPos.x - dragOffsetX;
				spr.y = parallaxPos.y - dragOffsetY;
				parallaxPos.put();
				
			} else if (activeHandle == HANDLE_ROTATE) {
				var curAng = Math.atan2(my - rotateCenterY, mx - rotateCenterX) * (180 / Math.PI);
				spr.angle  = rotateStartAngle + (curAng - rotateStartMouseAngle);
				
			} else if (activeHandle >= 0) {
				var zoom = camGame.zoom;
				var dX = (mx - resizeStartX) / zoom;
				var dY = (my - resizeStartY) / zoom;
				
				var bW = spr.frameWidth  > 0 ? spr.frameWidth  : 1.0;
				var bH = spr.frameHeight > 0 ? spr.frameHeight : 1.0;
				
				switch (activeHandle) {
					case HANDLE_RIGHT:
						spr.scale.x = Math.max(0.05, resizeStartW + dX / bW);
					case HANDLE_LEFT:
						var ns = Math.max(0.05, resizeStartW - dX / bW);
						spr.x = resizeOrigX + (resizeStartW - ns) * bW;
						spr.scale.x = ns;
					case HANDLE_DOWN:
						spr.scale.y = Math.max(0.05, resizeStartH + dY / bH);
					case HANDLE_UP:
						var ns = Math.max(0.05, resizeStartH - dY / bH);
						spr.y = resizeOrigY + (resizeStartH - ns) * bH;
						spr.scale.y = ns;
					case HANDLE_TOPRIGHT:
						var ns = Math.max(0.05, resizeStartH - dY / bH);
						spr.y = resizeOrigY + (resizeStartH - ns) * bH;
						spr.scale.y = ns;
						spr.scale.x = Math.max(0.05, resizeStartW + dX / bW);
					case HANDLE_TOPLEFT:
						var nsY = Math.max(0.05, resizeStartH - dY / bH);
						spr.y = resizeOrigY + (resizeStartH - nsY) * bH;
						spr.scale.y = nsY;
						var nsX = Math.max(0.05, resizeStartW - dX / bW);
						spr.x = resizeOrigX + (resizeStartW - nsX) * bW;
						spr.scale.x = nsX;
					case HANDLE_BOTTOMRIGHT:
						spr.scale.x = Math.max(0.05, resizeStartW + dX / bW);
						spr.scale.y = Math.max(0.05, resizeStartH + dY / bH);
					case HANDLE_BOTTOMLEFT:
						var ns = Math.max(0.05, resizeStartW - dX / bW);
						spr.x = resizeOrigX + (resizeStartW - ns) * bW;
						spr.scale.x = ns;
						spr.scale.y = Math.max(0.05, resizeStartH + dY / bH);
				}
				spr.updateHitbox();
			}
		}

		if (FlxG.mouse.justReleased) {
			isDragging   = false;
			activeHandle = -1;
		}
	}

	function handleKeybinds(elapsed:Float)
	{
		var ctrl = FlxG.keys.pressed.CONTROL;
		var alt  = FlxG.keys.pressed.ALT;
		if (ctrl) {
			if (FlxG.keys.justPressed.S) saveStage();
			if (FlxG.keys.justPressed.O) openStageFileDialog();
			if (FlxG.keys.justPressed.D) { selectedIndex = -1; isDragging = false; }
			if (FlxG.keys.justPressed.A && stageObjects.length > 0) selectedIndex = stageObjects.length - 1;
			if (FlxG.keys.justPressed.R) resetCamera();
			if (FlxG.keys.justPressed.N) openNewObjectDialog();
			if (FlxG.keys.justPressed.H) toggleUI();
		}

		if (alt && FlxG.keys.justPressed.R) resetSelectedObject();

		if (FlxG.keys.justPressed.TAB && stageObjects.length > 0)
			selectedIndex = (selectedIndex + 1) % stageObjects.length;
		if ((FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE) && selectedIndex >= 0)
			deleteSelected();

		if (FlxG.keys.justPressed.LBRACKET && selectedIndex > 0) {
			swapObjects(selectedIndex, selectedIndex - 1);
			selectedIndex--;
		}
		if (FlxG.keys.justPressed.RBRACKET && selectedIndex >= 0 && selectedIndex < stageObjects.length - 1) {
			swapObjects(selectedIndex, selectedIndex + 1);
			selectedIndex++;
		}

		if (FlxG.keys.justPressed.SPACE) {
			animPlaying = !animPlaying;
			for (obj in stageObjects) {
				if (animPlaying && obj.spr.animation.curAnim != null)
					obj.spr.animation.play(obj.spr.animation.curAnim.name);
				else
					obj.spr.animation.pause();
			}
		}

		if (FlxG.keys.justPressed.F && selectedIndex >= 0) {
			var spr = stageObjects[selectedIndex].spr;
			camGame.scroll.x = spr.x + spr.width * 0.5 - FlxG.width * 0.5;
			camGame.scroll.y = spr.y + spr.height * 0.5 - FlxG.height * 0.5;
		}
	}

	function updateOverlay()
	{
		if (selectedIndex < 0 || selectedIndex >= stageObjects.length) {
			outlineSprite.visible = false;
			for (h in handleSprites) h.visible = false;
			return;
		}

		var spr  = stageObjects[selectedIndex].spr;
		var zoom = camGame.zoom;
		
		var sx = (spr.x - camGame.scroll.x * spr.scrollFactor.x) * zoom + (FlxG.width * 0.5) * (1 - zoom);
		var sy = (spr.y - camGame.scroll.y * spr.scrollFactor.y) * zoom + (FlxG.height * 0.5) * (1 - zoom);
		
		var sw = spr.width * zoom;
		var sh = spr.height * zoom;

		var PAD  = 3;
		var ow   = Std.int(sw) + PAD * 2;
		if (ow < PAD * 2) ow = PAD * 2;
		var oh   = Std.int(sh) + PAD * 2;
		if (oh < PAD * 2) oh = PAD * 2;
		if (Std.int(outlineSprite.width) != ow || Std.int(outlineSprite.height) != oh) {
			outlineSprite.makeGraphic(ow, oh, 0x00000000);
			drawHollowRect(outlineSprite, ow, oh, FlxColor.YELLOW, 3);
		}
		
		outlineSprite.offset.set(PAD, PAD);
		outlineSprite.setPosition(sx, sy);
		outlineSprite.origin.set(sw * 0.5 + PAD, sh * 0.5 + PAD);
		outlineSprite.angle = spr.angle;
		outlineSprite.visible = true;

		var cx  = sx + sw * 0.5;
		var cy  = sy + sh * 0.5;
		var P:Float = 6;
		var hx:Array<Float> = [
			sx - handleSprites[0].width - P,
			sx + sw + P,
			cx - handleSprites[2].width  * 0.5,
			cx - handleSprites[3].width  * 0.5,
			sx - handleSprites[4].width  - P,
			sx + sw + P,
			sx - handleSprites[6].width  - P,
			sx + sw + P,
			cx - handleSprites[8].width  * 0.5
		];
		var hy:Array<Float> = [
			cy - handleSprites[0].height * 0.5,
			cy - handleSprites[1].height * 0.5,
			sy - handleSprites[2].height - P,
			sy + sh + P,
			sy - handleSprites[4].height - P,
			sy - handleSprites[5].height - P,
			sy + sh + P,
			sy + sh + P,
			sy - handleSprites[8].height - P - 28
		];
		for (i in 0...handleSprites.length) {
			if (spr.angle != 0) {
				var rad = spr.angle * (Math.PI / 180);
				var dx = hx[i] + (handleSprites[i].width * 0.5) - cx;
				var dy = hy[i] + (handleSprites[i].height * 0.5) - cy;
				var rx = cx + (dx * Math.cos(rad) - dy * Math.sin(rad));
				var ry = cy + (dx * Math.sin(rad) + dy * Math.cos(rad));
				handleSprites[i].setPosition(rx - handleSprites[i].width * 0.5, ry - handleSprites[i].height * 0.5);
			} else {
				handleSprites[i].setPosition(hx[i], hy[i]);
			}
			handleSprites[i].visible = true;
		}
	}

	function drawHollowRect(target:FlxSprite, w:Int, h:Int, color:FlxColor, thickness:Int)
	{
		var bmd = target.pixels;
		if (bmd == null) return;
		for (x in 0...w) for (y in 0...h) {
			var edge = (x < thickness || x >= w - thickness || y < thickness || y >= h - thickness);
			bmd.setPixel32(x, y, edge ? color : 0x00000000);
		}
		target.pixels = bmd;
		target.dirty  = true;
	}

	function updateStatusText()
	{
		if (uiHidden) return;
		var cam = 'Cam:(${Std.int(camGame.scroll.x)}, ${Std.int(camGame.scroll.y)})  Zoom:${Math.round(camGame.zoom * 100)}%';
		var sel = selectedIndex >= 0
			? '  |  [${selectedIndex}]  x=${Std.int(stageObjects[selectedIndex].spr.x)}  y=${Std.int(stageObjects[selectedIndex].spr.y)}  rot=${Std.int(stageObjects[selectedIndex].spr.angle)}deg'
			: '  |  No selection';
		statusText.text = cam + sel;
		infoText.text   = 'Stage: ${currentStageName}   Objs: ${stageObjects.length}' +
			(animPlaying ? '  [ANIM]' : '') +
			(selectedIndex >= 0 ? '  |  ${stageObjects[selectedIndex].imagePath}' : '');
	}

	function openStageFileDialog()
	{
		try {
			var fr = new FileReference();
			fr.addEventListener(Event.SELECT, function(e:Event) {
				var nameNoExt = fr.name.split('.')[0];
				loadStage(nameNoExt);
				dropdownLabel.text = "Stage: " + nameNoExt + "  v";
			});
			fr.browse([new FileFilter("JSON Files", "*.json")]);
		} catch(e:Dynamic) {
			showError('File dialog error: $e');
		}
	}

	// ── AUTOMATED LEGACY PSYCH STAGE FORMAT CONVERTER WIZARD ──────────────────
	function openLegacyConverterDialog()
	{
		try {
			var fr = new FileReference();
			fr.addEventListener(Event.SELECT, function(e:Event) {
				fr.addEventListener(Event.COMPLETE, function(completeEvent:Event) {
					try {
						var rawLegacy:String = fr.data.toString();
						var legacy = Json.parse(rawLegacy);
						var stageName = fr.name.split('.')[0];
						
						var zoom:Float = (legacy.defaultZoom != null) ? legacy.defaultZoom : 0.9;
						var bfPos:Array<Float> = (legacy.boyfriend != null) ? legacy.boyfriend : [989.5, 885];
						var dadPos:Array<Float> = (legacy.opponent != null) ? legacy.opponent : [335, 885];
						var gfPos:Array<Float> = (legacy.girlfriend != null) ? legacy.girlfriend : [751.5, 787];
						var bfCam:Array<Float> = (legacy.camera_boyfriend != null) ? legacy.camera_boyfriend : [0, 0];
						var dadCam:Array<Float> = (legacy.camera_opponent != null) ? legacy.camera_opponent : [0, 0];
						var gfCam:Array<Float> = (legacy.camera_girlfriend != null) ? legacy.camera_girlfriend : [0, 0];
						var dir:String = (legacy.directory != null) ? legacy.directory : "shared";

						// DYNAMIC EXTRACTION: Check for alternative legacy array fields
						var parsedProps:Array<Dynamic> = [];
						if (legacy.props != null && Std.isOfType(legacy.props, Array)) {
							parsedProps = cast legacy.props;
						} else if (legacy.objects != null && Std.isOfType(legacy.objects, Array)) {
							parsedProps = cast legacy.objects;
						} else if (legacy.sprites != null && Std.isOfType(legacy.sprites, Array)) {
							parsedProps = cast legacy.sprites;
						}

						var convertedProps:Array<PropJson> = [];
						if (parsedProps.length > 0) {
							for (i in 0...parsedProps.length) {
								var o = parsedProps[i];
								var pName:String = o.name != null ? Std.string(o.name) : "prop_" + i;
								
								var pAsset:String = "";
								if (o.assetPath != null) pAsset = Std.string(o.assetPath);
								else if (o.image != null) pAsset = Std.string(o.image);
								
								var pPos:Array<Float> = [0, 0];
								if (o.position != null && Std.isOfType(o.position, Array)) {
									pPos = [cast o.position[0], cast o.position[1]];
								} else if (o.pos != null && Std.isOfType(o.pos, Array)) {
									pPos = [cast o.pos[0], cast o.pos[1]];
								} else {
									if (o.x != null) pPos[0] = cast o.x;
									if (o.y != null) pPos[1] = cast o.y;
								}

								var pScale:Array<Float> = [1, 1];
								if (o.scale != null) {
									if (Std.isOfType(o.scale, Array)) {
										pScale = [cast o.scale[0], cast o.scale[1]];
									} else {
										pScale[0] = cast o.scale;
										pScale[1] = cast o.scale;
									}
								}

								var pScroll:Array<Float> = [1, 1];
								if (o.scroll != null && Std.isOfType(o.scroll, Array)) {
									pScroll = [cast o.scroll[0], cast o.scroll[1]];
								} else {
									if (o.scrollX != null) pScroll[0] = cast o.scrollX;
									if (o.scrollY != null) pScroll[1] = cast o.scrollY;
								}

								var pZIndex:Int = o.zIndex != null ? o.zIndex : (i + 1) * 10;
								var pDanceEvery:Int = o.danceEvery != null ? o.danceEvery : 0;
								var pAnimType:String = o.animType != null ? o.animType : "sparrow";
								var pIsPixel:Bool = o.isPixel != null ? o.isPixel : false;
								var pAnims:Array<Dynamic> = o.animations != null ? o.animations : [];

								convertedProps.push({
									name: pName,
									assetPath: pAsset,
									position: pPos,
									scale: pScale,
									scroll: pScroll,
									zIndex: pZIndex,
									danceEvery: pDanceEvery,
									animType: pAnimType,
									isPixel: pIsPixel,
									animations: pAnims
								});
							}
						} else {
							// Fallback if the legacy JSON was completely empty of background arrays
							convertedProps.push({
								name: "converted_background_base",
								assetPath: "stageback", 
								position: [-600, -200],
								scale: [1.0, 1.0],
								scroll: [0.9, 0.9],
								zIndex: 10,
								danceEvery: 0,
								animType: "sparrow",
								isPixel: false,
								animations: []
							});
						}

						var convertedJson:FullStageJson = {
							name: stageName.toUpperCase() + " Converted Stage",
							directory: dir,
							version: "Lid-1.0.0",
							cameraZoom: zoom,
							props: convertedProps,
							characters: {
								bf: { position: bfPos, cameraOffsets: bfCam, zIndex: 300 },
								dad: { position: dadPos, cameraOffsets: dadCam, zIndex: 200 },
								gf: { position: gfPos, cameraOffsets: gfCam, zIndex: 100 }
							}
						};

						var convertedString = Json.stringify(convertedJson, null, "  ");
						var outPath = Sys.getCwd() + 'assets/shared/stages/${stageName}_converted.json';
						File.saveContent(outPath, convertedString);
						
						loadStage(stageName + "_converted");
						dropdownLabel.text = "Stage: " + stageName + "_conv  v";
						showError('Success! Converted format written to: $outPath');
					} catch(err:Dynamic) {
						showError('Conversion parse error: $err');
					}
				});
				fr.load();
			});
			fr.browse([new FileFilter("Legacy Psych Stage JSON", "*.json")]);
		} catch(e:Dynamic) {
			showError('Converter browser window crash: $e');
		}
	}

	// ── STAGE JSON SYSTEM LOADING ─────────────────────────────────────────────
	function loadStage(name:String)
	{
		selectedIndex = -1; isDragging = false; activeHandle = -1;
		currentStageName = name;
		clearStage();
		var fsPath = Paths.getSharedPath('stages/' + name + '.json');
		var raw:String = null;

		if (FileSystem.exists(fsPath)) {
			try { raw = File.getContent(fsPath); } catch(e:Dynamic) {}
		}
		if (raw == null) {
			raw = Paths.getTextFromFile('stages/' + name + '.json');
		}
		if (raw == null) {
			showError('Stage not found: $name  (tried $fsPath)');
			return;
		}

		try {
			var data = Json.parse(raw);
			var list:Array<Dynamic> = [];

			if (data.props != null)        list = cast data.props;
			else if (data.objects != null) list = cast data.objects;
			else if (data.sprites != null) list = cast data.sprites;
			else {
				list = getFallbackSpritesForStage(name);
			}

			for (o in list) {
				try { addObjectFromData(o); }
				catch(e:Dynamic) { trace('Skipped object: $e'); }
			}

			if (data.cameraZoom != null) camGame.zoom = data.cameraZoom;
			showError('Loaded "$name" — ${stageObjects.length} objects');
		} catch(e:Dynamic) {
			showError('Parse error in $name: $e');
		}
	}

	function addObjectFromData(o:Dynamic)
	{
		var spr     = new FlxSprite();
		var imgPath = '';
		if (o.assetPath != null)   imgPath = Std.string(o.assetPath);
		else if (o.image != null)  imgPath = Std.string(o.image);

		var loaded = false;
		for (w in 1...8) {
			var p = 'assets/week$w/images/$imgPath.png';
			if (FileSystem.exists(p)) {
				try {
					var bmd = openfl.display.BitmapData.fromFile(p);
					if (bmd != null) { spr.loadGraphic(bmd); loaded = true; break; }
				} catch(e:Dynamic) {}
			}
		}

		if (!loaded) {
			var p = 'assets/shared/images/$imgPath.png';
			if (FileSystem.exists(p)) {
				try {
					var bmd = openfl.display.BitmapData.fromFile(p);
					if (bmd != null) { spr.loadGraphic(bmd); loaded = true; }
				} catch(e:Dynamic) {}
			}
		}

		if (!loaded) {
			try {
				var g = Paths.image(imgPath);
				if (g != null) { spr.loadGraphic(g); loaded = true; }
			} catch(e:Dynamic) {}
		}

		if (!loaded) {
			spr.makeGraphic(200, 200, FlxColor.fromRGB(180, 80, 80));
		}

		var px:Float = 0.0;
		var py:Float = 0.0;
		if (o.position != null && Std.isOfType(o.position, Array)) {
			px = o.position[0];
			py = o.position[1];
		} else if (o.pos != null && Std.isOfType(o.pos, Array)) {
			px = o.pos[0];
			py = o.pos[1];
		} else {
			if (o.x != null) px = o.x;
			if (o.y != null) py = o.y;
		}

		var sx:Float = 1.0;
		var sy:Float = 1.0;
		if (o.scroll != null && Std.isOfType(o.scroll, Array)) {
			sx = o.scroll[0];
			sy = o.scroll[1];
		} else {
			if (o.scrollX != null) sx = o.scrollX;
			if (o.scrollY != null) sy = o.scrollY;
		}

		var scX:Float = 1.0;
		var scY:Float = 1.0;
		if (o.scale != null) {
			if (Std.isOfType(o.scale, Array)) {
				scX = o.scale[0];
				scY = o.scale[1];
			} else {
				scX = cast o.scale;
				scY = cast o.scale;
			}
		}

		var zIdx:Int      = o.zIndex != null ? o.zIndex : 10;
		var danceEv:Int   = o.danceEvery != null ? o.danceEvery : 0;
		var aType:String  = o.animType != null ? o.animType : "sparrow";
		var pixel:Bool    = o.isPixel != null ? o.isPixel : false;
		var ang:Float     = o.angle != null ? o.angle : 0.0;

		var propName:String = 'prop_${stageObjects.length}';
		if (o.name != null) 
			propName = Std.string(o.name);
		else if (imgPath != '') 
			propName = imgPath.split('/').pop();

		spr.scale.set(scX, scY);
		spr.updateHitbox();
		spr.setPosition(px, py);
		spr.scrollFactor.set(sx, sy);
		spr.angle = ang;
		spr.antialiasing = !pixel;

		stageObjects.push({
			name: propName,
			spr: spr, imagePath: imgPath,
			defaultX: px, defaultY: py, defaultAngle: ang,
			defaultScaleX: scX, defaultScaleY: scY,
			scrollX: sx, scrollY: sy,
			zIndex: zIdx, danceEvery: danceEv,
			animType: aType, isPixel: pixel
		});
		spriteGroup.add(spr);
	}

	function getFallbackSpritesForStage(name:String):Array<Dynamic>
	{
		switch (name) {
			case 'stage':
				return [
					{ assetPath: 'stageback',     position: [-600, -200], scroll: [0.9,  0.9],  scale: [1.0, 1.0] },
					{ assetPath: 'stagefront',    position: [-650,  600], scroll: [0.9,  0.9],  scale: [1.1, 1.1] },
					{ assetPath: 'stagecurtains', position: [-500, -300], scroll: [1.3,  1.3],  scale: [0.9, 0.9] }
				];
			case 'spooky':
				return [{ assetPath: 'halloweenBG', position: [-200, -100], scroll: [1.0, 1.0], scale: [1.0, 1.0] }];
			case 'philly':
				return [
					{ assetPath: 'philly/sky',         position: [-100,   0], scroll: [0.1, 0.1], scale: [1.0, 1.0] },
					{ assetPath: 'philly/city',        position: [ -10,   0], scroll: [0.3, 0.3], scale: [1.0, 1.0] },
					{ assetPath: 'philly/behindtrain', position: [ -40,  50], scroll: [1.0, 1.0], scale: [1.0, 1.0] },
					{ assetPath: 'philly/street',      position: [ -40,  50], scroll: [1.0, 1.0], scale: [1.0, 1.0] }
				];
			case 'limo':
				return [
					{ assetPath: 'limo/limoSunset',  position: [-120,  -50], scroll: [0.1, 0.1], scale: [1.0, 1.0] },
					{ assetPath: 'limo/limoDriveby', position: [-120,  550], scroll: [1.0, 1.0], scale: [1.0, 1.0] }
				];
			case 'mall':
				return [
					{ assetPath: 'christmas/bgWalls',     position: [-1000, -500], scroll: [0.2, 0.2], scale: [1.0, 1.0] },
					{ assetPath: 'christmas/bgEscalator', position: [-1000, -500], scroll: [0.3, 0.3], scale: [1.0, 1.0] },
					{ assetPath: 'christmas/fgSnow',      position: [-600,  700], scroll: [1.0, 1.0], scale: [1.0, 1.0] }
				];
			case 'mallEvil':
				return [{ assetPath: 'christmas/evilBGGlow', position: [-400, -500], scroll: [0.2, 0.2], scale: [1.0, 1.0] }];
			case 'school':
				return [{ assetPath: 'weeb/weebBackground', position: [-200, -100], scroll: [1.0, 1.0], scale: [1.0, 1.0] }];
			case 'schoolEvil':
				return [{ assetPath: 'weeb/animatedEvilSchool', position: [-200, -100], scroll: [1.0, 1.0], scale: [1.0, 1.0] }];
			case 'tank':
				return [
					{ assetPath: 'tankSky',       position: [-400, -400], scroll: [0.1, 0.1], scale: [1.0, 1.0] },
					{ assetPath: 'tankBuildings', position: [-200, -200], scroll: [0.2, 0.2], scale: [1.0, 1.0] },
					{ assetPath: 'tankGround',    position: [-300,  300], scroll: [1.0, 1.0], scale: [1.0, 1.0] }
				];
			default:
				return [{ assetPath: name + '_bg', position: [-200, -100], scroll: [1.0, 1.0], scale: [1.0, 1.0] }];
		}
	}

	function clearStage()
	{
		for (obj in stageObjects) { spriteGroup.remove(obj.spr, true); obj.spr.destroy(); }
		stageObjects = [];
	}

	function saveStage()
	{
		var propList:Array<PropJson> = [];
		for (i in 0...stageObjects.length) {
			var obj = stageObjects[i];
			propList.push({
				name:       obj.name,
				assetPath:  obj.imagePath,
				position:   [obj.spr.x, obj.spr.y],
				scale:      [obj.spr.scale.x, obj.spr.scale.y],
				scroll:     [obj.scrollX, obj.scrollY],
				zIndex:     obj.zIndex != 0 ? obj.zIndex : (i + 1) * 10,
				danceEvery: obj.danceEvery,
				animType:   obj.animType,
				isPixel:    obj.isPixel,
				animations: []
			});
		}

		var fullJson:FullStageJson = {
			name: currentStageName.toUpperCase() + " Stage",
			directory: "shared",
			version: "1.0.0",
			cameraZoom: camGame.zoom,
			props: propList,
			characters: {
				bf: { position: [989.5, 885], cameraOffsets: [-100, -100], zIndex: 300 },
				dad: { position: [335, 885], cameraOffsets: [150, -100], zIndex: 200 },
				gf: { position: [751.5, 787], cameraOffsets: [0, 0], zIndex: 100 }
			}
		};

		var jsonString = Json.stringify(fullJson, null, "  ");
		try {
			var out = Sys.getCwd() + 'assets/shared/stages/${currentStageName}_edited.json';
			File.saveContent(out, jsonString);
			showError('Saved Official Format: $out');
		} catch(e:Dynamic) {
			showError('Save failed: $e');
		}
	}

	function openNewObjectDialog()
	{
		try {
			var fr = new FileReference();
			fr.addEventListener(Event.SELECT, function(e:Event) {
				addObjectFromData({
					assetPath:  fr.name.split('.')[0],
					position:   [camGame.scroll.x + FlxG.width / camGame.zoom * 0.5,
					             camGame.scroll.y + FlxG.height / camGame.zoom * 0.5],
					scroll: [1.0, 1.0], scale: [1.0, 1.0], angle: 0
				});
				selectedIndex = stageObjects.length - 1;
			});
			fr.browse([new FileFilter("PNG Images", "*.png")]);
		} catch(e:Dynamic) {
			showError('File dialog error: $e');
		}
	}

	function resetCamera()
	{
		FlxTween.tween(camGame, { "scroll.x": 0.0, "scroll.y": 0.0, zoom: DEFAULT_ZOOM }, 0.35);
	}

	function resetSelectedObject()
	{
		if (selectedIndex < 0) return;
		var obj = stageObjects[selectedIndex];
		obj.spr.x = obj.defaultX; obj.spr.y = obj.defaultY;
		obj.spr.angle = obj.defaultAngle;
		obj.spr.scale.set(obj.defaultScaleX, obj.defaultScaleY);
		obj.spr.updateHitbox();
	}

	function deleteSelected()
	{
		if (selectedIndex < 0 || selectedIndex >= stageObjects.length) return;
		var obj = stageObjects[selectedIndex];
		spriteGroup.remove(obj.spr, true);
		obj.spr.destroy();
		stageObjects.splice(selectedIndex, 1);
		selectedIndex = stageObjects.length > 0 ? Std.int(Math.min(selectedIndex, stageObjects.length - 1)) : -1;
		isDragging = false; activeHandle = -1;
	}

	function swapObjects(a:Int, b:Int)
	{
		var tmp = stageObjects[a]; stageObjects[a] = stageObjects[b]; stageObjects[b] = tmp;
		spriteGroup.clear();
		for (obj in stageObjects) spriteGroup.add(obj.spr);
	}

	function toggleUI()
	{
		uiHidden        = !uiHidden;
		uiGroup.visible = !uiHidden;
		if (uiHidden) for (h in handleSprites) h.visible = false;
	}

	function isOverDropdown():Bool
	{
		var mp = FlxG.mouse.getScreenPosition(camUI);
		var mx = mp.x;
		var my = mp.y;
		mp.put();
		if (mx >= DD_X && mx <= DD_X + DD_W && my >= DD_Y && my <= DD_Y + DD_H) return true;
		if (dropdownOpen && mx >= DD_X && mx <= DD_X + DD_W
		    && my >= DD_Y + DD_H && my <= DD_Y + DD_H + STAGES.length * DD_IH) return true;
		return false;
	}

	function isOverTopbar():Bool
	{
		var mp = FlxG.mouse.getScreenPosition(camUI);
		var inside = (mp.y >= 0 && mp.y <= 30);
		mp.put();
		return inside;
	}

	function showError(msg:String)
	{
		errorText.text = msg; errorText.visible = true; errorTimer = 5;
	}

	function tickError(elapsed:Float)
	{
		if (errorTimer > 0) { errorTimer -= elapsed; if (errorTimer <= 0) errorText.visible = false; }
	}

	override function destroy()
	{
		clearStage();
		super.destroy();
	}
}