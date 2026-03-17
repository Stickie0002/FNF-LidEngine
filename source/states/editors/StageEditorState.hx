package states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import backend.MusicBeatState;
import objects.Character;

class StageEditorState extends MusicBeatState
{
    var objectsGroup:FlxTypedGroup<FlxSprite>;
    var curObject:FlxSprite;
    
    // Character Previews (Ghosting)
    var coachBF:Character;
    var coachDad:Character;
    
    var camEditor:FlxCamera;
    var camHUD:FlxCamera;
    var uiText:FlxText;

    override function create()
    {
        // 1. Setup Cameras FIRST
        camEditor = new FlxCamera();
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;
        FlxG.cameras.reset(camEditor);
        FlxG.cameras.add(camHUD, false);

        // 2. Initialize Group
        objectsGroup = new FlxTypedGroup<FlxSprite>();
        objectsGroup.cameras = [camEditor];
        add(objectsGroup); 

        // 3. Add Ghost Characters (Positions)
        coachDad = new Character(100, 100, 'dad');
        coachDad.alpha = 0.6;
        coachDad.cameras = [camEditor];
        add(coachDad);

        coachBF = new Character(770, 450, 'bf');
        coachBF.alpha = 0.6;
        coachBF.cameras = [camEditor];
        add(coachBF);

        // 4. UI Setup
        uiText = new FlxText(20, 20, 0, "LID STAGE EDITOR\nSPACE: Spawn\nWASD: Move Cam\nQ/E: Zoom\nSHIFT: Fast Move", 20);
        uiText.setFormat(Paths.font("vcr.ttf"), 20, 0xFF00FF00, LEFT, OUTLINE, 0xFF000000);
        uiText.cameras = [camHUD];
        add(uiText);

        FlxG.mouse.visible = true;
        super.create();
    }

    override function update(elapsed:Float)
    {
        // 1. Safety Camera Check
        var targetCam = (camEditor != null) ? camEditor : FlxG.camera;

        // 2. WASD Movement
        var moveSpeed:Float = 500 * elapsed;
        if (FlxG.keys.pressed.SHIFT) moveSpeed *= 2;

        if (FlxG.keys.pressed.W) targetCam.scroll.y -= moveSpeed;
        if (FlxG.keys.pressed.S) targetCam.scroll.y += moveSpeed;
        if (FlxG.keys.pressed.A) targetCam.scroll.x -= moveSpeed;
        if (FlxG.keys.pressed.D) targetCam.scroll.x += moveSpeed;

        // 3. Zooming (I and O)
        if (FlxG.keys.pressed.I) targetCam.zoom += 0.5 * elapsed;
        if (FlxG.keys.pressed.O) targetCam.zoom -= 0.5 * elapsed;

        // 4. Fixed Spawn Logic
        if (FlxG.keys.justPressed.SPACE) {
            // We use 'targetCam' safety here to prevent the line 80/84 crash
            var spawnX = FlxG.mouse.x + targetCam.scroll.x;
            var spawnY = FlxG.mouse.y + targetCam.scroll.y;
            
            var newObj:FlxSprite = new FlxSprite(spawnX, spawnY);
            // Using the exact path from your folder screenshot
            newObj.loadGraphic('assets/week_assets/week1/images/stageback.png'); 
            
            if (objectsGroup != null) {
                objectsGroup.add(newObj);
                curObject = newObj;
                trace("Spawned object at: " + spawnX + ", " + spawnY);
            }
        }

        // 5. Selection with Null Guard
        if (FlxG.mouse.justPressed && objectsGroup != null) {
            objectsGroup.forEachAlive(function(spr:FlxSprite) {
                if (spr != null && FlxG.mouse.overlaps(spr, targetCam)) {
                    curObject = spr;
                }
            });
        }

        // 6. Dragging
        if (FlxG.mouse.pressed && curObject != null) {
            curObject.x = FlxG.mouse.x + targetCam.scroll.x - (curObject.width / 2);
            curObject.y = FlxG.mouse.y + targetCam.scroll.y - (curObject.height / 2);
        }

        if (controls.BACK) MusicBeatState.switchState(new states.editors.MasterEditorMenu());
        super.update(elapsed);
    }
}