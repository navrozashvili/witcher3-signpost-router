// Signpost Router - orchestration: throttling, state machine, target lookup, teleport detection.

enum ESRState
{
	SRS_Idle,
	SRS_Direct,
	SRS_Guiding
}

class SRRouter
{
	private var minimap : CR4HudModuleMinimap2;
	private var settings : SRSettings;
	private var pins : SRPinManager;
	private var overlay : SROverlay;
	private var routerState : ESRState;
	private var plan : SRPlan;
	private var lastEvalTime : float;
	private var lastEvalPos : Vector;
	private var lastTarget : Vector;
	private var lastTickPos : Vector;
	private var lastWorldPath : string;
	private var adopted : bool;
	private var pendingForce : bool;
	private var lastDrawPos : Vector;
	private var lastDrawScale : float;
	private var lastHudTime : float;

	private const var EVAL_INTERVAL : float;		default EVAL_INTERVAL = 2.0;
	private const var HUD_INTERVAL : float;			default HUD_INTERVAL = 0.25;
	private const var JUMP_RANGE : float;			default JUMP_RANGE = 8.0;
	private const var MOVE_THRESHOLD : float;		default MOVE_THRESHOLD = 20.0;
	private const var TELEPORT_THRESHOLD : float;	default TELEPORT_THRESHOLD = 300.0;
	private const var REDRAW_DIST : float;			default REDRAW_DIST = 10.0;

	public function Init( owner : CR4HudModuleMinimap2 )
	{
		minimap = owner;
		settings = new SRSettings in this;
		pins = new SRPinManager in this;
		overlay = new SROverlay in this;
		overlay.Init( owner );
		settings.Load();
		routerState = SRS_Idle;
		theInput.RegisterListener( this, 'OnSRSignpostJump', 'SRSignpostJump' );
		SRLog( "Router initialised: " + settings.ToString() );
	}

	// The dedicated jump key (input.settings action SRSignpostJump), used while standing at a signpost.
	event OnSRSignpostJump( action : SInputAction )
	{
		if ( IsPressed( action ) )
			JumpFromHere();
	}

	public function Tick()
	{
		var now : float;
		var pos : Vector;
		var worldPath : string;
		var settingsChanged : bool;

		overlay.Flush();

		pos = thePlayer.GetWorldPosition();
		worldPath = theGame.GetWorld().GetDepotPath();

		// Cheap every-tick check: a big jump or a world change means fast travel (or a load).
		if ( lastWorldPath != "" && ( worldPath != lastWorldPath || VecDistance2D( pos, lastTickPos ) > TELEPORT_THRESHOLD ) )
			OnTeleported();
		lastTickPos = pos;
		lastWorldPath = worldPath;

		// Between full re-plans, redraw the dots every REDRAW_DIST metres walked and when the zoom changes.
		if ( routerState == SRS_Guiding && settings.showLine && !overlay.IsBusy() && !IsPaused()
			&& ( VecDistance2D( pos, lastDrawPos ) >= REDRAW_DIST || AbsF( overlay.ZoomScale() - lastDrawScale ) > 0.05 ) )
			DrawDots( pos, plan.entryPos, plan.exitPos, lastTarget );

		UpdateHudDistances( pos );

		now = theGame.GetEngineTimeAsSeconds();
		if ( now - lastEvalTime < EVAL_INTERVAL )
			return;
		lastEvalTime = now;

		settingsChanged = settings.Load();
		if ( settingsChanged )
			pendingForce = true;
		HandleDebugToggles();

		if ( !adopted )
		{
			pins.AdoptExisting( SRCollectSignposts( worldPath ) );
			adopted = true;
		}

		if ( !settings.enabled )
		{
			if ( routerState != SRS_Idle || pins.HasOurPin() || overlay.IsDrawn() )
				Reset( "disabled" );
			return;
		}
		if ( IsPaused() )
			return;

		Evaluate( pos, worldPath, pendingForce );
		pendingForce = false;
	}

	private function DrawDots( pos : Vector, entryPos : Vector, exitPos : Vector, target : Vector )
	{
		overlay.Draw( pos, entryPos, exitPos, target, SRRouteColor( settings.color ) );
		lastDrawPos = pos;
		lastDrawScale = overlay.ZoomScale();
	}

