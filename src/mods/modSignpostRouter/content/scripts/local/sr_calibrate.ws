// Signpost Router - draws 5 test lines north of the player, 15 m apart (west to east), to find the colour encoding.
// 1 white -1 (control) | 2 0xFFFF0000 | 3 0xFF0000FF | 4 0x00FF00FF | 5 0x8000FF00 (half-alpha green if ARGB)

function SRCalibrate( minimap : CR4HudModuleMinimap2 )
{
	var colors : array< int >;
	var path : SMapPathInstance;
	var base, a, b : Vector;
	var i, j : int;

	colors.PushBack( -1 );
	colors.PushBack( -65536 );
	colors.PushBack( -16776961 );
	colors.PushBack( 16711935 );
	colors.PushBack( -2147418368 );

	base = thePlayer.GetWorldPosition();
	for ( i = 0; i < colors.Size(); i += 1 )
	{
		a = base + Vector( ( (float)( i - 2 ) ) * 15.0, 5, 0 );
		b = a + Vector( 0, 60, 0 );
		path.id = 778201 + i;
		path.position = Vector( 0, 0, 0 );
		path.color = colors[ i ];
		path.lineWidth = 20.0;
		path.splinePoints.Clear();
		for ( j = 0; j < 12; j += 1 )
			path.splinePoints.PushBack( a + ( b - a ) * ( (float)j / 11.0 ) );
		minimap.AddMapPath( path );
	}
	SRNotify( "SR calibrate: 5 lines north of you, west->east = 1..5" );
}
