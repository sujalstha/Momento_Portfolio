/* global React */
const { useState } = React;

/* =========================================================
   MOMENTO — Wireframes
   Sketchy / low-fi explorations for an accessibility-first
   running coach for blind & low-vision runners.
   Palette: Okabe-Ito (colorblind-safe) — same family Datylon
   recommends. Big type, huge tap targets, voice-first flow.
   ========================================================= */

const StatusBar = () => (
  <div className="statusbar">
    <span>9:41</span>
    <span>MOMENTO</span>
    <span>●●●●</span>
  </div>
);

const TabBar = ({ on = "home" }) => (
  <div className="tabbar">
    <div className={on === "home" ? "on" : ""}>
      <span className="glyph">▶</span>Run
    </div>
    <div className={on === "history" ? "on" : ""}>
      <span className="glyph">≡</span>History
    </div>
    <div className={on === "settings" ? "on" : ""}>
      <span className="glyph">✦</span>Settings
    </div>
  </div>
);

const Phone = ({ children, label, note }) => (
  <div style={{ position: "relative" }}>
    <div className="phone">
      <StatusBar />
      {children}
    </div>
    {note && (
      <div style={{
        position: "absolute",
        top: -18,
        left: 16,
        fontFamily: "var(--font-hand)",
        fontSize: 18,
        color: "var(--ink)",
      }}>
        {note}
      </div>
    )}
  </div>
);

/* =========================================================
   1. LOGIN  — 3 variants
   ========================================================= */

const Login_A = () => (
  <Phone>
    <div className="screen" style={{ justifyContent: "space-between" }}>
      <div style={{ marginTop: 24 }}>
        <p className="eyebrow">A run coach you can hear</p>
        <h1 className="h1" style={{ fontSize: 64, marginTop: 6 }}>
          <span className="marker">Momento</span>
        </h1>
        <p className="body" style={{ marginTop: 14, fontSize: 22 }}>
          Tap a button. We'll do the rest, out loud.
        </p>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
        <button className="tap dark">
          <span style={{ fontSize: 28 }}> Sign in with Apple</span>
        </button>
        <button className="tap ghost">
          <span style={{ fontSize: 28 }}>G  Sign in with Google</span>
        </button>
        <p className="label" style={{ textAlign: "center", marginTop: 4 }}>
          VoiceOver ready · 88px tap targets
        </p>
      </div>
    </div>
  </Phone>
);

const Login_B = () => (
  <Phone>
    <div className="screen" style={{ justifyContent: "space-between" }}>
      <div style={{ textAlign: "center", marginTop: 30 }}>
        <p className="eyebrow">welcome back</p>
        <h1 className="h1" style={{ fontSize: 54, marginTop: 8 }}>Momento</h1>
      </div>

      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 22 }}>
        <div className="orb" style={{ width: 150, height: 150 }} />
        <div className="vbubble" style={{ maxWidth: 280, textAlign: "center" }}>
          "Tap once to sign in with Apple. Twice for Google."
        </div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
        <button className="tap dark column">
          
          <small>SIGN IN WITH APPLE</small>
        </button>
        <button className="tap sky column">
          G
          <small>SIGN IN WITH GOOGLE</small>
        </button>
      </div>
    </div>
  </Phone>
);

const Login_C = () => (
  <Phone>
    <div className="screen" style={{ justifyContent: "space-between" }}>
      <div style={{ marginTop: 26 }}>
        <h1 className="h1" style={{ fontSize: 70, lineHeight: 0.95 }}>
          hi.<br />
          <span className="uline">it's us.</span>
        </h1>
        <p className="body" style={{ marginTop: 18, fontSize: 21 }}>
          Momento — your pocket running coach.
          Pick how you'd like to come in.
        </p>
      </div>

      <div className="scribble" style={{ padding: 16, display: "flex", flexDirection: "column", gap: 12 }}>
        <button className="tap dark" style={{ boxShadow: "none" }}>
           Apple
        </button>
        <button className="tap primary" style={{ boxShadow: "none" }}>
          G  Google
        </button>
        <div className="divider" />
        <p className="label" style={{ textAlign: "center" }}>
          Or hold the screen to hear your options
        </p>
      </div>
    </div>
  </Phone>
);

/* =========================================================
   2. ONBOARDING  — 3 variants (voice-first)
   ========================================================= */

