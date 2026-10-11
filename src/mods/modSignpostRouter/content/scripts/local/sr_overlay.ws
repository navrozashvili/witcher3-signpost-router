// Signpost Router - draws the suggested route on the minimap with AddMapPath (absolute world coords).

class SROverlay
{
	private var minimap : CR4HudModuleMinimap2;
	private var drawn : bool;
	private var pending : bool;
	private var deletedThisTick : bool;
	private var pendingEntry : array< Vector >;
	private var pendingExit : array< Vector >;
	private var wipes : int;
	private var sends : int;
	private var lastSendTime : float;
	private var curEntryId : int;
	private var curExitId : int;
	private var nextId : int;

	private const var RESEND_INTERVAL : float;	default RESEND_INTERVAL = 2.0;
	private const var ID_FIRST : int;			default ID_FIRST = 778100;
	private const var ID_LAST : int;			default ID_LAST = 799000;

	// -1 = opaque white and width 20 are verified visible on 5.0; Task 6 recalibrates to subtle green.
	private const var LINE_COLOR : int;			default LINE_COLOR = -1;
	private const var LINE_WIDTH : float;		default LINE_WIDTH = 20.0;
	private const var STEP : float;				default STEP = 15.0;
	private const var MIN_POINTS : int;			default MIN_POINTS = 12;
	private const var MAX_POINTS : int;			default MAX_POINTS = 120;
	private const var NUDGE_RANGE : float;		default NUDGE_RANGE = 100.0;
	private const var NAV_RADIUS : float;		default NAV_RADIUS = 0.4;

	public function Init( owner : CR4HudModuleMinimap2 )
	{
		minimap = owner;
	}

	public function IsDrawn() : bool
	{
		return drawn || pending;
	}

	// Verified in game:
	// - the minimap ignores AddMapPath for an id it already knows, so every send uses fresh ids;
	// - a DeleteMapPaths call wipes paths added in the same tick, so deletes and adds go in separate ticks;
	// - placing a map pin wipes the drawn lines, so they are re-sent every RESEND_INTERVAL seconds.
	// Call Flush() once per tick, before anything else touches the overlay.
	public function Flush()
	{
		var now : float;

		now = theGame.GetEngineTimeAsSeconds();
		if ( pending && !deletedThisTick )
		{
			nextId += 2;
			if ( nextId < ID_FIRST || nextId > ID_LAST )
				nextId = ID_FIRST;
			curEntryId = nextId;
			curExitId = nextId + 1;
			SendPath( curEntryId, pendingEntry );
			SendPath( curExitId, pendingExit );
			pending = false;
			drawn = true;
			lastSendTime = now;
			sends += 1;
		}
		else if ( drawn && now - lastSendTime >= RESEND_INTERVAL )
		{
			DeleteCurrent();
			pending = true;		// sent with fresh ids on the next tick
		}
		deletedThisTick = false;
	}

	// TEMPORARY diagnostic: send the current route legs once under fresh ids, no deletes.
	public function DebugSendRoute() : string
	{
		var e, x : int;

		e = pendingEntry.Size();
		x = pendingExit.Size();
		SendPath( 795001 + sends * 2, pendingEntry );
		SendPath( 795002 + sends * 2, pendingExit );
		sends += 1;
		if ( e > 0 )
			return "Route test: entry " + e + " pts from " + RoundF( pendingEntry[0].X ) + "," + RoundF( pendingEntry[0].Y )
				+ " to " + RoundF( pendingEntry[e - 1].X ) + "," + RoundF( pendingEntry[e - 1].Y ) + " | exit " + x + " pts";
		return "Route test: no route legs stored (entry 0 pts, exit " + x + " pts)";
	}

	public function GetSends() : int
	{
		return sends;
	}

	// Verified in game: placing a map pin (and the game's own path refreshes) wipes all minimap paths.
	// Called from the DeleteMapPathsFromMinimap hook: re-send our last lines on a later tick.
	public function OnPathsWiped()
	{
		wipes += 1;
		lastSendTime = -1000;	// force a fresh-id resend on the next ticks
	}

	public function GetWipes() : int
	{
		return wipes;
	}

	public function Draw( player : Vector, entryPos : Vector, exitPos : Vector, target : Vector )
	{
		Clear();
		pendingEntry = BuildLeg( player, entryPos, true, player );
		pendingExit = BuildLeg( exitPos, target, false, player );
		pending = true;
		if ( !deletedThisTick )
			Flush();
	}

	public function Clear()
	{
		pending = false;
		DeleteCurrent();
	}

	private function DeleteCurrent()
	{
		var ids : array< int >;

		if ( !drawn || !minimap )
			return;
		ids.PushBack( curEntryId );
		ids.PushBack( curExitId );
		minimap.DeleteMapPaths( ids );
		drawn = false;
		deletedThisTick = true;
	}

	private function SendPath( id : int, points : array< Vector > )
	{
		var path : SMapPathInstance;

		if ( !minimap || points.Size() < 2 )
			return;
		path.id = id;
		path.position = Vector( 0, 0, 0 );
		path.color = LINE_COLOR;
		path.lineWidth = LINE_WIDTH;
		path.splinePoints = points;
		minimap.AddMapPath( path );
	}

	// Evenly spaced points from 'from' to 'to'. With nudge, points within NUDGE_RANGE of the player are
	// shifted sideways around navmesh obstacles (navmesh is only loaded near the player).
	private function BuildLeg( from : Vector, to : Vector, nudge : bool, player : Vector ) : array< Vector >
	{
		var points : array< Vector >;
		var world : CWorld;
		var count, i : int;
		var p, prev, dir, side : Vector;

		world = theGame.GetWorld();
		count = RoundF( VecDistance2D( from, to ) / STEP ) + 1;
		if ( count < MIN_POINTS )
			count = MIN_POINTS;
		if ( count > MAX_POINTS )
			count = MAX_POINTS;

		dir = VecNormalize2D( to - from );
		side = Vector( -dir.Y, dir.X, 0 );
		prev = from;
		points.PushBack( from );
		for ( i = 1; i < count - 1; i += 1 )
		{
			p = from + ( to - from ) * ( (float)i / (float)( count - 1 ) );
			if ( nudge && world && VecDistance2D( p, player ) < NUDGE_RANGE )
				p = NudgePoint( world, prev, p, side );
			points.PushBack( p );
			prev = p;
		}
		points.PushBack( to );
		return points;
	}

	private function NudgePoint( world : CWorld, prev : Vector, p : Vector, side : Vector ) : Vector
	{
		var offsets : array< float >;
		var cand : Vector;
		var i : int;

		if ( world.NavigationLineTest( prev, p, NAV_RADIUS ) )
			return p;
		offsets.PushBack( 5 );
		offsets.PushBack( -5 );
		offsets.PushBack( 10 );
		offsets.PushBack( -10 );
		offsets.PushBack( 15 );
		offsets.PushBack( -15 );
		for ( i = 0; i < offsets.Size(); i += 1 )
		{
			cand = p + side * offsets[ i ];
			if ( world.NavigationLineTest( prev, cand, NAV_RADIUS ) )
				return cand;
		}
		return p;
	}
}