	// While guiding, the time/weather tab shows "<to entry> m > <exit to target> m" (straight line, like the
	// game's own objective distance). Pushed only when the text changes, at most every HUD_INTERVAL.
	private function UpdateHudDistances( pos : Vector )
	{
		var text : string;
		var now : float;

		if ( routerState == SRS_Guiding && settings.enabled && settings.showDistances && !IsPaused() )
			text = " | " + RoundF( VecDistance2D( pos, plan.entryPos ) ) + " m > "
				+ RoundF( VecDistance2D( plan.exitPos, lastTarget ) ) + " m";
		if ( text == minimap.srTimeSuffix )
			return;
		now = theGame.GetEngineTimeAsSeconds();
		if ( text != "" && now - lastHudTime < HUD_INTERVAL )
			return;
		lastHudTime = now;
		minimap.srTimeSuffix = text;
		minimap.RefreshTimeDisplay();
	}

	// Jump key outside menus: fast travel from the signpost the player stands at to the one nearest the target.
	// Same steps as the map's local fast travel (CR4MapMenu.OnStaticMapPinUsed), minus the menu.
	private function JumpFromHere()
	{
		var mm : CCommonMapManager;
		var entities : array< CGameplayEntity >;
		var here, sp : W3FastTravelEntity;
		var i : int;
		var d, best : float;
		var tag, area : name;

		if ( !settings.enabled || theGame.IsBlackscreenOrFading() || theGame.IsDialogOrCutscenePlaying() )
			return;
		FindGameplayEntitiesInRange( entities, thePlayer, JUMP_RANGE, 10, , , , 'W3FastTravelEntity' );
		best = -1;
		for ( i = 0; i < entities.Size(); i += 1 )
		{
			sp = (W3FastTravelEntity)entities[ i ];
			if ( !sp )
				continue;
			d = VecDistance2D( sp.GetWorldPosition(), thePlayer.GetWorldPosition() );
			if ( best < 0 || d < best )
			{
				best = d;
				here = sp;
			}
		}
		if ( !here )
		{
			thePlayer.DisplayHudMessage( "Signpost Jump: stand at a signpost first" );
			return;
		}

		mm = theGame.GetCommonMapManager();
		if ( !thePlayer.IsActionAllowed( EIAB_FastTravel ) )
		{
			thePlayer.DisplayActionDisallowedHudMessage( EIAB_FastTravel );
			return;
		}
		if ( mm.IsEntityMapPinDisabled( here.entityName ) )
		{
			thePlayer.DisplayActionDisallowedHudMessage( EIAB_Undefined, , , true );
			return;
		}
		if ( !FindJumpSignpost( here.entityName, tag ) )
		{
			thePlayer.DisplayHudMessage( "Signpost Jump: no signpost closer to your target" );
			return;
		}

		SRLog( "Signpost Jump (key) " + NameToString( here.entityName ) + " -> " + NameToString( tag ) );
		area = mm.GetAreaFromWorldPath( theGame.GetWorld().GetDepotPath() );
		mm.UseMapPin( tag, true );
		mm.SetDesiredFastTravelPoint( tag, area );
		mm.PerformLocalFastTravelTeleport( tag );
		if ( !theGame.IsGameTimePaused() )
			theGame.SetGameTime( theGame.GetGameTime() + GameTimeCreate( 0, RoundF( RandF() * 4 ), RoundF( RandF() * 60 ), RoundF( RandF() * 60 ) ), true );
		mm.OnFastTravelInitiated( tag, area );
	}

	public function OnPathsWiped()
	{
		overlay.OnPathsWiped();
	}

	private function Evaluate( pos : Vector, worldPath : string, force : bool )
	{
		var target : Vector;
		var isUserPin, redirect, targetMoved : bool;
		var newPlan : SRPlan;
		var area : name;

		if ( !FindTarget( worldPath, pos, target, isUserPin ) )
		{
			if ( routerState != SRS_Idle || pins.HasOurPin() || overlay.IsDrawn() )
				Reset( "no target" );
			return;
		}

		targetMoved = VecDistance2D( target, lastTarget ) >= 1.0;
		if ( !force && !targetMoved && routerState != SRS_Idle && VecDistance2D( pos, lastEvalPos ) < MOVE_THRESHOLD )
			return;
		if ( targetMoved )
			pins.ResetOverride();
		lastEvalPos = pos;
		lastTarget = target;

		newPlan = SRPlanRoute( pos, target, SRCollectSignposts( worldPath ), settings.detour, settings.penalty, settings.minSaving, plan );

		if ( !newPlan.useSignposts )
		{
			ClearPins();
			overlay.Clear();
			if ( routerState != SRS_Direct )
				SRLog( "Direct: walk " + RoundF( newPlan.directCost ) );
			routerState = SRS_Direct;
			plan = newPlan;
			return;
		}

		pins.CheckUserOverride();
		redirect = settings.mode == 0 && !isUserPin && !pins.IsOverridden() && !pins.IsFailed();
		if ( redirect )
		{
			area = theGame.GetCommonMapManager().GetAreaFromWorldPath( worldPath, true );
			pins.PlaceAt( area, newPlan.entryPos );
		}
		else
		{
			ClearPins();
		}

		if ( settings.showLine )
			DrawDots( pos, newPlan.entryPos, newPlan.exitPos, target );
		else
			overlay.Clear();

		if ( routerState != SRS_Guiding || newPlan.entryTag != plan.entryTag || newPlan.exitTag != plan.exitTag )
			SRLog( "Guiding via " + NameToString( newPlan.entryTag ) + " -> " + NameToString( newPlan.exitTag )
				+ " route " + RoundF( newPlan.routeCost ) + " vs direct " + RoundF( newPlan.directCost ) );
		routerState = SRS_Guiding;
		plan = newPlan;
	}

