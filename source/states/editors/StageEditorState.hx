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

typedef StageObject = {
	spr:           FlxSprite,
	imagePath:     String,
	defaultX:      Float,
	defaultY:      Float,
	defaultAngle:  Float,
	defaultScaleX: Float,
	defaultScaleY: Float,
	scrollX:       Float,
	scrollY:       Float
}

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

	// ── CUSTOM DROPDOWN ───────────────────────────────────────────────────────
	var dropdownBg:FlxSprite;
	var dropdownLabel:FlxText;
	var dropdownOpen:Bool = false;
	var dropdownItems:Array<FlxText> = [];
	var dropdownItemBgs:Array<FlxSprite> = [];
	var dropdownGroup:FlxGroup;
	static inline var DD_X:Float   = 150;
	static inline var DD_W:Float   = 180;
	static inline var DD_H:Float   = 28;
	static inline var DD_IH:Float  = 24; // item height

	// ── UI ────────────────────────────────────────────────────────────────────
	var statusText:FlxText;
	var infoText:FlxText;
	var hintText:FlxText;
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
		// MUST be first — Psych MusicBeatState sets up internals here
		super.create();

		FlxG.mouse.visible = true;

		// ── Cameras ──────────────────────────────────────────────────────────
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

		// World sprites draw to camGame by default
		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		FlxG.cameras.setDefaultDrawTarget(camHandles, false);
		FlxG.cameras.setDefaultDrawTarget(camUI, false);

		// ── Stage sprite group ────────────────────────────────────────────────
		spriteGroup = new FlxTypedGroup<FlxSprite>();
		spriteGroup.cameras = [camGame];
		add(spriteGroup);

		// ── Yellow outline (screen-space on camHandles) ───────────────────────
		outlineSprite = new FlxSprite();
		outlineSprite.cameras = [camHandles];
		outlineSprite.scrollFactor.set(0, 0);
		outlineSprite.visible = false;
		add(outlineSprite);

		// ── Handles ──────────────────────────────────────────────────────────
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

		// ── UI ────────────────────────────────────────────────────────────────
		buildUI();

		// ── Load default stage ────────────────────────────────────────────────
		loadStage('stage');
	}

	function buildUI()
	{
		uiGroup = new FlxGroup();
		add(uiGroup);

		// ── Dropdown header ───────────────────────────────────────────────────
		dropdownBg = new FlxSprite(DD_X, 10);
		dropdownBg.makeGraphic(Std.int(DD_W), Std.int(DD_H), 0xFF333355);
		dropdownBg.cameras = [camUI];
		dropdownBg.scrollFactor.set(0, 0);
		uiGroup.add(dropdownBg);

		dropdownLabel = new FlxText(DD_X + 6, 15, DD_W - 12, "Stage: stage  v", 12);
		dropdownLabel.setFormat(null, 12, FlxColor.WHITE, LEFT);
		dropdownLabel.cameras = [camUI];
		dropdownLabel.scrollFactor.set(0, 0);
		uiGroup.add(dropdownLabel);

		// ── Dropdown items ────────────────────────────────────────────────────
		dropdownGroup = new FlxGroup();
		for (i in 0...STAGES.length) {
			var bg = new FlxSprite(DD_X, 10 + DD_H + i * DD_IH);
			bg.makeGraphic(Std.int(DD_W), Std.int(DD_IH), i % 2 == 0 ? 0xFF2b2b44 : 0xFF232338);
			bg.cameras = [camUI];
			bg.scrollFactor.set(0, 0);
			bg.visible = false;
			dropdownItemBgs.push(bg);
			dropdownGroup.add(bg);

			var txt = new FlxText(DD_X + 6, 10 + DD_H + i * DD_IH + 4, DD_W - 12, STAGES[i], 11);
			txt.setFormat(null, 11, FlxColor.fromRGB(190, 210, 255), LEFT);
			txt.cameras = [camUI];
			txt.scrollFactor.set(0, 0);
			txt.visible = false;
			dropdownItems.push(txt);
			dropdownGroup.add(txt);
		}
		uiGroup.add(dropdownGroup);

		// ── Status bar (bottom-left) ──────────────────────────────────────────
		statusText = new FlxText(10, FlxG.height - 20, 700, "", 11);
		statusText.setFormat(null, 11, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		statusText.cameras = [camUI];
		statusText.scrollFactor.set(0, 0);
		uiGroup.add(statusText);

		// ── Info (top-right) ──────────────────────────────────────────────────
		infoText = new FlxText(0, 10, FlxG.width - 10, "", 11);
		infoText.setFormat(null, 11, FlxColor.fromRGB(200, 200, 200), RIGHT, OUTLINE, FlxColor.BLACK);
		infoText.cameras = [camUI];
		infoText.scrollFactor.set(0, 0);
		uiGroup.add(infoText);

		// ── Hint (bottom-right) ───────────────────────────────────────────────
		hintText = new FlxText(0, FlxG.height - 116, FlxG.width - 10,
			"I/J/K/L Pan  |  Q/E or Scroll=Zoom  |  Shift=3x  Ctrl=0.1x\n" +
			"LClick=Select/Drag  |  Tab=Cycle  |  [/]=Layer  |  Del=Delete\n" +
			"Ctrl+A=SelAll  Ctrl+D=Desel  Ctrl+R=ResetCam  Alt+R=ResetObj\n" +
			"Ctrl+S=Save  Ctrl+N=NewObj  Ctrl+H=HideUI  F=FocusCam\n" +
			"Space=ToggleAnim  |  ESC=Exit",
			10
		);
		hintText.setFormat(null, 10, FlxColor.fromRGB(130, 130, 130), RIGHT, OUTLINE, FlxColor.BLACK);
		hintText.cameras = [camUI];
		hintText.scrollFactor.set(0, 0);
		uiGroup.add(hintText);

		// ── Error / info toast ────────────────────────────────────────────────
		errorText = new FlxText(10, FlxG.height - 42, FlxG.width - 20, "", 13);
		errorText.setFormat(null, 13, FlxColor.YELLOW, LEFT, OUTLINE, FlxColor.BLACK);
		errorText.cameras = [camUI];
		errorText.scrollFactor.set(0, 0);
		errorText.visible = false;
		add(errorText); // outside uiGroup so it survives Ctrl+H
	}

	// ═════════════════════════════════════════════════════════════════════════
	//  UPDATE
	// ═════════════════════════════════════════════════════════════════════════
	override function update(elapsed:Float)
	{
		if (FlxG.keys.justPressed.ESCAPE) {
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new states.editors.MasterEditorMenu());
			return;
		}

		super.update(elapsed);

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

	// ── Custom dropdown ───────────────────────────────────────────────────────
	function handleDropdown()
	{
		if (!FlxG.mouse.justPressed) return;
		// Use camUI screen position — avoids camGame zoom/scroll affecting coords
		var mp = FlxG.mouse.getScreenPosition(camUI);
		var mx = mp.x;
		var my = mp.y;
		mp.put();

		// Header
		if (mx >= DD_X && mx <= DD_X + DD_W && my >= 10 && my <= 10 + DD_H) {
			dropdownOpen = !dropdownOpen;
			for (i in 0...STAGES.length) {
				dropdownItems[i].visible   = dropdownOpen;
				dropdownItemBgs[i].visible = dropdownOpen;
			}
			return;
		}

		// Items
		if (dropdownOpen) {
			for (i in 0...STAGES.length) {
				var iy = 10 + DD_H + i * DD_IH;
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

	// ── Camera panning ────────────────────────────────────────────────────────
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

	// ── Zoom ──────────────────────────────────────────────────────────────────
	function handleZoom()
	{
		if (FlxG.mouse.wheel != 0)
			camGame.zoom = Math.max(0.1, Math.min(camGame.zoom + FlxG.mouse.wheel * 0.05, 8.0));
		if (FlxG.keys.justPressed.Q) camGame.zoom = Math.min(camGame.zoom + 0.1, 8.0);
		if (FlxG.keys.justPressed.E) camGame.zoom = Math.max(camGame.zoom - 0.1, 0.1);
	}

	// ── Object selection ──────────────────────────────────────────────────────
	function handleSelection()
	{
		if (!FlxG.mouse.justPressed) return;
		if (isOverDropdown()) return;
		for (h in handleSprites)
			if (h.visible && FlxG.mouse.overlaps(h, camHandles)) return;

		var hit = -1;
		var i   = stageObjects.length - 1;
		while (i >= 0) {
			if (FlxG.mouse.overlaps(stageObjects[i].spr, camGame)) { hit = i; break; }
			i--;
		}

		selectedIndex = hit;
		isDragging    = false;

		if (selectedIndex >= 0) {
			var mw      = FlxG.mouse.getWorldPosition(camGame);
			dragOffsetX = mw.x - stageObjects[selectedIndex].spr.x;
			dragOffsetY = mw.y - stageObjects[selectedIndex].spr.y;
			isDragging  = true;
		}
	}

	// ── Drag / resize / rotate ────────────────────────────────────────────────
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
				var mw  = FlxG.mouse.getWorldPosition(camGame);
				resizeStartX = mw.x; resizeStartY = mw.y;
				resizeStartW = spr.scale.x; resizeStartH = spr.scale.y;
				resizeOrigX  = spr.x; resizeOrigY = spr.y;
				if (i == HANDLE_ROTATE) {
					rotateCenterX = spr.x + spr.frameWidth  * spr.scale.x * 0.5;
					rotateCenterY = spr.y + spr.frameHeight * spr.scale.y * 0.5;
					rotateStartAngle = spr.angle;
					rotateStartMouseAngle = Math.atan2(mw.y - rotateCenterY, mw.x - rotateCenterX) * (180 / Math.PI);
				}
				break;
			}
		}

		if (FlxG.mouse.pressed && selectedIndex >= 0) {
			var spr = stageObjects[selectedIndex].spr;
			var mw  = FlxG.mouse.getWorldPosition(camGame);

			if (activeHandle == -1 && isDragging) {
				spr.x = mw.x - dragOffsetX;
				spr.y = mw.y - dragOffsetY;

			} else if (activeHandle == HANDLE_ROTATE) {
				var curAng = Math.atan2(mw.y - rotateCenterY, mw.x - rotateCenterX) * (180 / Math.PI);
				spr.angle  = rotateStartAngle + (curAng - rotateStartMouseAngle);

			} else if (activeHandle >= 0) {
				var dX = mw.x - resizeStartX;
				var dY = mw.y - resizeStartY;
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

	// ── Keybinds ──────────────────────────────────────────────────────────────
	function handleKeybinds(elapsed:Float)
	{
		var ctrl = FlxG.keys.pressed.CONTROL;
		var alt  = FlxG.keys.pressed.ALT;

		if (ctrl) {
			if (FlxG.keys.justPressed.S) saveStage();
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
			camGame.scroll.x = spr.x + spr.frameWidth  * spr.scale.x * 0.5 - FlxG.width  * 0.5;
			camGame.scroll.y = spr.y + spr.frameHeight * spr.scale.y * 0.5 - FlxG.height * 0.5;
		}
	}

	// ═════════════════════════════════════════════════════════════════════════
	//  OUTLINE + HANDLES  (fixed screen-space math)
	// ═════════════════════════════════════════════════════════════════════════
	function updateOverlay()
	{
		if (selectedIndex < 0 || selectedIndex >= stageObjects.length) {
			outlineSprite.visible = false;
			for (h in handleSprites) h.visible = false;
			return;
		}

		var spr  = stageObjects[selectedIndex].spr;
		var zoom = camGame.zoom;

		// getScreenPosition accounts for camera scroll, zoom, and viewport offset correctly
		var screenPos = spr.getScreenPosition(null, camGame);
		var sx = screenPos.x;
		var sy = screenPos.y;
		screenPos.put();

		// Screen-space size = world size * zoom
		var sw = spr.frameWidth  * spr.scale.x * zoom;
		var sh = spr.frameHeight * spr.scale.y * zoom;

		// ── Outline ───────────────────────────────────────────────────────────
		var PAD  = 3;
		var ow   = Std.int(sw) + PAD * 2; if (ow < PAD * 2) ow = PAD * 2;
		var oh   = Std.int(sh) + PAD * 2; if (oh < PAD * 2) oh = PAD * 2;

		if (Std.int(outlineSprite.width) != ow || Std.int(outlineSprite.height) != oh) {
			outlineSprite.makeGraphic(ow, oh, 0x00000000);
			drawHollowRect(outlineSprite, ow, oh, FlxColor.YELLOW, 3);
		}
		// Place outline so its inner edge aligns exactly with the sprite edges
		outlineSprite.setPosition(sx - PAD, sy - PAD);
		outlineSprite.angle   = spr.angle;
		outlineSprite.visible = true;

		// ── Handle positions ──────────────────────────────────────────────────
		var cx  = sx + sw * 0.5;
		var cy  = sy + sh * 0.5;
		var P:Float = 6; // gap between sprite edge and handle

		// left, right, up, down, topLeft, topRight, bottomLeft, bottomRight, rotate
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
			handleSprites[i].setPosition(hx[i], hy[i]);
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

	// ── Status bar ────────────────────────────────────────────────────────────
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

	// ═════════════════════════════════════════════════════════════════════════
	//  STAGE LOADING
	// ═════════════════════════════════════════════════════════════════════════
	function loadStage(name:String)
	{
		selectedIndex = -1; isDragging = false; activeHandle = -1;
		currentStageName = name;
		clearStage();

		// Try direct filesystem path first (works in desktop / debug builds)
		var fsPath = Paths.getSharedPath('stages/' + name + '.json');
		var raw:String = null;

		if (FileSystem.exists(fsPath)) {
			try { raw = File.getContent(fsPath); } catch(e:Dynamic) {}
		}

		// Fallback: OpenFL embedded assets via Paths
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

			if (data.objects != null)      list = cast data.objects;
			else if (data.sprites != null) list = cast data.sprites;
			else {
				// Standard Psych stage JSON — build from known layout
				list = getFallbackSpritesForStage(name);
			}

			for (o in list) {
				try { addObjectFromData(o); }
				catch(e:Dynamic) { trace('Skipped object: $e'); }
			}

			showError('Loaded "$name" — ${stageObjects.length} objects');
		} catch(e:Dynamic) {
			showError('Parse error in $name: $e');
		}
	}

	function addObjectFromData(o:Dynamic)
	{
		var spr     = new FlxSprite();
		var imgPath = o.image != null ? Std.string(o.image) : '';

		var loaded = false;

		// 1. Try week folders directly (week1–week7)
		for (w in 1...8) {
			var p = 'assets/week$w/images/$imgPath.png';
			if (FileSystem.exists(p)) {
				try {
					var bmd = openfl.display.BitmapData.fromFile(p);
					if (bmd != null) { spr.loadGraphic(bmd); loaded = true; break; }
				} catch(e:Dynamic) {}
			}
		}

		// 2. Shared images
		if (!loaded) {
			var p = 'assets/shared/images/$imgPath.png';
			if (FileSystem.exists(p)) {
				try {
					var bmd = openfl.display.BitmapData.fromFile(p);
					if (bmd != null) { spr.loadGraphic(bmd); loaded = true; }
				} catch(e:Dynamic) {}
			}
		}

		// 3. Paths.image() — handles OpenFL embedded + mods
		if (!loaded) {
			try {
				var g = Paths.image(imgPath);
				if (g != null) { spr.loadGraphic(g); loaded = true; }
			} catch(e:Dynamic) {}
		}

		if (!loaded) {
			spr.makeGraphic(200, 200, FlxColor.fromRGB(180, 80, 80));
			trace('Could not load image: $imgPath');
		}

		// ── Parameters ───────────────────────────────────────────────────────
		var px:Float  = (o.pos    != null && Std.isOfType(o.pos, Array))    ? o.pos[0]    : (o.x       != null ? o.x       : 0.0);
		var py:Float  = (o.pos    != null && Std.isOfType(o.pos, Array))    ? o.pos[1]    : (o.y       != null ? o.y       : 0.0);
		var sx:Float  = (o.scroll != null && Std.isOfType(o.scroll, Array)) ? o.scroll[0] : (o.scrollX != null ? o.scrollX : 1.0);
		var sy:Float  = (o.scroll != null && Std.isOfType(o.scroll, Array)) ? o.scroll[1] : (o.scrollY != null ? o.scrollY : 1.0);
		var sc:Float  = o.scale  != null ? o.scale  : 1.0;
		var ang:Float = o.angle  != null ? o.angle  : 0.0;

		spr.scale.set(sc, sc);
		spr.updateHitbox();
		spr.setPosition(px, py);
		spr.scrollFactor.set(sx, sy);
		spr.angle = ang;

		stageObjects.push({
			spr: spr, imagePath: imgPath,
			defaultX: px, defaultY: py, defaultAngle: ang,
			defaultScaleX: sc, defaultScaleY: sc,
			scrollX: sx, scrollY: sy
		});
		spriteGroup.add(spr);
	}

	// Fallback layout for standard Psych stage JSONs that use Haxe code, not object lists
	function getFallbackSpritesForStage(name:String):Array<Dynamic>
	{
		switch (name) {
			case 'stage':
				return [
					{ image: 'stageback',     pos: [-600, -200], scroll: [0.9,  0.9],  scale: 1.0 },
					{ image: 'stagefront',    pos: [-650,  600], scroll: [0.9,  0.9],  scale: 1.1 },
					{ image: 'stagecurtains', pos: [-500, -300], scroll: [1.3,  1.3],  scale: 0.9 }
				];
			case 'spooky':
				return [
					{ image: 'halloweenBG', pos: [-200, -100], scroll: [1.0, 1.0] }
				];
			case 'philly':
				return [
					{ image: 'philly/sky',         pos: [-100,   0], scroll: [0.1, 0.1] },
					{ image: 'philly/city',         pos: [ -10,   0], scroll: [0.3, 0.3] },
					{ image: 'philly/behindtrain',  pos: [ -40,  50], scroll: [1.0, 1.0] },
					{ image: 'philly/street',       pos: [ -40,  50], scroll: [1.0, 1.0] }
				];
			case 'limo':
				return [
					{ image: 'limo/limoSunset',  pos: [-120,  -50], scroll: [0.1, 0.1] },
					{ image: 'limo/limoDriveby', pos: [-120,  550], scroll: [1.0, 1.0] }
				];
			case 'mall':
				return [
					{ image: 'christmas/bgWalls',  pos: [-1000, -500], scroll: [0.2, 0.2] },
					{ image: 'christmas/bgEscalator', pos: [-1000, -500], scroll: [0.3, 0.3] },
					{ image: 'christmas/fgSnow',   pos: [-600,  700], scroll: [1.0, 1.0] }
				];
			case 'mallEvil':
				return [
					{ image: 'christmas/evilBGGlow', pos: [-400, -500], scroll: [0.2, 0.2] }
				];
			case 'school':
				return [
					{ image: 'weeb/weebBackground', pos: [-200, -100], scroll: [1.0, 1.0] }
				];
			case 'schoolEvil':
				return [
					{ image: 'weeb/animatedEvilSchool', pos: [-200, -100], scroll: [1.0, 1.0] }
				];
			case 'tank':
				return [
					{ image: 'tankSky',     pos: [-400, -400], scroll: [0.1, 0.1] },
					{ image: 'tankBuildings', pos: [-200, -200], scroll: [0.2, 0.2] },
					{ image: 'tankGround',  pos: [-300,  300], scroll: [1.0, 1.0] }
				];
			default:
				return [
					{ image: name + '_bg', pos: [-200, -100], scroll: [1.0, 1.0] }
				];
		}
	}

	function clearStage()
	{
		for (obj in stageObjects) { spriteGroup.remove(obj.spr, true); obj.spr.destroy(); }
		stageObjects = [];
	}

	// ═════════════════════════════════════════════════════════════════════════
	//  SAVE
	// ═════════════════════════════════════════════════════════════════════════
	function saveStage()
	{
		var list:Array<Dynamic> = [];
		for (obj in stageObjects) list.push({
			image:  obj.imagePath,
			pos:    [obj.spr.x, obj.spr.y],
			scroll: [obj.scrollX, obj.scrollY],
			scale:  obj.spr.scale.x,
			angle:  obj.spr.angle
		});
		var json = Json.stringify({ objects: list }, null, "\t");
		try {
			var out = Sys.getCwd() + 'assets/shared/stages/${currentStageName}_edited.json';
			File.saveContent(out, json);
			showError('Saved: $out');
		} catch(e:Dynamic) {
			showError('Save failed: $e');
		}
	}

	// ═════════════════════════════════════════════════════════════════════════
	//  NEW OBJECT
	// ═════════════════════════════════════════════════════════════════════════
	function openNewObjectDialog()
	{
		try {
			var fr = new FileReference();
			fr.addEventListener(Event.SELECT, function(e:Event) {
				addObjectFromData({
					image:  fr.name.split('.')[0],
					pos:    [camGame.scroll.x + FlxG.width / camGame.zoom * 0.5,
					         camGame.scroll.y + FlxG.height / camGame.zoom * 0.5],
					scroll: [1.0, 1.0], scale: 1.0, angle: 0
				});
				selectedIndex = stageObjects.length - 1;
			});
			fr.browse([new FileFilter("PNG Images", "*.png")]);
		} catch(e:Dynamic) {
			showError('File dialog error: $e');
		}
	}

	// ═════════════════════════════════════════════════════════════════════════
	//  HELPERS
	// ═════════════════════════════════════════════════════════════════════════
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
		if (mx >= DD_X && mx <= DD_X + DD_W && my >= 10 && my <= 10 + DD_H) return true;
		if (dropdownOpen && mx >= DD_X && mx <= DD_X + DD_W
		    && my >= 10 + DD_H && my <= 10 + DD_H + STAGES.length * DD_IH) return true;
		return false;
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
