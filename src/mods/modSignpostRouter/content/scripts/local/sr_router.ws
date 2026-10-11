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
	private var wtStage : int;
	private var wtTime : float;
	private var wtRun : int;
	private var wtBase : Vector;

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
		routerState = SRS_Idle;
		SRLog( "Router initialised: " + settings.ToString() );
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

		// Temporary wipe-test sequencer (see sr_linetest.ws).
		if ( wtStage > 0 && wtStage < 3 && theGame.GetEngineTimeAsSeconds() - wtTime >= 2.0 )
		{
			wtStage += 1;
			wtTime = theGame.GetEngineTimeAsSeconds();
			SRWipeTestStep( minimap, wtStage, wtRun, wtBase );
		}

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
			overlay.Draw( pos, newPlan.entryPos, newPlan.exitPos, target );
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
		var pp : Vector;

		if ( SRConsumeToggle( 'SRStatus' ) )
			SRNotify( "SR " + StateName() + " | " + settings.ToString()
				+ " | direct=" + RoundF( plan.directCost ) + " route=" + RoundF( plan.routeCost )
				+ " " + NameToString( plan.entryTag ) + "->" + NameToString( plan.exitTag )
				+ " | " + pins.ToString() + " line=" + SRBool( overlay.IsDrawn() ) + " wipes=" + overlay.GetWipes() + " sends=" + overlay.GetSends() );
		if ( SRConsumeToggle( 'SRSelfTest' ) )
			SRNotify( SRRunSelfTest() );
			if ( SRConsumeToggle( 'SRCalibrate' ) )
				SRCalibrate( minimap );
			if ( SRConsumeToggle( 'SRLineTest' ) )
				SRLineTest( minimap );
			if ( SRConsumeToggle( 'SRRouteTest' ) )
			{
				pp = thePlayer.GetWorldPosition();
				SRNotify( overlay.DebugSendRoute() + " | player " + RoundF( pp.X ) + "," + RoundF( pp.Y ) );
			}
			if ( SRConsumeToggle( 'SRWipeTest' ) )
			{
				wtRun += 1;
				wtStage = 1;
				wtTime = theGame.GetEngineTimeAsSeconds();
				wtBase = thePlayer.GetWorldPosition();
				SRWipeTestStep( minimap, wtStage, wtRun, wtBase );
			}
	}
}