const Onboard_A = () => (
  <Phone>
    <div className="screen" style={{ alignItems: "center", justifyContent: "space-between" }}>
      <div style={{ textAlign: "center", marginTop: 18, width: "100%" }}>
        <p className="eyebrow">step 1 of 5</p>
        <h2 className="h2" style={{ marginTop: 6, fontSize: 32 }}>
          What should I call you?
        </h2>
      </div>

      <div style={{ position: "relative", display: "flex", alignItems: "center", justifyContent: "center" }}>
        <div className="orb-ring" style={{ width: 250, height: 250, top: -35, left: -35 }} />
        <div className="orb-ring" style={{ width: 215, height: 215, top: -17, left: -17, borderStyle: "dotted" }} />
        <div className="orb" />
      </div>

      <div style={{ width: "100%" }}>
        <div className="vbubble" style={{ marginBottom: 10 }}>
          "Hi! I'm Echo. Say your name when you hear the tone."
        </div>
        <div className="wave" style={{ marginBottom: 12 }}>
          {[14,28,46,62,40,72,52,30,18,34,58,44,24,12].map((h,i) => (
            <span key={i} style={{ height: h }} />
          ))}
        </div>
        <button className="tap primary" style={{ minHeight: 70 }}>
          ●  Tap to speak
        </button>
      </div>
    </div>
  </Phone>
);

const Onboard_B = () => (
  <Phone>
    <div className="screen">
      <div style={{ display: "flex", gap: 4, marginTop: 6, marginBottom: 14 }}>
        {[1,2,3,4,5].map(i => (
          <div key={i} style={{
            flex: 1, height: 8,
            background: i <= 3 ? "var(--ink)" : "var(--paper-2)",
            border: "2px solid var(--ink)", borderRadius: 4,
          }} />
        ))}
      </div>

      <p className="eyebrow">about you</p>
      <h2 className="h2" style={{ marginTop: 6 }}>Tell me your height.</h2>

      <div className="vbubble" style={{ marginTop: 14, fontSize: 20 }}>
        "You can speak it, or use the wheel below. Either works."
      </div>

      <div className="scribble" style={{ marginTop: 18, padding: "20px 18px", textAlign: "center" }}>
        <p className="label">CURRENT</p>
        <div className="num" style={{ fontSize: 72, marginTop: 4 }}>5′ 9″</div>
        <p className="label" style={{ marginTop: 4 }}>175 cm</p>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 14, gap: 10 }}>
          <button className="tap ghost" style={{ minHeight: 64, fontSize: 26, boxShadow: "2px 2px 0 var(--ink)" }}>−</button>
          <button className="tap ghost" style={{ minHeight: 64, fontSize: 26, boxShadow: "2px 2px 0 var(--ink)" }}>+</button>
        </div>
      </div>

      <div style={{ flex: 1 }} />
      <div style={{ display: "flex", gap: 12 }}>
        <button className="tap ghost" style={{ flex: 1, minHeight: 72, fontSize: 24 }}>← Back</button>
        <button className="tap primary" style={{ flex: 2, minHeight: 72, fontSize: 26 }}>Next →</button>
      </div>
    </div>
  </Phone>
);

const Onboard_C = () => (
  <Phone>
    <div className="screen">
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginTop: 6 }}>
        <div className="orb" style={{ width: 56, height: 56, boxShadow: "2px 2px 0 var(--ink)" }} />
        <div>
          <p className="eyebrow">echo</p>
          <p className="body" style={{ fontSize: 18 }}>setting you up…</p>
        </div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 12, marginTop: 18, flex: 1, overflow: "hidden" }}>
        <div className="vbubble">"Nice to meet you. What's your name?"</div>
        <div className="vbubble user" style={{ alignSelf: "flex-end" }}>"Priya"</div>
        <div className="vbubble">"Hi Priya! How old are you?"</div>
        <div className="vbubble user" style={{ alignSelf: "flex-end" }}>"Thirty-four"</div>
        <div className="vbubble">"Got it. Your weight, roughly?"</div>
        <div className="vbubble" style={{ background: "var(--paper-2)", borderStyle: "dashed" }}>
          <span style={{ opacity: 0.5 }}>...listening</span>
          <span style={{ display: "inline-block", marginLeft: 6, animation: "blink 1s infinite" }}>●</span>
        </div>
      </div>

      <button className="tap dark" style={{ marginTop: 14, minHeight: 80 }}>
        ◉  HOLD TO SPEAK
      </button>
    </div>
  </Phone>
);

