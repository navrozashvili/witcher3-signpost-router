// Signpost Router - TEMPORARY diagnostic: which AddMapPath usage renders? Remove after debugging.
// Four 60 m lines north of the player, west -> east:
// A probe recipe (12 points pushed into the struct) | B 12 points assigned as an array
// C 120 points pushed | D like A, but deleted and re-added with the same id in the same frame

function SRLineTest( minimap : CR4HudModuleMinimap2 )
{
	var path : SMapPathInstance;
	var pts : array< Vector >;
	var base, a, b, side : Vector;
	var sps : array< SRSignpost >;
	var j, best : int;

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

	// E: exact replica of the probe line that rendered (player + 12 m sideways -> nearest signpost, 12 points)
	sps = SRCollectSignposts( theGame.GetWorld().GetDepotPath() );
	best = -1;
	for ( j = 0; j < sps.Size(); j += 1 )
	{
		if ( best < 0 || VecDistance2D( base, sps[ j ].pos ) < VecDistance2D( base, sps[ best ].pos ) )
			best = j;
	}
	if ( best >= 0 )
	{
		side = VecNormalize2D( sps[ best ].pos - base );
		side = Vector( -side.Y, side.X, 0 ) * 12.0;
		a = base + side;
		b = sps[ best ].pos + side;
		path.id = 778305;
		path.splinePoints.Clear();
		for ( j = 0; j < 12; j += 1 )
			path.splinePoints.PushBack( a + ( b - a ) * ( (float)j / 11.0 ) );
		minimap.AddMapPath( path );
	}

	// F: long line, 300 m due north from the player, 12 points
	a = base;
	b = a + Vector( 0, 300, 0 );
	path.id = 778306;
	path.splinePoints.Clear();
	for ( j = 0; j < 12; j += 1 )
		path.splinePoints.PushBack( a + ( b - a ) * ( (float)j / 11.0 ) );
	minimap.AddMapPath( path );

	if ( best >= 0 )
		SRNotify( "SR line test: A-C short lines north; E to nearest signpost (" + RoundF( VecDistance2D( base, sps[ best ].pos ) ) + " m); F 300 m north" );
	else
		SRNotify( "SR line test: A-C short lines north; E skipped (no signpost); F 300 m north" );
}
