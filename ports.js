window.setupPorts = function (app) {
  // Web Audio context for metronome click
  const context = new (window.AudioContext || window.webkitAudioContext)();
  function playClick(primary) {
    const osc = context.createOscillator();
    const envelope = context.createGain();
    osc.type = "square";
    osc.frequency.value = primary ? 1440 : 960; // higher pitch for downbeat
    envelope.gain.value = primary ? 0.25 : 0.09;
    osc.connect(envelope);
    envelope.connect(context.destination);
    osc.start();
    envelope.gain.setTargetAtTime(0, context.currentTime, 0.01);
    osc.stop(context.currentTime + 0.08);
  }

  if (app.ports && app.ports.beatClick) {
    app.ports.beatClick.subscribe((beatType) => {
      if (context.state === "suspended") context.resume();
      playClick(beatType === "primary");
    });
  }
};