/* =========================================================
   3. HOME / START — 3 variants
   ========================================================= */

const Home_A = () => (
  <>
    <Phone>
      <div className="screen" style={{ paddingBottom: 0 }}>
        <div style={{ marginTop: 10 }}>
          <p className="eyebrow">good morning, priya</p>
          <h2 className="h2" style={{ marginTop: 4 }}>Ready to run?</h2>
        </div>

        <div className="tabs" style={{ marginTop: 16 }}>
          <div className="on">Start run</div>
          <div>History</div>
          <div>Settings</div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 18, marginTop: 22, flex: 1 }}>
          <button className="tap primary column" style={{ flex: 1, fontSize: 34 }}>
            <span> WITH</span>
            <span>LIVE COACH</span>
            <small style={{ marginTop: 8 }}>echo guides you in real time</small>
          </button>
          <button className="tap ghost column" style={{ flex: 1, fontSize: 34 }}>
            <span>▶  WITHOUT</span>
            <span>COACH</span>
            <small style={{ marginTop: 8 }}>solo run, metrics only</small>
          </button>
        </div>
      </div>
      <TabBar on="home" />
    </Phone>
  </>
);

const Home_B = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 8 }}>
        <p className="eyebrow">momento · home</p>
        <span className="pill green">● ONLINE</span>
      </div>

      <h2 className="h2" style={{ marginTop: 14, fontSize: 36 }}>
        Hi Priya.<br /><span className="uline">Let's move.</span>
      </h2>

      <div style={{ display: "flex", justifyContent: "center", margin: "26px 0 18px" }}>
        <div className="rec" style={{ width: 220, height: 220 }}>
          START RUN
          <small>with live coach</small>
        </div>
      </div>

      <button className="tap ghost" style={{ minHeight: 72, fontSize: 24 }}>
        ▶  Start without coach
      </button>

      <p className="label" style={{ textAlign: "center", marginTop: 14 }}>
        Triple-tap anywhere to start instantly
      </p>

      <div style={{ flex: 1 }} />
    </div>
    <TabBar on="home" />
  </Phone>
);

const Home_C = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <div style={{ marginTop: 8 }}>
        <p className="eyebrow">today · tue may 23</p>
        <h2 className="h2" style={{ marginTop: 4, fontSize: 34 }}>Hey Priya 👋</h2>
      </div>

      <button className="tap primary column" style={{ marginTop: 18, minHeight: 150, fontSize: 36 }}>
        <span style={{ fontSize: 42 }}>▶ START RUN</span>
        <small style={{ marginTop: 10 }}>WITH LIVE COACH ECHO</small>
      </button>

      <button className="tap ghost column" style={{ marginTop: 14, minHeight: 110, fontSize: 28 }}>
        <span>▶ START RUN</span>
        <small>WITHOUT COACH · SOLO</small>
      </button>

      <div className="divider" style={{ margin: "18px 0 10px" }} />
      <p className="label">LAST SESSION</p>
      <div className="row" style={{ marginTop: 8, padding: "12px 14px" }}>
        <div className="left">
          <div className="h2" style={{ fontSize: 24 }}>Yesterday · 4.2 km</div>
          <p className="label" style={{ marginTop: 2 }}>34:12 · avg 8:08/mi</p>
        </div>
        <span className="chev">›</span>
      </div>
    </div>
    <TabBar on="home" />
  </Phone>
);

/* =========================================================
   4. HISTORY tab — 3 variants
   ========================================================= */

