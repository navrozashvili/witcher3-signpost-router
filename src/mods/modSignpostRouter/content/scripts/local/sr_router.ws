// Signpost Router - orchestration. (Task 1 stub: settings + status only.)

class SRRouter
{
	private var minimap : CR4HudModuleMinimap2;
	private var settings : SRSettings;
	private var lastEvalTime : float;

	private const var EVAL_INTERVAL : float;	default EVAL_INTERVAL = 2.0;

	public function Init( owner : CR4HudModuleMinimap2 )
	{
		minimap = owner;
		settings = new SRSettings in this;
		settings.Load();
		SRLog( "Router initialised: " + settings.ToString() );
	}

	public function Tick()
	{
		var now : float;

		now = theGame.GetEngineTimeAsSeconds();
		if ( now - lastEvalTime < EVAL_INTERVAL )
			return;
		lastEvalTime = now;

		settings.Load();
		HandleDebugToggles();
	}

	private function HandleDebugToggles()
	{
		if ( SRConsumeToggle( 'SRStatus' ) )
			SRNotify( "Signpost Router: " + settings.ToString() );
	}
}
