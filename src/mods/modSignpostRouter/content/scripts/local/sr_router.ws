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
	private var state : ESRState;
	private var plan : SRPlan;
	private var lastEvalTime : float;
	private var lastEvalPos : Vector;
	private var lastTarget : Vector;
	private var lastTickPos : Vector;
	private var lastWorldPath : string;
	private var adopted : bool;
	private var pendingForce : bool;

	private const var EVAL_INTERVAL : float;		default EVAL_INTERVAL = 2.0;
	private const var MOVE_THRESHOLD : float;		default MOVE_THRESHOLD = 20.0;
	private const var TELEPORT_THRESHOLD : float;	default TELEPORT_THRESHOLD = 300.0;

	public function Init( owner : CR4HudModuleMinimap2 )
	{
		minimap = owner;
		settings = new SRSettings in this;
		pins = new SRPinManager in this;
		overlay = new SROverlay in this;
		overlay.Init( owner );
		settings.Load();
		state = SRS_Idle;
		SRLog( "Router initialised: " + settings.ToString() );
	}

	public function Tick()
	{
		var now : float;
		var pos : Vector;
		var worldPath : string;
		var settingsChanged : bool;

		pos = thePlayer.GetWorldPosition();
		worldPath = theGame.GetWorld().GetDepotPath();

		// Cheap every-tick check: a big jump or a world change means fast travel (or a load).
		if ( lastWorldPath != "" && ( worldPath != lastWorldPath || VecDistance2D( pos, lastTickPos ) > TELEPORT_THRESHOLD ) )
			OnTeleported();
		lastTickPos = pos;
		lastWorldPath = worldPath;

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
			if ( state != SRS_Idle || pins.HasOurPin() || overlay.IsDrawn() )
				Reset( "disabled" );
			return;
		}
		if ( IsPaused() )
			return;

		Evaluate( pos, worldPath, pendingForce );
		pendingForce = false;
	}

	private function Evaluate( pos : Vector, worldPath : string, force : bool )
	{
		var target : Vector;
		var isUserPin, redirect, targetMoved : bool;
		var newPlan : SRPlan;
		var area : name;

		if ( !FindTarget( worldPath, pos, target, isUserPin ) )
		{
			if ( state != SRS_Idle || pins.HasOurPin() || overlay.IsDrawn() )
				Reset( "no target" );
			return;
		}

		targetMoved = VecDistance2D( target, lastTarget ) >= 1.0;
		if ( !force && !targetMoved && state != SRS_Idle && VecDistance2D( pos, lastEvalPos ) < MOVE_THRESHOLD )
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
			if ( state != SRS_Direct )
				SRLog( "Direct: walk " + RoundF( newPlan.directCost ) );
			state = SRS_Direct;
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
			overlay.Draw( pos, newPlan.entryPos, newPlan.exitPos, target );
		else
			overlay.Clear();

		if ( state != SRS_Guiding || newPlan.entryTag != plan.entryTag || newPlan.exitTag != plan.exitTag )
			SRLog( "Guiding via " + NameToString( newPlan.entryTag ) + " -> " + NameToString( newPlan.exitTag )
				+ " route " + RoundF( newPlan.routeCost ) + " vs direct " + RoundF( newPlan.directCost ) );
		state = SRS_Guiding;
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
		state = SRS_Idle;
		plan = empty;
		lastTarget = Vector( 0, 0, 0 );
		SRLog( "Reset: " + reason );
	}

	private function StateName() : string
	{
		if ( state == SRS_Guiding )
			return "GUIDING";
		if ( state == SRS_Direct )
			return "DIRECT";
		return "IDLE";
	}

	private function HandleDebugToggles()
	{
		if ( SRConsumeToggle( 'SRStatus' ) )
			SRNotify( "SR " + StateName() + " | " + settings.ToString()
				+ " | direct=" + RoundF( plan.directCost ) + " route=" + RoundF( plan.routeCost )
				+ " " + NameToString( plan.entryTag ) + "->" + NameToString( plan.exitTag )
				+ " | " + pins.ToString() + " line=" + SRBool( overlay.IsDrawn() ) );
		if ( SRConsumeToggle( 'SRSelfTest' ) )
			SRNotify( SRRunSelfTest() );
			if ( SRConsumeToggle( 'SRCalibrate' ) )
				SRCalibrate( minimap );
	}
}