const History_A = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <p className="eyebrow" style={{ marginTop: 8 }}>your runs</p>
      <h2 className="h2" style={{ marginTop: 4 }}>Session History</h2>

      <div className="tabs" style={{ marginTop: 16 }}>
        <div>Start run</div>
        <div className="on">History</div>
        <div>Settings</div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 14, marginTop: 18 }}>
        <button className="tap ghost column" style={{ minHeight: 130, alignItems: "flex-start", padding: "16px 20px" }}>
          <div style={{ display: "flex", justifyContent: "space-between", width: "100%", alignItems: "center" }}>
            <span className="pill orange">YESTERDAY</span>
            <span style={{ fontSize: 22 }}>›</span>
          </div>
          <div style={{ fontSize: 44, marginTop: 8 }}>4.2 km</div>
          <small style={{ alignSelf: "flex-start" }}>34:12 · with coach</small>
        </button>

        <button className="tap ghost column" style={{ minHeight: 130, alignItems: "flex-start", padding: "16px 20px" }}>
          <div style={{ display: "flex", justifyContent: "space-between", width: "100%", alignItems: "center" }}>
            <span className="pill sky">SUN MAY 19</span>
            <span style={{ fontSize: 22 }}>›</span>
          </div>
          <div style={{ fontSize: 44, marginTop: 8 }}>5.0 km</div>
          <small style={{ alignSelf: "flex-start" }}>41:50 · solo</small>
        </button>
      </div>

      <p className="label" style={{ textAlign: "center", marginTop: "auto", marginBottom: 14, opacity: 0.7 }}>
        Showing last 2 sessions
      </p>
    </div>
    <TabBar on="history" />
  </Phone>
);

const History_B = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <p className="eyebrow" style={{ marginTop: 8 }}>history</p>
      <h2 className="h2" style={{ marginTop: 4 }}>2 sessions</h2>

      <div style={{ display: "flex", flexDirection: "column", gap: 14, marginTop: 22 }}>
        <div className="row" style={{ minHeight: 110, padding: 16 }}>
          <div className="hatch-orange" style={{
            width: 72, height: 72, borderRadius: 12,
            border: "2.5px solid var(--ink)",
            display: "flex", alignItems: "center", justifyContent: "center",
            flexShrink: 0,
          }}>
            <span style={{ fontFamily: "var(--font-hand)", fontSize: 30, fontWeight: 700 }}>22</span>
          </div>
          <div className="left">
            <p className="label" style={{ marginBottom: 2 }}>FRI MAY 22</p>
            <div className="h2" style={{ fontSize: 30 }}>4.2 km</div>
            <p className="body" style={{ fontSize: 16, opacity: 0.7 }}>34:12 · coached</p>
          </div>
          <span className="chev">→</span>
        </div>

        <div className="row" style={{ minHeight: 110, padding: 16 }}>
          <div className="hatch-sky" style={{
            width: 72, height: 72, borderRadius: 12,
            border: "2.5px solid var(--ink)",
            display: "flex", alignItems: "center", justifyContent: "center",
            flexShrink: 0,
          }}>
            <span style={{ fontFamily: "var(--font-hand)", fontSize: 30, fontWeight: 700 }}>19</span>
          </div>
          <div className="left">
            <p className="label" style={{ marginBottom: 2 }}>SUN MAY 19</p>
            <div className="h2" style={{ fontSize: 30 }}>5.0 km</div>
            <p className="body" style={{ fontSize: 16, opacity: 0.7 }}>41:50 · solo</p>
          </div>
          <span className="chev">→</span>
        </div>
      </div>

      <div className="box dashed" style={{ marginTop: 18, padding: 16, textAlign: "center", borderRadius: 14 }}>
        <p className="body" style={{ fontSize: 17 }}>
          Older runs sync to your phone's Health app.
        </p>
      </div>

      <div style={{ flex: 1 }} />
    </div>
    <TabBar on="history" />
  </Phone>
);

const History_C = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <div style={{ marginTop: 8 }}>
        <p className="eyebrow">history</p>
        <h2 className="h2" style={{ marginTop: 4, fontSize: 32 }}>
          Recent <span className="marker">runs</span>
        </h2>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 18, marginTop: 20 }}>
        <button className="scribble" style={{
          padding: 18, textAlign: "left", background: "var(--orange)",
          color: "var(--ink)", border: "3px solid var(--ink)", boxShadow: "4px 4px 0 var(--ink)",
          cursor: "pointer",
        }}>
          <div style={{ display: "flex", justifyContent: "space-between" }}>
            <p className="label">YESTERDAY</p>
            <p className="label">▶ COACHED</p>
          </div>
          <div style={{ display: "flex", alignItems: "baseline", gap: 12, marginTop: 6 }}>
            <span style={{ fontFamily: "var(--font-hand)", fontWeight: 700, fontSize: 64, lineHeight: 1 }}>4.2</span>
            <span className="label">KM · 34:12</span>
          </div>
          <p className="body" style={{ fontSize: 16, marginTop: 4 }}>tap for full breakdown →</p>
        </button>

        <button className="scribble" style={{
          padding: 18, textAlign: "left", background: "var(--sky)",
          color: "var(--ink)", border: "3px solid var(--ink)", boxShadow: "4px 4px 0 var(--ink)",
          cursor: "pointer",
        }}>
          <div style={{ display: "flex", justifyContent: "space-between" }}>
            <p className="label">SUN MAY 19</p>
            <p className="label">SOLO</p>
          </div>
          <div style={{ display: "flex", alignItems: "baseline", gap: 12, marginTop: 6 }}>
            <span style={{ fontFamily: "var(--font-hand)", fontWeight: 700, fontSize: 64, lineHeight: 1 }}>5.0</span>
            <span className="label">KM · 41:50</span>
          </div>
          <p className="body" style={{ fontSize: 16, marginTop: 4 }}>tap for full breakdown →</p>
        </button>
      </div>

      <div style={{ flex: 1 }} />
    </div>
    <TabBar on="history" />
  </Phone>
);

