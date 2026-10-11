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

	private const var DELETE_GAP : float;		default DELETE_GAP = 0.1;
	private const var ID_FIRST : int;			default ID_FIRST = 778100;
	private const var ID_LAST : int;			default ID_LAST = 799000;

	// Colour format is ARGB (verified with the calibration test). 0xFF2E9A48 = dark green, opaque.
	// Lengths below are at vanilla zoom (33 m radius) and scale with the minimap zoom.
	private const var DOT_COLOR : int;			default DOT_COLOR = -13723064;
	private const var DOT_WIDTH : float;		default DOT_WIDTH = 14.0;
	private const var DOT_LEN : float;			default DOT_LEN = 3.0;
	private const var DOT_SPACING : float;		default DOT_SPACING = 10.0;
	private const var DOT_RANGE : float;		default DOT_RANGE = 45.0;	// a bit beyond the 33 m vanilla radius
	private const var MAX_DOTS : int;			default MAX_DOTS = 40;

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

	public function IsBusy() : bool
	{
		return phase != 0;
	}

	// Dots are anchored to the signposts (counted from the signpost end of each leg), so a redraw after
	// walking puts them in the same world positions. The ones nearest the player are sent first.
	public function Draw( player : Vector, entryPos : Vector, exitPos : Vector, target : Vector )
	{
		var scale : float;
		var near : array< SRDot >;
		var i : int;

		scale = ZoomScale();
		queue.Clear();
		near = AnchoredDots( BuildLeg( entryPos, player, true, player ), player, scale );
		for ( i = near.Size() - 1; i >= 0; i -= 1 )
			queue.PushBack( near[ i ] );
		near = AnchoredDots( BuildLeg( exitPos, target, false, player ), player, scale );
		for ( i = 0; i < near.Size(); i += 1 )
			queue.PushBack( near[ i ] );
		StartSend();
	}

	// 1 at vanilla zoom; larger when the minimap is zoomed out (e.g. by the Minimap Zoom mod).
	public function ZoomScale() : float
	{
		var hud : CR4ScriptedHud;
		var zoom : float;

		hud = (CR4ScriptedHud)theGame.GetHud();
		if ( !hud )
			return 1.0;
		zoom = hud.GetMinimapZoom();
		if ( zoom <= 0 )
			return 1.0;
		return ClampF( 1.0 / zoom, 1.0, 8.0 );
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

	// A short dash every spacing metres along the polyline, counted from points[0] so the positions stay
	// put between redraws. Only dashes within range of the player are returned (at most MAX_DOTS).
	private function AnchoredDots( points : array< Vector >, player : Vector, scale : float ) : array< SRDot >
	{
		var result : array< SRDot >;
		var dot : SRDot;
		var a, b, dir, p : Vector;
		var segLen, along, spacing, range : float;
		var i : int;

		spacing = DOT_SPACING * scale;
		range = DOT_RANGE * scale;
		dot.color = DOT_COLOR;
		dot.width = DOT_WIDTH;
		along = spacing;
		for ( i = 0; i + 1 < points.Size() && result.Size() < MAX_DOTS; i += 1 )
		{
			a = points[ i ];
			b = points[ i + 1 ];
			segLen = VecDistance2D( a, b );
			if ( segLen <= 0 )
				continue;
			dir = VecNormalize2D( b - a );
			while ( along < segLen && result.Size() < MAX_DOTS )
			{
				p = a + dir * along;
				if ( VecDistance2D( p, player ) <= range )
				{
					dot.from = p;
					dot.to = p + dir * ( DOT_LEN * scale );
					result.PushBack( dot );
				}
				along += spacing;
			}
			along -= segLen;
		}
		return result;
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
