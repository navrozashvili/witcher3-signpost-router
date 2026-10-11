// Signpost Router - draws the suggested route on the minimap as dots, with AddMapPath (absolute world coords).
//
// Minimap path rules, all verified in game on 5.0:
// 1. DeleteMapPaths of an existing path wipes EVERY path; paths added later draw fine.
// 2. Only the last AddMapPath sent in a frame takes effect, so pieces go out one per frame.
// 3. AddMapPath with an id the minimap already knows is ignored, so every piece gets a fresh id.
// A redraw is therefore: delete, wait DELETE_GAP, then send the queued pieces one per frame.

struct SRDot
{
	var from : Vector;
	var to : Vector;
	var color : int;
	var width : float;
}

class SROverlay
{
	private var minimap : CR4HudModuleMinimap2;
	private var queue : array< SRDot >;
	private var sentIds : array< int >;
	private var qIndex : int;
	private var phase : int;				// 0 idle | 1 waiting after a delete | 2 sending one piece per frame
	private var phaseTime : float;
	private var nextId : int;
	private var wipes : int;
	private var sends : int;

	private const var DELETE_GAP : float;		default DELETE_GAP = 0.3;
	private const var ID_FIRST : int;			default ID_FIRST = 778100;
	private const var ID_LAST : int;			default ID_LAST = 799000;

	// Dots: -1 = opaque white (verified visible). Recoloured after the calibration test.
	private const var DOT_COLOR : int;			default DOT_COLOR = -1;
	private const var DOT_WIDTH : float;		default DOT_WIDTH = 20.0;
	private const var DOT_LEN : float;			default DOT_LEN = 2.0;
	private const var DOT_SPACING : float;		default DOT_SPACING = 8.0;
	private const var DOT_RANGE : float;		default DOT_RANGE = 150.0;	// only dots this close to the player are drawn
	private const var MAX_DOTS : int;			default MAX_DOTS = 25;

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
		return sentIds.Size() > 0 || phase != 0;
	}

	// Call once per tick, before anything else touches the overlay.
	public function Flush()
	{
		if ( phase == 1 && theGame.GetEngineTimeAsSeconds() - phaseTime >= DELETE_GAP )
		{
			phase = 2;
			qIndex = 0;
		}
		if ( phase != 2 )
			return;

		if ( qIndex < queue.Size() )
		{
			SendDot( queue[ qIndex ] );
			qIndex += 1;
		}
		if ( qIndex >= queue.Size() )
		{
			phase = 0;
			sends += 1;
		}
	}

	public function Draw( player : Vector, entryPos : Vector, exitPos : Vector, target : Vector )
	{
		queue.Clear();
		AddDots( BuildLeg( player, entryPos, true, player ), player );
		AddDots( BuildLeg( exitPos, target, false, player ), player );
		StartSend();
	}

	// Five long test lines north of the player, west -> east, one colour encoding each.
	// 1 white -1 (control) | 2 0xFFFF0000 | 3 0xFF0000FF | 4 0x00FF00FF | 5 0x8000FF00
	public function Calibrate( base : Vector )
	{
		var colors : array< int >;
		var line : SRDot;
		var i : int;

		colors.PushBack( -1 );
		colors.PushBack( -65536 );
		colors.PushBack( -16776961 );
		colors.PushBack( 16711935 );
		colors.PushBack( -2147418368 );

		queue.Clear();
		for ( i = 0; i < colors.Size(); i += 1 )
		{
			line.from = base + Vector( ( (float)( i - 2 ) ) * 15.0, 5, 0 );
			line.to = line.from + Vector( 0, 60, 0 );
			line.color = colors[ i ];
			line.width = 20.0;
			queue.PushBack( line );
		}
		StartSend();
	}

	public function Clear()
	{
		phase = 0;
		queue.Clear();
		DeleteCurrent();
	}

	// Called from the DeleteMapPathsFromMinimap hook: the game wiped paths, so send ours again.
	public function OnPathsWiped()
	{
		wipes += 1;
		if ( sentIds.Size() > 0 )
		{
			sentIds.Clear();
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

	private function StartSend()
	{
		DeleteCurrent();
		phase = 1;
		phaseTime = theGame.GetEngineTimeAsSeconds();
	}

	private function DeleteCurrent()
	{
		if ( sentIds.Size() == 0 || !minimap )
			return;
		minimap.DeleteMapPaths( sentIds );
		sentIds.Clear();
	}

	private function SendDot( dot : SRDot )
	{
		var path : SMapPathInstance;

		if ( !minimap )
			return;
		nextId += 1;
		if ( nextId < ID_FIRST || nextId > ID_LAST )
			nextId = ID_FIRST;
		path.id = nextId;
		path.position = Vector( 0, 0, 0 );
		path.color = dot.color;
		path.lineWidth = dot.width;
		path.splinePoints.PushBack( dot.from );
		path.splinePoints.PushBack( ( dot.from + dot.to ) * 0.5 );
		path.splinePoints.PushBack( dot.to );
		minimap.AddMapPath( path );
		sentIds.PushBack( nextId );
	}

	// Queue a short dash every DOT_SPACING metres along the polyline, only within DOT_RANGE of the player.
	private function AddDots( points : array< Vector >, player : Vector )
	{
		var dot : SRDot;
		var a, b, dir, p : Vector;
		var segLen, along : float;
		var i : int;

		dot.color = DOT_COLOR;
		dot.width = DOT_WIDTH;
		along = DOT_SPACING * 0.5;
		for ( i = 0; i + 1 < points.Size() && queue.Size() < MAX_DOTS; i += 1 )
		{
			a = points[ i ];
			b = points[ i + 1 ];
			segLen = VecDistance2D( a, b );
			if ( segLen <= 0 )
				continue;
			dir = VecNormalize2D( b - a );
			while ( along < segLen && queue.Size() < MAX_DOTS )
			{
				p = a + dir * along;
				if ( VecDistance2D( p, player ) <= DOT_RANGE )
				{
					dot.from = p;
					dot.to = p + dir * DOT_LEN;
					queue.PushBack( dot );
				}
				along += DOT_SPACING;
			}
			along -= segLen;
		}
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
