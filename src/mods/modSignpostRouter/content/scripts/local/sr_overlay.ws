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

	// -1 = opaque white and width 20 are verified visible on 5.0; Task 6 recalibrates to subtle green.
	private const var LINE_COLOR : int;			default LINE_COLOR = -1;
	private const var LINE_WIDTH : float;		default LINE_WIDTH = 20.0;
	private const var STEP : float;				default STEP = 15.0;
	private const var MIN_POINTS : int;			default MIN_POINTS = 12;
	private const var MAX_POINTS : int;			default MAX_POINTS = 120;
	private const var NUDGE_RANGE : float;		default NUDGE_RANGE = 100.0;
	private const var NAV_RADIUS : float;		default NAV_RADIUS = 0.4;
	private const var ID_ENTRY : int;			default ID_ENTRY = 778101;
	private const var ID_EXIT : int;			default ID_EXIT = 778102;

	public function Init( owner : CR4HudModuleMinimap2 )
	{
		minimap = owner;
	}

	public function IsDrawn() : bool
	{
		return drawn || pending;
	}

	// Verified in game: a DeleteMapPaths call wipes every path added in the same tick.
	// So a redraw deletes now and sends the new lines on the next tick. Call Flush() once per tick,
	// before anything else touches the overlay.
	public function Flush()
	{
		if ( pending && !deletedThisTick )
		{
			SendPath( ID_ENTRY, pendingEntry );
			SendPath( ID_EXIT, pendingExit );
			pending = false;
			drawn = true;
		}
		deletedThisTick = false;
	}

	// Verified in game: placing a map pin (and the game's own path refreshes) wipes all minimap paths.
	// Called from the DeleteMapPathsFromMinimap hook: re-send our last lines on a later tick.
	public function OnPathsWiped()
	{
		wipes += 1;
		if ( !drawn )
			return;
		drawn = false;
		pending = true;
		deletedThisTick = true;
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
		var ids : array< int >;

		pending = false;
		if ( !drawn || !minimap )
			return;
		ids.PushBack( ID_ENTRY );
		ids.PushBack( ID_EXIT );
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
