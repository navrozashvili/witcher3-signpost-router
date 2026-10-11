// Signpost Router - TEMPORARY diagnostic: which AddMapPath usage renders? Remove after debugging.
// Four 60 m lines north of the player, west -> east:
// A probe recipe (12 points pushed into the struct) | B 12 points assigned as an array
// C 120 points pushed | D like A, but deleted and re-added with the same id in the same frame

function SRLineTest( minimap : CR4HudModuleMinimap2 )
{
	var path : SMapPathInstance;
	var pts : array< Vector >;
	var ids : array< int >;
	var base, a, b : Vector;
	var j : int;

	base = thePlayer.GetWorldPosition();

	// A
	a = base + Vector( -30, 5, 0 );
	b = a + Vector( 0, 60, 0 );
	path.id = 778301;
	path.position = Vector( 0, 0, 0 );
	path.color = -1;
	path.lineWidth = 20.0;
	path.splinePoints.Clear();
	for ( j = 0; j < 12; j += 1 )
		path.splinePoints.PushBack( a + ( b - a ) * ( (float)j / 11.0 ) );
	minimap.AddMapPath( path );

	// B
	a = base + Vector( -10, 5, 0 );
	b = a + Vector( 0, 60, 0 );
	for ( j = 0; j < 12; j += 1 )
		pts.PushBack( a + ( b - a ) * ( (float)j / 11.0 ) );
	path.id = 778302;
	path.splinePoints = pts;
	minimap.AddMapPath( path );

	// C
	a = base + Vector( 10, 5, 0 );
	b = a + Vector( 0, 60, 0 );
	path.id = 778303;
	path.splinePoints.Clear();
	for ( j = 0; j < 120; j += 1 )
		path.splinePoints.PushBack( a + ( b - a ) * ( (float)j / 119.0 ) );
	minimap.AddMapPath( path );

	// D
	a = base + Vector( 30, 5, 0 );
	b = a + Vector( 0, 60, 0 );
	path.id = 778304;
	path.splinePoints.Clear();
	for ( j = 0; j < 12; j += 1 )
		path.splinePoints.PushBack( a + ( b - a ) * ( (float)j / 11.0 ) );
	minimap.AddMapPath( path );
	ids.PushBack( 778304 );
	minimap.DeleteMapPaths( ids );
	minimap.AddMapPath( path );

	SRNotify( "SR line test: 4 lines north, west->east = A B C D" );
}
