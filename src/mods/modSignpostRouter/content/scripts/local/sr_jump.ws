// Signpost Router - Signpost Jump. In the map opened from a signpost, fast travel straight to the
// signpost nearest the tracked target: press T, or select the signpost you are standing at.

@addMethod(CR4MapMenu) function SRJumpTag( out tag : name ) : bool
{
	var initData : W3MapInitData;
	var here : W3FastTravelEntity;
	var hud : CR4ScriptedHud;
	var minimap : CR4HudModuleMinimap2;

	initData = (W3MapInitData)GetMenuInitData();
	if ( !initData )
		return false;
	here = (W3FastTravelEntity)initData.GetUsedFastTravelEntity();
	if ( !here )
		return false;
	hud = (CR4ScriptedHud)theGame.GetHud();
	if ( !hud )
		return false;
	minimap = (CR4HudModuleMinimap2)hud.GetHudModule( "Minimap2Module" );
	if ( !minimap || !minimap.srRouter )
		return false;
	return minimap.srRouter.FindJumpSignpost( here.entityName, tag );
}

@addMethod(CR4MapMenu) function SRJump() : bool
{
	var tag, area : name;

	if ( !SRJumpTag( tag ) )
		return false;
	area = theGame.GetCommonMapManager().GetAreaFromWorldPath( theGame.GetWorld().GetDepotPath() );
	SRLog( "Signpost Jump to " + NameToString( tag ) );
	OnStaticMapPinUsed( tag, NameToFlashUInt( area ) );
	return true;
}

// Show the T hint only when there is somewhere to jump to.
@wrapMethod(CR4MapMenu) function UpdateInputFeedback()
{
	var tag : name;

	wrappedMethod();
	if ( SRJumpTag( tag ) )
	{
		AddInputBinding( "panel_button_sr_jump", "gamepad_L3", IK_T );
		SetButtons();
	}
}

// Selecting the signpost you are standing at normally says "already here"; jump instead.
@wrapMethod(CR4MapMenu) function OnStaticMapPinUsed( pinTag : name, areaNameId : int )
{
	var initData : W3MapInitData;
	var here : W3FastTravelEntity;

	initData = (W3MapInitData)GetMenuInitData();
	if ( initData )
		here = (W3FastTravelEntity)initData.GetUsedFastTravelEntity();
	if ( here && here.entityName == pinTag && SRJump() )
		return true;
	return wrappedMethod( pinTag, areaNameId );
}

// The T key arrives at whichever menu the hint bar reports to; handle it in both.
@wrapMethod(CR4CommonMenu) function OnInputHandled( NavCode : string, KeyCode : int, ActionId : int )
{
	var mapMenu : CR4MapMenu;

	if ( KeyCode == (int)IK_T || NavCode == "gamepad_L3" )
	{
		mapMenu = (CR4MapMenu)GetSubMenu();
		if ( mapMenu && mapMenu.SRJump() )
			return true;
	}
	return wrappedMethod( NavCode, KeyCode, ActionId );
}

@wrapMethod(CR4MenuBase) function OnInputHandled( NavCode : string, KeyCode : int, ActionId : int )
{
	var mapMenu : CR4MapMenu;

	if ( KeyCode == (int)IK_T || NavCode == "gamepad_L3" )
	{
		mapMenu = (CR4MapMenu)this;
		if ( mapMenu && mapMenu.SRJump() )
			return true;
	}
	return wrappedMethod( NavCode, KeyCode, ActionId );
}