/* =========================================================
   5. METRICS DETAIL — 3 variants
   ========================================================= */

const Metrics_A = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 16, overflow: "auto" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 6 }}>
        <button className="pill dark">← BACK</button>
        <span className="pill orange">COACHED</span>
      </div>

      <p className="eyebrow" style={{ marginTop: 14 }}>FRI MAY 22 · 7:14 AM</p>
      <h2 className="h2" style={{ marginTop: 4, fontSize: 30 }}>Morning run</h2>

      <div style={{ display: "flex", alignItems: "baseline", gap: 6, marginTop: 14 }}>
        <span className="num" style={{ fontSize: 88 }}>4.2</span>
        <span className="label">KM</span>
      </div>
      <p className="body" style={{ fontSize: 22, marginTop: 4 }}>
        in <b>34 min 12 sec</b> · pace 8:08 /mi
      </p>

      <div className="divider" style={{ margin: "14px 0" }} />

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        <div className="tile"><div className="k">HEART RATE</div><div className="v">152</div><div className="u">AVG BPM</div></div>
        <div className="tile"><div className="k">CADENCE</div><div className="v">168</div><div className="u">STEPS/MIN</div></div>
        <div className="tile"><div className="k">POWER</div><div className="v">241</div><div className="u">WATTS AVG</div></div>
        <div className="tile"><div className="k">STRIDE</div><div className="v">1.14</div><div className="u">METERS</div></div>
        <div className="tile"><div className="k">CALORIES</div><div className="v">312</div><div className="u">KCAL</div></div>
        <div className="tile"><div className="k">SPO₂</div><div className="v">97</div><div className="u">PERCENT</div></div>
        <div className="tile"><div className="k">ELEVATION</div><div className="v">+38</div><div className="u">METERS</div></div>
        <div className="tile"><div className="k">HRV</div><div className="v">52</div><div className="u">MS</div></div>
      </div>

      <button className="tap dark" style={{ marginTop: 14, minHeight: 64, fontSize: 22 }}>
        ◀ HEAR FULL SUMMARY
      </button>
    </div>
  </Phone>
);

