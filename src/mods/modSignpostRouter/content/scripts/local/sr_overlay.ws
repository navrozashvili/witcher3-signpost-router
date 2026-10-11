// Signpost Router - draws the suggested route on the minimap with AddMapPath (absolute world coords).
//
// Minimap path rules, all verified in game on 5.0:
// 1. DeleteMapPaths of an existing path wipes EVERY path; paths added later draw fine.
// 2. Only the last AddMapPath sent in a frame takes effect, so the two legs go out on separate frames.
// 3. AddMapPath with an id the minimap already knows is ignored, so every send uses fresh ids.
// A redraw is therefore: delete, wait DELETE_GAP, send the entry leg, send the exit leg next frame.

class SROverlay
{
	private var minimap : CR4HudModuleMinimap2;
	private var drawn : bool;
	private var phase : int;				// 0 idle | 1 waiting after a delete | 2 send entry leg | 3 send exit leg
	private var phaseTime : float;
	private var pendingEntry : array< Vector >;
	private var pendingExit : array< Vector >;
	private var wipes : int;
	private var sends : int;
	private var curEntryId : int;
	private var curExitId : int;
	private var nextId : int;

	private const var DELETE_GAP : float;		default DELETE_GAP = 0.3;
	private const var ID_FIRST : int;			default ID_FIRST = 778100;
	private const var ID_LAST : int;			default ID_LAST = 799000;

	// -1 = opaque white and width 20 are verified visible on 5.0.
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
		return drawn || phase != 0;
	}

	// Call once per tick, before anything else touches the overlay.
	public function Flush()
	{
		if ( phase == 1 && theGame.GetEngineTimeAsSeconds() - phaseTime >= DELETE_GAP )
			phase = 2;

		if ( phase == 2 )
		{
			nextId += 2;
			if ( nextId < ID_FIRST || nextId > ID_LAST )
				nextId = ID_FIRST;
			curEntryId = nextId;
			curExitId = nextId + 1;
			SendPath( curEntryId, pendingEntry );
			drawn = true;
			sends += 1;
			phase = 3;
		}
		else if ( phase == 3 )
		{
			SendPath( curExitId, pendingExit );
			phase = 0;
		}
	}

	public function Draw( player : Vector, entryPos : Vector, exitPos : Vector, target : Vector )
	{
		pendingEntry = BuildLeg( player, entryPos, true, player );
		pendingExit = BuildLeg( exitPos, target, false, player );
		if ( drawn )
		{
			DeleteCurrent();
			phase = 1;
			phaseTime = theGame.GetEngineTimeAsSeconds();
		}
		else if ( phase != 3 )
		{
			// Nothing on screen yet. Still wait DELETE_GAP: the router may have just placed a pin,
			// and a pin change wipes paths too.
			phase = 1;
			phaseTime = theGame.GetEngineTimeAsSeconds();
		}
	}

	public function Clear()
	{
		phase = 0;
		DeleteCurrent();
	}

	// Called from the DeleteMapPathsFromMinimap hook: the game wiped paths, so send ours again.
	public function OnPathsWiped()
	{
		wipes += 1;
		if ( drawn )
		{
			drawn = false;
			phase = 1;
			phaseTime = theGame.GetEngineTimeAsSeconds();
		}
	}

	public function GetWipes() : int
	{
		return wipes;
	}

	public function GetSends() : int
	{
		return sends;
	}

	// TEMPORARY diagnostic: send the current route legs once, one per frame via the normal path.
	public function DebugSendRoute() : string
	{
		var e : int;

		e = pendingEntry.Size();
		if ( phase == 0 )
			phase = 2;
		if ( e > 0 )
			return "Route test: entry " + e + " pts from " + RoundF( pendingEntry[0].X ) + "," + RoundF( pendingEntry[0].Y )
				+ " to " + RoundF( pendingEntry[e - 1].X ) + "," + RoundF( pendingEntry[e - 1].Y ) + " | exit " + pendingExit.Size() + " pts";
		return "Route test: no route legs stored";
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
