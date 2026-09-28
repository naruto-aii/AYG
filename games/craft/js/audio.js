export class AudioSys {
  constructor() {
    this.ctx = null;
    this.master = null;
    this.music = null;
    this.volume = 0.6;
    this.musicVolume = 0.22;
    this.step = 0;
  }

  unlock() {
    if (this.ctx) return;
    const ctx = new AudioContext();
    const master = ctx.createGain();
    master.gain.value = this.volume;
    master.connect(ctx.destination);
    this.ctx = ctx;
    this.master = master;
    if (ctx.state === "suspended") ctx.resume();
    this.loopMusic();
  }

  setVolume(v, music) {
    this.volume = v;
    this.musicVolume = music;
    if (this.master) this.master.gain.value = v;
    if (this.musicGain) this.musicGain.gain.value = music * v;
  }

  tone(freq, dur, type, gain, slide = 0) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t);
    if (slide) osc.frequency.exponentialRampToValueAtTime(Math.max(40, freq + slide), t + dur);
    g.gain.setValueAtTime(gain, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    osc.connect(g);
    g.connect(this.master);
    osc.start(t);
    osc.stop(t + dur + 0.02);
  }

  noise(dur, gain, freq) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const length = Math.floor(this.ctx.sampleRate * dur);
    const buffer = this.ctx.createBuffer(1, length, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < length; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / length);
    const src = this.ctx.createBufferSource();
    src.buffer = buffer;
    const filter = this.ctx.createBiquadFilter();
    filter.type = "lowpass";
    filter.frequency.value = freq;
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(gain, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    src.connect(filter);
    filter.connect(g);
    g.connect(this.master);
    src.start(t);
  }

  play(name) {
    if (!this.ctx) return;
    if (name === "break") this.noise(0.14, 0.22, 700);
    else if (name === "place") {
      this.tone(180, 0.06, "square", 0.05);
      this.noise(0.05, 0.12, 500);
    } else if (name === "step") this.noise(0.05, 0.08, 280);
    else if (name === "hurt") this.tone(220, 0.18, "sawtooth", 0.08, -120);
    else if (name === "eat") {
      this.noise(0.12, 0.1, 900);
      this.tone(420, 0.08, "triangle", 0.04);
    } else if (name === "splash") this.noise(0.2, 0.12, 600);
    else if (name === "click") this.tone(640, 0.04, "square", 0.04);
    else if (name === "pickup") this.tone(880, 0.07, "triangle", 0.05, 200);
    else if (name === "hit") this.noise(0.08, 0.16, 400);
  }

  foot(dt, moving, grounded) {
    if (!moving || !grounded) {
      this.step = 0;
      return;
    }
    this.step -= dt;
    if (this.step <= 0) {
      this.step = 0.42;
      this.play("step");
    }
  }

  loopMusic() {
    const ctx = this.ctx;
    const gain = ctx.createGain();
    gain.gain.value = this.musicVolume * this.volume;
    gain.connect(this.master);
    this.musicGain = gain;
    const scale = [220, 247, 262, 294, 330, 349, 392, 440];
    const melody = [0, 2, 4, 7, 4, 2, 0, 4, 5, 4, 2, 1, 0, 2, 4, 2];
    let step = 0;
    const tick = () => {
      if (!this.ctx) return;
      const freq = scale[melody[step % melody.length]];
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      osc.type = "triangle";
      osc.frequency.value = freq;
      const t = ctx.currentTime;
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.08, t + 0.05);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.9);
      osc.connect(g);
      g.connect(gain);
      osc.start(t);
      osc.stop(t + 1);
      step++;
      this.musicTimer = setTimeout(tick, 780);
    };
    tick();
  }
}