const Metrics_B = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 16, overflow: "auto" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 6 }}>
        <button className="pill">← BACK</button>
        <button className="pill dark">⇪ SHARE</button>
      </div>

      <div className="scribble" style={{
        marginTop: 14, padding: "20px 18px", background: "var(--ink)",
        color: "var(--paper)", border: "3px solid var(--ink)",
      }}>
        <p className="label" style={{ color: "var(--paper)", opacity: 0.7 }}>FRI MAY 22</p>
        <div style={{ display: "flex", alignItems: "baseline", gap: 10, marginTop: 6 }}>
          <span className="num" style={{ fontSize: 80, color: "var(--orange)" }}>4.2</span>
          <span className="label" style={{ color: "var(--paper)" }}>KILOMETERS</span>
        </div>
        <p className="body" style={{ fontSize: 20, marginTop: 8 }}>
          34:12 total · 8:08 /mi avg pace
        </p>
      </div>

      <p className="label" style={{ marginTop: 16 }}>THE HEART OF IT</p>
      <div style={{ display: "flex", gap: 10, marginTop: 8 }}>
        <div className="tile" style={{ flex: 1, background: "var(--paper)" }}>
          <div className="k">AVG HR</div><div className="v">152</div><div className="u">BPM</div>
        </div>
        <div className="tile" style={{ flex: 1, background: "var(--paper)" }}>
          <div className="k">PEAK HR</div><div className="v">171</div><div className="u">BPM</div>
        </div>
        <div className="tile" style={{ flex: 1, background: "var(--paper)" }}>
          <div className="k">HRV</div><div className="v">52</div><div className="u">MS</div>
        </div>
      </div>

      <p className="label" style={{ marginTop: 14 }}>FORM</p>
      <div style={{ display: "flex", gap: 10, marginTop: 8 }}>
        <div className="tile" style={{ flex: 1 }}><div className="k">CADENCE</div><div className="v">168</div><div className="u">SPM</div></div>
        <div className="tile" style={{ flex: 1 }}><div className="k">STRIDE</div><div className="v">1.14</div><div className="u">M</div></div>
        <div className="tile" style={{ flex: 1 }}><div className="k">POWER</div><div className="v">241</div><div className="u">W</div></div>
      </div>

      <p className="label" style={{ marginTop: 14 }}>BODY</p>
      <div style={{ display: "flex", gap: 10, marginTop: 8 }}>
        <div className="tile" style={{ flex: 1 }}><div className="k">CALS</div><div className="v">312</div><div className="u">KCAL</div></div>
        <div className="tile" style={{ flex: 1 }}><div className="k">SPO₂</div><div className="v">97</div><div className="u">%</div></div>
        <div className="tile" style={{ flex: 1 }}><div className="k">ELEV</div><div className="v">+38</div><div className="u">M</div></div>
      </div>
    </div>
  </Phone>
);

const Metrics_C = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 16, overflow: "auto" }}>
      <button className="pill dark" style={{ alignSelf: "flex-start", marginTop: 4 }}>← ALL RUNS</button>

      <p className="eyebrow" style={{ marginTop: 14 }}>YESTERDAY</p>
      <h2 className="h2" style={{ marginTop: 2, fontSize: 34 }}>
        <span className="uline">Your run</span>, by numbers.
      </h2>

      {/* Hero stat */}
      <div className="hatch-orange" style={{
        marginTop: 16, padding: 18,
        border: "3px solid var(--ink)", borderRadius: 22,
        boxShadow: "4px 4px 0 var(--ink)",
      }}>
        <p className="label">DISTANCE</p>
        <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
          <span className="num" style={{ fontSize: 96 }}>4.2</span>
          <span className="label" style={{ fontSize: 18 }}>KM</span>
        </div>
        <p className="body" style={{ fontSize: 19 }}>34:12 · 8:08 /mi avg</p>
      </div>

      {/* Read-aloud list */}
      <div style={{ marginTop: 14, display: "flex", flexDirection: "column", gap: 8 }}>
        {[
          ["Average heart rate", "152", "BPM"],
          ["Cadence", "168", "STEPS / MIN"],
          ["Running power", "241", "WATTS"],
          ["Stride length", "1.14", "METERS"],
          ["Calories burned", "312", "KCAL"],
          ["Blood oxygen", "97", "PERCENT"],
          ["Elevation gain", "+38", "METERS"],
        ].map(([k, v, u]) => (
          <div key={k} style={{
            display: "flex", alignItems: "baseline", justifyContent: "space-between",
            padding: "10px 4px",
            borderBottom: "2px dashed var(--ink)",
          }}>
            <span style={{ fontFamily: "var(--font-body)", fontSize: 19 }}>{k}</span>
            <span>
              <b style={{ fontFamily: "var(--font-hand)", fontSize: 30 }}>{v}</b>
              <span className="label" style={{ marginLeft: 6 }}>{u}</span>
            </span>
          </div>
        ))}
      </div>

      <button className="tap primary" style={{ marginTop: 16, minHeight: 70, fontSize: 24 }}>
         PLAY SUMMARY
      </button>
    </div>
  </Phone>
);

/* =========================================================
   6. SETTINGS — 3 variants
   ========================================================= */