	// Highlighted quest objective pin in this world (nearest if several); else the player's own waypoint.
	private function FindTarget( worldPath : string, pos : Vector, out target : Vector, out isUserPin : bool ) : bool
	{
		var mm : CCommonMapManager;
		var instances : array< SCommonMapPinInstance >;
		var i : int;
		var d, best : float;
		var found : bool;
		var area, currentArea : name;
		var x, y : float;

		mm = theGame.GetCommonMapManager();
		instances = mm.GetMapPinInstances( worldPath );
		for ( i = 0; i < instances.Size(); i += 1 )
		{
			if ( !instances[ i ].isHighlighted || !mm.IsQuestPinType( instances[ i ].type ) )
				continue;
			d = VecDistance2D( pos, instances[ i ].position );
			if ( !found || d < best )
			{
				found = true;
				best = d;
				target = instances[ i ].position;
			}
		}
		if ( found )
		{
			isUserPin = false;
			return true;
		}

		currentArea = mm.GetAreaFromWorldPath( worldPath, true );
		if ( pins.FindUserWaypoint( area, x, y ) && area == currentArea )
		{
			target = Vector( x, y, 0 );
			isUserPin = true;
			return true;
		}
		return false;
	}

	// Signpost Jump: the discovered signpost nearest the current target, unless that is the one at 'here'.
	public function FindJumpSignpost( here : name, out tag : name ) : bool
	{
		var worldPath : string;
		var target : Vector;
		var isUserPin : bool;
		var signposts : array< SRSignpost >;
		var i : int;
		var d, best : float;

		worldPath = theGame.GetWorld().GetDepotPath();
		if ( !FindTarget( worldPath, thePlayer.GetWorldPosition(), target, isUserPin ) )
			return false;
		signposts = SRCollectSignposts( worldPath );
		best = -1;
		for ( i = 0; i < signposts.Size(); i += 1 )
		{
			d = VecDistance2D( signposts[ i ].pos, target );
			if ( best < 0 || d < best )
			{
				best = d;
				tag = signposts[ i ].tag;
			}
		}
		return best >= 0 && tag != here;
	}

	private function IsPaused() : bool
	{
		return theGame.IsDialogOrCutscenePlaying() || theGame.IsBlackscreenOrFading()
			|| thePlayer.IsInInterior() || thePlayer.IsSailing();
	}

	private function OnTeleported()
	{
		Reset( "teleported" );
		lastEvalTime = theGame.GetEngineTimeAsSeconds();	// give the new area 2 s to stream in
	}

	// Detect a player-placed waypoint first, so Clear() never restores an old pin over it.
	private function ClearPins()
	{
		pins.CheckUserOverride();
		pins.Clear();
	}

	private function Reset( reason : string )
	{
		var empty : SRPlan;

		ClearPins();
		overlay.Clear();
		routerState = SRS_Idle;
		plan = empty;
		lastTarget = Vector( 0, 0, 0 );
		SRLog( "Reset: " + reason );
	}

	private function StateName() : string
	{
		if ( routerState == SRS_Guiding )
			return "GUIDING";
		if ( routerState == SRS_Direct )
			return "DIRECT";
		return "IDLE";
	}

	private function HandleDebugToggles()
	{
		if ( SRConsumeToggle( 'SRStatus' ) )
			SRNotify( "SR " + StateName() + " | " + settings.ToString()
				+ " | direct=" + RoundF( plan.directCost ) + " route=" + RoundF( plan.routeCost )
				+ " " + NameToString( plan.entryTag ) + "->" + NameToString( plan.exitTag )
				+ " | " + pins.ToString() + " line=" + SRBool( overlay.IsDrawn() ) + " wipes=" + overlay.GetWipes() + " sends=" + overlay.GetSends() );
		if ( SRConsumeToggle( 'SRSelfTest' ) )
			SRNotify( SRRunSelfTest() );
	}
}
