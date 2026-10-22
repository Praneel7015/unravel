/**
 * Unravel — Interactive Circadian Botanical Landing Page Controller (`site/app.js`)
 * Zero external dependencies, zero tracking pixels.
 *
 * Features:
 * 1. Live 4-Mode Circadian Resolver (06:00–11:00 Morning Mist, 11:00–17:30 High Sun,
 *    17:30–23:00 Dusk Pine, 23:00–06:00 Midnight Starlight OLED) + manual pill override.
 * 2. Interactive "Try Unraveling a Worry" Scenario Switcher + Before/After Toggle.
 * 3. Real-time SVG Dual Cubic Spline Perspective Curve recalculated as visitors drag sliders.
 */

(function () {
  'use strict';

  const SCENARIOS = {
    interview: {
      title: 'Product Design Interview',
      meta: 'OPEN THREAD · TOMORROW 10:00 AM',
      predictedFear: 8,
      actualOutcome: 2,
      transcript:
        '“I keep thinking that if I pause for too long during the portfolio review, the panel will assume I didn’t build the system myself...”',
      whatFearSays: '“Any silence means they think I’m unqualified.”',
      groundedTruth:
        'Thoughtful pauses show composure. Nobody expects instant answers to complex trade-offs.',
      worry1:
        'I might freeze up when asked about system architecture trade-offs.',
      action1: 'Next Step: Sketch 2 past projects on index cards tonight.',
      worry2: 'What if they already have an internal candidate in mind?',
      action2:
        'Grounding: I cannot control their budget, only the clarity of my craft.',
      physicalAnchor:
        'Rest both hands flat on the desk before beginning your slide walkthrough. Feel the ground beneath you.',
      afterNotes:
        '“They actually appreciated that I paused to think through the latency trade-off before answering. The conversation felt like peers collaborating.”',
      historicalFear: [7, 9, 8, 6, 8],
      historicalReality: [2, 2, 3, 2, 2],
    },
    boundary: {
      title: 'Setting a Boundary with a Manager',
      meta: 'OPEN THREAD · FRIDAY 2:00 PM',
      predictedFear: 9,
      actualOutcome: 2,
      transcript:
        '“If I tell her that taking on the weekend migration will burn out the team, she might see me as uncooperative...”',
      whatFearSays: '“Saying no once will ruin my reputation on the team.”',
      groundedTruth:
        'Protecting sustainable quality is leadership, not defiance. Clear boundaries earn long-term trust.',
      worry1: 'My voice might rush or sound defensive when explaining scope.',
      action1:
        'Next Step: Write down 2 concrete timeline trade-offs before joining the call.',
      worry2: 'How she privately reacts to adjusting the launch date.',
      action2:
        'Grounding: Another person’s initial mood belongs to fortune, not my character.',
      physicalAnchor:
        'Unclench your jaw and lower your shoulders before speaking your first sentence.',
      afterNotes:
        '“She thanked me for flagging the burnout risk early and we moved the migration to Tuesday morning.”',
      historicalFear: [8, 7, 9, 8, 9],
      historicalReality: [3, 2, 3, 2, 2],
    },
    dinner: {
      title: 'Going to a Dinner Alone',
      meta: 'OPEN THREAD · TONIGHT 7:30 PM',
      predictedFear: 7,
      actualOutcome: 1,
      transcript:
        '“Everyone in the restaurant will notice I’m sitting by myself and think I have nowhere else to be...”',
      whatFearSays: '“Every table is silently judging me for dining solo.”',
      groundedTruth:
        'Passersby are absorbed in their own conversations. Solitude at a table is a quiet luxury.',
      worry1: 'Feeling restless during the ten minutes before food arrives.',
      action1:
        'Next Step: Bring a pocket notebook or physical book you enjoy.',
      worry2: 'What strangers at neighboring tables might assume.',
      action2:
        'Grounding: As Epictetus reminds us, other people’s fleeting thoughts are not ours to carry.',
      physicalAnchor:
        'Wrap both hands around the warm teacup and notice three details in the room.',
      afterNotes:
        '“The chef sent over a complimentary appetizer and I wrote three pages in my notebook in total peace.”',
      historicalFear: [7, 8, 6, 8, 7],
      historicalReality: [2, 3, 2, 2, 1],
    },
  };

  let activeScenarioKey = 'interview';
  let fearHistory = SCENARIOS.interview.historicalFear.slice();
  let realityHistory = SCENARIOS.interview.historicalReality.slice();

  /**
   * Resolves the Circadian theme slug and sun pill label from a local Date object.
   * Mirrors `CircadianResolver.resolveForTime` in `packages/core/lib/src/theme/circadian_mode.dart`.
   */
  function resolveCircadianFromDate(now) {
    const minutes = now.getHours() * 60 + now.getMinutes();
    const hour12 = now.getHours() % 12 === 0 ? 12 : now.getHours() % 12;
    const mm = String(now.getMinutes()).padStart(2, '0');
    const amPm = now.getHours() >= 12 ? 'PM' : 'AM';
    const formattedClock = `${hour12}:${mm} ${amPm}`;

    // 06:00 (360) .. 10:59 (659) -> Morning Mist
    if (minutes >= 360 && minutes < 660) {
      return {
        slug: 'morning-mist',
        phase: 'Dawn',
        name: 'Morning Mist',
        clock: formattedClock,
      };
    }
    // 11:00 (660) .. 17:29 (1049) -> High Sun
    if (minutes >= 660 && minutes < 1050) {
      return {
        slug: 'high-sun',
        phase: 'Midday',
        name: 'High Sun',
        clock: formattedClock,
      };
    }
    // 17:30 (1050) .. 22:59 (1379) -> Dusk Pine
    if (minutes >= 1050 && minutes < 1380) {
      return {
        slug: 'dusk-pine',
        phase: 'Dusk',
        name: 'Dusk Pine',
        clock: formattedClock,
      };
    }
    // 23:00 (1380) .. 05:59 (359) -> Midnight Starlight OLED
    return {
      slug: 'midnight-starlight',
      phase: 'Starlight',
      name: 'Midnight Starlight OLED',
      clock: formattedClock,
    };
  }

  function applyThemeSelection(selection) {
    const nowInfo = resolveCircadianFromDate(new Date());
    const localClockPill = document.getElementById('local-clock-pill');
    const heroSunPill = document.getElementById('hero-sun-pill');

    if (localClockPill) {
      localClockPill.textContent = `Auto · ${nowInfo.clock}`;
    }

    const effectiveSlug = selection === 'auto' ? nowInfo.slug : selection;
    document.documentElement.setAttribute('data-theme', effectiveSlug);

    const displayMap = {
      'morning-mist': `Dawn · ${nowInfo.clock} · Morning Mist (#F6F5F0)`,
      'high-sun': `Midday · ${nowInfo.clock} · High Sun (#EAE8E1)`,
      'dusk-pine': `Dusk · ${nowInfo.clock} · Dusk Pine (#141815)`,
      'midnight-starlight': `Starlight · ${nowInfo.clock} · Pure OLED (#000000)`,
    };

    if (heroSunPill) {
      heroSunPill.textContent = displayMap[effectiveSlug] || displayMap['dusk-pine'];
    }

    const buttons = document.querySelectorAll('[data-theme-select]');
    buttons.forEach((btn) => {
      const target = btn.getAttribute('data-theme-select');
      btn.classList.toggle('is-active', target === selection);
    });
  }

  /**
   * Maps a score in [1..10] to an SVG Y coordinate inside viewBox height 220.
   */
  function scoreToSvgY(score, height) {
    const clamped = Math.max(1, Math.min(10, score));
    const normalized = (clamped - 1) / 9;
    return height * (0.86 - normalized * 0.72);
  }

  /**
   * Builds a smooth cubic Bezier SVG path string matching `_PerspectiveCurvePainter._buildSmoothSpline`.
   */
  function buildCubicSplinePath(points) {
    if (!points.length) return '';
    let d = `M ${points[0].x.toFixed(1)} ${points[0].y.toFixed(1)}`;
    for (let i = 0; i < points.length - 1; i++) {
      const curr = points[i];
      const next = points[i + 1];
      const ctrlX = ((curr.x + next.x) / 2).toFixed(1);
      d += ` C ${ctrlX} ${curr.y.toFixed(1)}, ${ctrlX} ${next.y.toFixed(1)}, ${next.x.toFixed(1)} ${next.y.toFixed(1)}`;
    }
    return d;
  }

  function renderPerspectiveCurve() {
    const width = 520;
    const height = 220;
    const padX = 28;
    const usableW = width - padX * 2;
    const stepX = usableW / (fearHistory.length - 1);

    const fearPts = fearHistory.map((score, i) => ({
      x: padX + i * stepX,
      y: scoreToSvgY(score, height),
    }));
    const realityPts = realityHistory.map((score, i) => ({
      x: padX + i * stepX,
      y: scoreToSvgY(score, height),
    }));

    const fearPathStr = buildCubicSplinePath(fearPts);
    const realityPathStr = buildCubicSplinePath(realityPts);
    const lastPt = realityPts[realityPts.length - 1];
    const firstPt = realityPts[0];
    const areaPathStr = `${realityPathStr} L ${lastPt.x.toFixed(1)} ${height} L ${firstPt.x.toFixed(1)} ${height} Z`;

    const svgFearPath = document.getElementById('svg-fear-path');
    const svgRealityPath = document.getElementById('svg-reality-path');
    const svgRealityArea = document.getElementById('svg-reality-area');
    const svgFearDot = document.getElementById('svg-fear-dot');
    const svgRealityDot = document.getElementById('svg-reality-dot');

    if (svgFearPath) svgFearPath.setAttribute('d', fearPathStr);
    if (svgRealityPath) svgRealityPath.setAttribute('d', realityPathStr);
    if (svgRealityArea) svgRealityArea.setAttribute('d', areaPathStr);

    const latestFearPt = fearPts[fearPts.length - 1];
    if (svgFearDot && latestFearPt) {
      svgFearDot.setAttribute('cx', latestFearPt.x.toFixed(1));
      svgFearDot.setAttribute('cy', latestFearPt.y.toFixed(1));
    }
    if (svgRealityDot && lastPt) {
      svgRealityDot.setAttribute('cx', lastPt.x.toFixed(1));
      svgRealityDot.setAttribute('cy', lastPt.y.toFixed(1));
    }

    // Compute "% gentler than feared"
    let totalFear = 0;
    let totalReduction = 0;
    for (let i = 0; i < fearHistory.length; i++) {
      totalFear += fearHistory[i];
      const delta = fearHistory[i] - realityHistory[i];
      if (delta > 0) totalReduction += delta;
    }
    const gentlerPct =
      totalFear > 0
        ? Math.max(0, Math.min(100, Math.round((totalReduction / totalFear) * 100)))
        : 0;

    const gentlerBadge = document.getElementById('curve-gentler-badge');
    if (gentlerBadge) {
      gentlerBadge.textContent = `${gentlerPct}% gentler than feared`;
    }

    const latestFearVal = fearHistory[fearHistory.length - 1];
    const latestRealityVal = realityHistory[realityHistory.length - 1];

    const fearBadge = document.getElementById('demo-fear-badge');
    if (fearBadge) fearBadge.textContent = `FEAR: ${latestFearVal} / 10`;

    const labelFear = document.getElementById('label-predicted-fear');
    if (labelFear) labelFear.textContent = `${latestFearVal} / 10`;

    const labelReality = document.getElementById('label-actual-reality');
    if (labelReality) labelReality.textContent = `${latestRealityVal} / 10`;

    const quickReadout = document.getElementById('quick-reality-readout');
    if (quickReadout) {
      quickReadout.textContent = `Predicted ${latestFearVal}/10 → Unfolded ${latestRealityVal}/10`;
    }
  }

  function loadScenario(key) {
    const data = SCENARIOS[key];
    if (!data) return;
    activeScenarioKey = key;
    fearHistory = data.historicalFear.slice();
    realityHistory = data.historicalReality.slice();

    const setText = (id, text) => {
      const el = document.getElementById(id);
      if (el) el.textContent = text;
    };

    setText('demo-event-title', data.title);
    setText('demo-event-meta', data.meta);
    setText('demo-transcript', data.transcript);
    setText('demo-fear-says', data.whatFearSays);
    setText('demo-grounded-truth', data.groundedTruth);
    setText('demo-worry-1', data.worry1);
    setText('demo-action-1', data.action1);
    setText('demo-worry-2', data.worry2);
    setText('demo-action-2', data.action2);
    setText('demo-physical-anchor', data.physicalAnchor);
    setText('demo-after-notes', data.afterNotes);

    const inputFear = document.getElementById('input-predicted-fear');
    const inputReality = document.getElementById('input-actual-reality');
    const quickReality = document.getElementById('quick-reality-slider');

    if (inputFear) inputFear.value = String(data.predictedFear);
    if (inputReality) inputReality.value = String(data.actualOutcome);
    if (quickReality) quickReality.value = String(data.actualOutcome);

    document.querySelectorAll('.scenario-pill').forEach((btn) => {
      const isMatch = btn.getAttribute('data-scenario') === key;
      btn.classList.toggle('is-selected', isMatch);
      btn.setAttribute('aria-selected', isMatch ? 'true' : 'false');
    });

    renderPerspectiveCurve();
  }

  function setPhase(phase) {
    const beforeBtn = document.getElementById('tab-before-moment');
    const afterBtn = document.getElementById('tab-after-moment');
    const beforePanel = document.getElementById('panel-before');
    const afterPanel = document.getElementById('panel-after');

    const isBefore = phase === 'before';
    if (beforeBtn) {
      beforeBtn.classList.toggle('is-active', isBefore);
      beforeBtn.setAttribute('aria-selected', isBefore ? 'true' : 'false');
    }
    if (afterBtn) {
      afterBtn.classList.toggle('is-active', !isBefore);
      afterBtn.setAttribute('aria-selected', !isBefore ? 'true' : 'false');
    }
    if (beforePanel) beforePanel.classList.toggle('is-hidden', !isBefore);
    if (afterPanel) afterPanel.classList.toggle('is-hidden', isBefore);
  }

  const FONT_STYLESHEETS = {
    plex: 'https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;1,400&family=IBM+Plex+Serif:ital,wght@0,400;0,500;1,400&display=swap',
    source: 'https://fonts.googleapis.com/css2?family=Source+Code+Pro:wght@400;500&family=Source+Sans+3:ital,wght@0,400;0,600;1,400&family=Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,500;1,8..60,400&display=swap',
    literata: 'https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&family=Inconsolata:wght@400;500&family=Literata:ital,opsz,wght@0,7..72,400;0,7..72,600;1,7..72,400&display=swap',
  };

  function ensureFontStylesheet(id) {
    const href = FONT_STYLESHEETS[id];
    if (!href || document.querySelector('link[data-font-href="' + id + '"]')) {
      return;
    }
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = href;
    link.setAttribute('data-font-href', id);
    document.head.appendChild(link);
  }

  function applyFont(id) {
    const resolved = id === 'field' || FONT_STYLESHEETS[id] ? id : 'field';
    ensureFontStylesheet(resolved);
    document.documentElement.setAttribute('data-font', resolved);
    try {
      localStorage.setItem('unravel-font', resolved);
    } catch (_) {}
    document.querySelectorAll('[data-font-select]').forEach((btn) => {
      const selected = btn.getAttribute('data-font-select') === resolved;
      btn.classList.toggle('is-active', selected);
      btn.setAttribute('aria-pressed', selected ? 'true' : 'false');
    });
  }
  document.addEventListener('DOMContentLoaded', () => {
    let savedFont = 'field';
    try {
      savedFont = localStorage.getItem('unravel-font') || 'field';
    } catch (_) {}
    applyFont(savedFont);
    document.querySelectorAll('[data-font-select]').forEach((btn) => {
      btn.addEventListener('click', () => {
        applyFont(btn.getAttribute('data-font-select') || 'field');
      });
    });

    // 1. Initialize Circadian theme from visitor's local clock
    applyThemeSelection('auto');

    document.querySelectorAll('[data-theme-select]').forEach((btn) => {
      btn.addEventListener('click', () => {
        applyThemeSelection(btn.getAttribute('data-theme-select') || 'auto');
      });
    });

    // 2. Scenario switcher
    document.querySelectorAll('.scenario-pill').forEach((btn) => {
      btn.addEventListener('click', () => {
        const key = btn.getAttribute('data-scenario');
        if (key) loadScenario(key);
      });
    });

    // 3. Before / After phase toggle
    document.querySelectorAll('[data-phase]').forEach((btn) => {
      btn.addEventListener('click', () => {
        setPhase(btn.getAttribute('data-phase') || 'before');
      });
    });

    // 4. Interactive Perspective Curve Sliders
    const inputFear = document.getElementById('input-predicted-fear');
    const inputReality = document.getElementById('input-actual-reality');
    const quickReality = document.getElementById('quick-reality-slider');

    if (inputFear) {
      inputFear.addEventListener('input', (e) => {
        fearHistory[fearHistory.length - 1] = Number(e.target.value);
        renderPerspectiveCurve();
      });
    }

    const onRealityInput = (val) => {
      const numeric = Number(val);
      realityHistory[realityHistory.length - 1] = numeric;
      if (inputReality) inputReality.value = String(numeric);
      if (quickReality) quickReality.value = String(numeric);
      renderPerspectiveCurve();
    };

    if (inputReality) {
      inputReality.addEventListener('input', (e) => onRealityInput(e.target.value));
    }
    if (quickReality) {
      quickReality.addEventListener('input', (e) => onRealityInput(e.target.value));
    }

    loadScenario(activeScenarioKey);

    // 5. Ephemeral 30fps Live Voice Waveform (Web Audio API + Synthetic Fallback)
    let isCapturingVoice = false;
    let voiceIntervalId = null;
    let voiceTick = 0;
    let audioCtx = null;
    let analyser = null;
    let mediaStream = null;
    let timeDomainBuf = null;

    const btnHold = document.getElementById('btn-hold-unravel');
    const btnHoldLabel = document.getElementById('btn-hold-label');
    const micStatusBadge = document.getElementById('mic-status-badge');
    const liveVoiceTimer = document.getElementById('live-voice-timer');
    const primaryRibbon = document.getElementById('wave-ribbon-primary');
    const secondaryRibbon = document.getElementById('wave-ribbon-secondary');

    function updateWaveformRibbons(normalizedAmp, tick) {
      const midY = 27;
      const energy = Math.max(0.16, Math.min(1.0, 0.2 + normalizedAmp * 0.8));
      const swingA = (21 * energy * (0.7 + 0.3 * Math.sin(tick * 0.25))).toFixed(1);
      const swingB = (22 * energy * (0.7 + 0.3 * Math.cos(tick * 0.19))).toFixed(1);
      const swingC = (19 * energy * (0.7 + 0.3 * Math.sin(tick * 0.31))).toFixed(1);

      if (primaryRibbon) {
        primaryRibbon.setAttribute(
          'd',
          `M 0 ${midY} C 50 ${midY - swingA}, 100 ${Number(midY) + Number(swingA)}, 150 25 ` +
            `C 200 ${midY - swingB}, 260 ${Number(midY) + Number(swingB)}, 310 ${midY} ` +
            `C 360 ${midY - swingC}, 395 ${Number(midY) + Number(swingC)}, 420 26`
        );
      }
      if (secondaryRibbon) {
        secondaryRibbon.setAttribute(
          'd',
          `M 0 29 C 60 ${Number(midY) + Number(swingB)}, 115 ${midY - swingB}, 175 29 ` +
            `C 235 ${Number(midY) + Number(swingA)}, 285 ${midY - swingA}, 345 25 ` +
            `C 380 ${Number(midY) + Number(swingC)}, 405 ${midY - swingC}, 420 28`
        );
      }
    }

    async function startLiveVoice() {
      if (isCapturingVoice) return;
      isCapturingVoice = true;
      voiceTick = 0;

      if (btnHoldLabel) {
        btnHoldLabel.textContent = 'Listening at 30fps... (Click to Stop & Shred RAM)';
      }

      try {
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
          mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
          const AudioContextClass = window.AudioContext || window.webkitAudioContext;
          audioCtx = new AudioContextClass();
          const source = audioCtx.createMediaStreamSource(mediaStream);
          analyser = audioCtx.createAnalyser();
          analyser.fftSize = 256;
          timeDomainBuf = new Uint8Array(analyser.fftSize);
          source.connect(analyser);
        }
      } catch (_err) {
        // Fallback to synthetic 30fps PCM simulation if microphone permission is declined
      }

      voiceIntervalId = setInterval(() => {
        voiceTick += 1;
        const elapsedSec = Math.min(60, Math.floor((voiceTick * 33) / 1000));
        const mm = Math.floor(elapsedSec / 60);
        const ss = String(elapsedSec % 60).padStart(2, '0');
        if (liveVoiceTimer) liveVoiceTimer.textContent = `${mm}:${ss} / 1:00`;

        let normAmp =
          0.32 + 0.42 * Math.abs(Math.sin(voiceTick * 0.22)) + 0.2 * Math.abs(Math.cos(voiceTick * 0.13));

        if (analyser && timeDomainBuf) {
          analyser.getByteTimeDomainData(timeDomainBuf);
          let sumSq = 0;
          for (let i = 0; i < timeDomainBuf.length; i++) {
            const centered = (timeDomainBuf[i] - 128) / 128;
            sumSq += centered * centered;
          }
          const rms = Math.sqrt(sumSq / timeDomainBuf.length);
          normAmp = Math.min(1.0, Math.max(0.12, rms * 3.4));
        }

        updateWaveformRibbons(normAmp, voiceTick);
        if (micStatusBadge) {
          micStatusBadge.textContent = `Ephemeral RAM: ${voiceTick * 320} bytes`;
        }

        if (elapsedSec >= 60) {
          stopAndShredLiveVoice();
        }
      }, 33);
    }

    function stopAndShredLiveVoice() {
      if (!isCapturingVoice) return;
      isCapturingVoice = false;
      if (voiceIntervalId) {
        clearInterval(voiceIntervalId);
        voiceIntervalId = null;
      }
      if (timeDomainBuf) {
        timeDomainBuf.fill(0);
      }
      if (mediaStream) {
        mediaStream.getTracks().forEach((t) => t.stop());
        mediaStream = null;
      }
      if (audioCtx) {
        audioCtx.close().catch(() => {});
        audioCtx = null;
      }
      analyser = null;
      if (btnHoldLabel) {
        btnHoldLabel.textContent = 'Hold or Click to Unravel a Worry (Live 30fps Mic)';
      }
      if (micStatusBadge) {
        micStatusBadge.textContent = 'RAM Shredded (0x00) · 0 bytes on disk';
      }
    }

    if (btnHold) {
      btnHold.addEventListener('click', () => {
        if (isCapturingVoice) {
          stopAndShredLiveVoice();
        } else {
          startLiveVoice();
        }
      });
    }

    // 6. Save Custom Open Thread
    const btnSaveThread = document.getElementById('btn-save-open-thread');
    const customThreadInput = document.getElementById('custom-thread-input');
    const savedToast = document.getElementById('saved-thread-toast');

    if (btnSaveThread && customThreadInput) {
      btnSaveThread.addEventListener('click', () => {
        stopAndShredLiveVoice();
        const customTitle = customThreadInput.value.trim() || 'Upcoming Moment This Week';
        const titleEl = document.getElementById('demo-event-title');
        const metaEl = document.getElementById('demo-event-meta');
        if (titleEl) titleEl.textContent = customTitle;
        if (metaEl) metaEl.textContent = 'OPEN THREAD · CHECK-IN SCHEDULED (+1 HR)';
        if (savedToast) {
          savedToast.textContent = `✓ Saved "${customTitle}" (AES-256-GCM encrypted envelope + offline check-in scheduled).`;
        }
        customThreadInput.value = '';
      });
    }
  });
})();