const Settings_A = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <p className="eyebrow" style={{ marginTop: 8 }}>settings</p>
      <h2 className="h2" style={{ marginTop: 4 }}>Your setup</h2>

      <div style={{ display: "flex", flexDirection: "column", gap: 14, marginTop: 20 }}>
        <button className="tap ghost" style={{ justifyContent: "space-between", padding: "0 22px", minHeight: 96 }}>
          <span style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
            <span style={{ fontSize: 28 }}>Profile</span>
            <small style={{ marginTop: 0 }}>NAME · AGE · BODY · GOALS</small>
          </span>
          <span style={{ fontSize: 30 }}>›</span>
        </button>

        <button className="tap ghost" style={{ justifyContent: "space-between", padding: "0 22px", minHeight: 96 }}>
          <span style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
            <span style={{ fontSize: 28 }}>Coaching</span>
            <small style={{ marginTop: 0 }}>ECHO'S VOICE · CADENCE · TONE</small>
          </span>
          <span style={{ fontSize: 30 }}>›</span>
        </button>

        <button className="tap ghost" style={{ justifyContent: "space-between", padding: "0 22px", minHeight: 96 }}>
          <span style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
            <span style={{ fontSize: 28 }}>Support</span>
            <small style={{ marginTop: 0 }}>HELP · CONTACT · ABOUT</small>
          </span>
          <span style={{ fontSize: 30 }}>›</span>
        </button>
      </div>

      <div style={{ flex: 1 }} />
      <p className="label" style={{ textAlign: "center", marginBottom: 14, opacity: 0.7 }}>
        v1.0 · Momento · made with 💛 for runners
      </p>
    </div>
    <TabBar on="settings" />
  </Phone>
);

const Settings_B = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <p className="eyebrow" style={{ marginTop: 8 }}>settings</p>
      <h2 className="h2" style={{ marginTop: 4 }}>Hi Priya 👋</h2>

      <div className="scribble" style={{
        marginTop: 16, padding: 16, display: "flex", alignItems: "center", gap: 14,
      }}>
        <div className="hatch-orange" style={{
          width: 64, height: 64, borderRadius: 50,
          border: "2.5px solid var(--ink)", flexShrink: 0,
        }} />
        <div style={{ flex: 1 }}>
          <p className="h2" style={{ fontSize: 22 }}>Priya · 34</p>
          <p className="label" style={{ marginTop: 2 }}>5′9″ · 142 LB · ANY PRONOUN</p>
        </div>
        <span style={{ fontSize: 26 }}>✎</span>
      </div>

      <p className="label" style={{ marginTop: 18 }}>MENU</p>
      <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 8 }}>
        <div className="row" style={{ padding: "16px 18px" }}>
          <div style={{ fontFamily: "var(--font-hand)", fontSize: 28, width: 36 }}>◉</div>
          <div className="left">
            <div className="body" style={{ fontSize: 22 }}>Profile</div>
            <p className="label">EDIT YOUR INFO</p>
          </div>
          <span className="chev">›</span>
        </div>
        <div className="row" style={{ padding: "16px 18px" }}>
          <div style={{ fontFamily: "var(--font-hand)", fontSize: 28, width: 36 }}>♫</div>
          <div className="left">
            <div className="body" style={{ fontSize: 22 }}>Coaching settings</div>
            <p className="label">VOICE, CHATTINESS, UNITS</p>
          </div>
          <span className="chev">›</span>
        </div>
        <div className="row" style={{ padding: "16px 18px" }}>
          <div style={{ fontFamily: "var(--font-hand)", fontSize: 28, width: 36 }}>?</div>
          <div className="left">
            <div className="body" style={{ fontSize: 22 }}>Support</div>
            <p className="label">HELP &amp; CONTACT</p>
          </div>
          <span className="chev">›</span>
        </div>
      </div>

      <div style={{ flex: 1 }} />
    </div>
    <TabBar on="settings" />
  </Phone>
);

