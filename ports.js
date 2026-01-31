window.setupPorts = function (app) {
  // Web Audio context for metronome click
  const context = new (window.AudioContext || window.webkitAudioContext)();
  function playClick() {
    const osc = context.createOscillator();
    const envelope = context.createGain();
    osc.type = "square";
    osc.frequency.value = 1000;
    envelope.gain.value = 0.2;
    osc.connect(envelope);
    envelope.connect(context.destination);
    osc.start();
    envelope.gain.setTargetAtTime(0, context.currentTime, 0.01);
    osc.stop(context.currentTime + 0.07);
  }

  if (app.ports && app.ports.beatClick) {
    app.ports.beatClick.subscribe(() => {
      if (context.state === "suspended") context.resume();
      playClick();
    });
  }
};
