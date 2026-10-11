// Signpost Router - THROWAWAY PROBE (5.0 feasibility test). Delete after testing.
// Plain WitcherScript, no annotations: tests that loose script mods still compile.

exec function srprobe()
{
	SRProbe_Run( "console" );
}

function SRProbe_Run( trigger : string )
{
	var mm : CCommonMapManager;
	var hud : CR4ScriptedHud;
	var minimap : CR4HudModuleMinimap2;
	var pins : array< SEntityMapPinInfo >;
	var worldPath : string;
	var area : name;
	var playerPos, bestPos, rel : Vector;
	var bestName : name;
	var bestDist, d : float;
	var i, discovered : int;
	var idToAdd, idToRemove, toggleRes : int;
	var count, pid, ptype : int;
	var parea : name;
	var px, py : float;
	var report : string;

	mm = theGame.GetCommonMapManager();
	hud = (CR4ScriptedHud)theGame.GetHud();
	if ( hud )
	{
		minimap = (CR4HudModuleMinimap2)hud.GetHudModule( "Minimap2Module" );
	}
	worldPath = theGame.GetWorld().GetDepotPath();
	area = mm.GetAreaFromWorldPath( worldPath, true );
	playerPos = thePlayer.GetWorldPosition();

	// 1) nearest discovered signpost in the current world
	bestDist = 1000000.0;
	pins = mm.GetEntityMapPins( worldPath );
	for ( i = 0; i < pins.Size(); i += 1 )
	{
		if ( pins[ i ].entityType != 'RoadSign' )
			continue;
		if ( !mm.IsEntityMapPinDiscovered( pins[ i ].entityName ) )
			continue;
		discovered += 1;
		d = VecDistance2D( playerPos, pins[ i ].entityPosition );
		if ( d < bestDist )
		{
			bestDist = d;
			bestName = pins[ i ].entityName;
			bestPos = pins[ i ].entityPosition;
		}
	}

	report = "SR probe (" + trigger + ") area=" + NameToString( area ) + " signposts=" + discovered;

	if ( discovered == 0 )
	{
		SRProbe_Report( report + " | no discovered signpost here" );
		return;
	}
	report += " nearest=" + NameToString( bestName ) + " " + RoundF( bestDist ) + "m";

	// 2) minimap lines: GREEN = absolute world coords, PINK = relative to path.position
	if ( minimap )
	{
		// v2: alpha-channel colours, wider lines, each variant offset sideways by 4m steps
		// RED    = absolute coords, ARGB 0xFFFF0000, width 3
		// BLUE   = absolute coords, ARGB 0xFF0000FF (or red if engine is ABGR), width 10
		// YELLOW = relative coords,  ARGB 0xFFFFFF00, width 10
		// WHITE  = absolute coords, 12 points, ARGB 0xFFFFFFFF, width 20
		rel = bestPos - playerPos;
		SRProbe_Line( minimap, 778001, playerPos, bestPos, 0,  -65536,    3.0,  false, 3 );
		SRProbe_Line( minimap, 778002, playerPos, bestPos, 4,  -16776961, 10.0, false, 3 );
		SRProbe_Line( minimap, 778003, playerPos, bestPos, 8,  -256,      10.0, true,  3 );
		SRProbe_Line( minimap, 778004, playerPos, bestPos, 12, -1,        20.0, false, 12 );
		report += " | 4 lines sent";
	}
	else
	{
		report += " | minimap module NOT found";
	}

	// 3) waypoint pin (type 0) on the signpost
	bestPos.Z = 0;
	toggleRes = mm.ToggleUserMapPin( area, bestPos, 0, false, true, idToAdd, idToRemove );
	count = mm.GetUserMapPinCount();
	report += " | pin res=" + toggleRes + " add=" + idToAdd + " rem=" + idToRemove + " count=" + count;
	for ( i = 0; i < count; i += 1 )
	{
		if ( mm.GetUserMapPinByIndex( i, pid, parea, px, py, ptype ) )
		{
			report += " [" + pid + " t" + ptype + " " + RoundF( px ) + "," + RoundF( py ) + "]";
		}
	}

	SRProbe_Report( report );
}

function SRProbe_Line( minimap : CR4HudModuleMinimap2, id : int, from, to : Vector, offset : float, color : int, width : float, relative : bool, points : int )
{
	var path : SMapPathInstance;
	var side, p : Vector;
	var i : int;

	side = VecNormalize2D( to - from );
	side = Vector( -side.Y, side.X, 0 ) * offset;
	from += side;
	to += side;

	path.id = id;
	path.color = color;
	path.lineWidth = width;
	if ( relative )
		path.position = from;
	else
		path.position = Vector( 0, 0, 0 );

	for ( i = 0; i < points; i += 1 )
	{
		p = from + ( to - from ) * ( (float)i / (float)( points - 1 ) );
		if ( relative )
			p -= from;
		path.splinePoints.PushBack( p );
	}
	minimap.AddMapPath( path );
}

function SRProbe_Report( text : string )
{
	LogChannel( 'SRProbe', text );
	theGame.GetGuiManager().ShowNotification( text );
}

exec function srprobeclear()
{
	var hud : CR4ScriptedHud;
	var minimap : CR4HudModuleMinimap2;
	var ids : array< int >;

	hud = (CR4ScriptedHud)theGame.GetHud();
	minimap = (CR4HudModuleMinimap2)hud.GetHudModule( "Minimap2Module" );
	ids.PushBack( 778001 );
	ids.PushBack( 778002 );
	ids.PushBack( 778003 );
	ids.PushBack( 778004 );
	minimap.DeleteMapPaths( ids );
}