const Settings_C = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <p className="eyebrow" style={{ marginTop: 8 }}>settings</p>
      <h2 className="h2" style={{ marginTop: 4, fontSize: 34 }}>
        <span className="marker">Yours.</span> Tweak it.
      </h2>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14, marginTop: 22 }}>
        <button className="tap ghost column" style={{ minHeight: 150, fontSize: 24 }}>
          <span style={{ fontSize: 38 }}>◉</span>
          <span style={{ marginTop: 6 }}>Profile</span>
          <small>YOUR DETAILS</small>
        </button>
        <button className="tap primary column" style={{ minHeight: 150, fontSize: 24 }}>
          <span style={{ fontSize: 38 }}>♫</span>
          <span style={{ marginTop: 6 }}>Coaching</span>
          <small>ECHO'S VOICE</small>
        </button>
        <button className="tap sky column" style={{ minHeight: 150, fontSize: 24 }}>
          <span style={{ fontSize: 38 }}>?</span>
          <span style={{ marginTop: 6 }}>Support</span>
          <small>HELP &amp; CONTACT</small>
        </button>
        <button className="tap ghost column" style={{ minHeight: 150, fontSize: 24, borderStyle: "dashed" }}>
          <span style={{ fontSize: 38 }}>↻</span>
          <span style={{ marginTop: 6 }}>Sign out</span>
          <small>SEE YOU SOON</small>
        </button>
      </div>

      <div style={{ flex: 1 }} />
      <p className="label" style={{ textAlign: "center", marginBottom: 14 }}>
        Momento v1.0 · accessibility first, always
      </p>
    </div>
    <TabBar on="settings" />
  </Phone>
);

/* =========================================================
   Compose into DesignCanvas
   ========================================================= */

const W = 430, H = 820;

function App() {
  return (
    <DesignCanvas
      title="MOMENTO — wireframes"
      subtitle="A run-coach app for blind & low-vision runners. Sketchy explorations across six screens, three variants each. Palette is Okabe-Ito (colorblind-safe). Big tap targets (88px+), big type, voice-first throughout."
    >
      <DCSection id="login" title="1 · Sign in" subtitle="Apple + Google. Voice-friendly entry.">
        <DCArtboard id="login-a" label="A · Plain stacked" width={W} height={H}><Login_A /></DCArtboard>
        <DCArtboard id="login-b" label="B · Voice greeting" width={W} height={H}><Login_B /></DCArtboard>
        <DCArtboard id="login-c" label="C · Marker headline" width={W} height={H}><Login_C /></DCArtboard>
      </DCSection>

      <DCSection id="onboard" title="2 · Onboarding" subtitle="Name, age, gender, height, weight — guided by Echo.">
        <DCArtboard id="ob-a" label="A · Big orb + voice" width={W} height={H}><Onboard_A /></DCArtboard>
        <DCArtboard id="ob-b" label="B · Step form + ± controls" width={W} height={H}><Onboard_B /></DCArtboard>
        <DCArtboard id="ob-c" label="C · Conversation log" width={W} height={H}><Onboard_C /></DCArtboard>
      </DCSection>

      <DCSection id="home" title="3 · Home — start a run" subtitle="Two huge buttons. Coached or solo.">
        <DCArtboard id="home-a" label="A · Two stacked slabs" width={W} height={H}><Home_A /></DCArtboard>
        <DCArtboard id="home-b" label="B · Hero record-style" width={W} height={H}><Home_B /></DCArtboard>
        <DCArtboard id="home-c" label="C · Action + last-run peek" width={W} height={H}><Home_C /></DCArtboard>
      </DCSection>

      <DCSection id="history" title="4 · Session history" subtitle="Latest two runs, each tappable for detail.">
        <DCArtboard id="hist-a" label="A · Big number cards" width={W} height={H}><History_A /></DCArtboard>
        <DCArtboard id="hist-b" label="B · Date chip list" width={W} height={H}><History_B /></DCArtboard>
        <DCArtboard id="hist-c" label="C · Bold color blocks" width={W} height={H}><History_C /></DCArtboard>
      </DCSection>

      <DCSection id="metrics" title="5 · Metric detail" subtitle="Minimal — but every metric from the spec.">
        <DCArtboard id="m-a" label="A · Tile grid" width={W} height={H}><Metrics_A /></DCArtboard>
        <DCArtboard id="m-b" label="B · Grouped by theme" width={W} height={H}><Metrics_B /></DCArtboard>
        <DCArtboard id="m-c" label="C · Story scroll · read-aloud" width={W} height={H}><Metrics_C /></DCArtboard>
      </DCSection>

      <DCSection id="settings" title="6 · Settings" subtitle="Profile · Coaching · Support.">
        <DCArtboard id="set-a" label="A · Big buttons" width={W} height={H}><Settings_A /></DCArtboard>
        <DCArtboard id="set-b" label="B · Profile + list" width={W} height={H}><Settings_B /></DCArtboard>
        <DCArtboard id="set-c" label="C · Tile grid" width={W} height={H}><Settings_C /></DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
