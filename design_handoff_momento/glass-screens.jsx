/* global React */
const { DesignCanvas, DCSection, DCArtboard } = window;

/* =========================================================
   MOMENTO — Liquid Glass · final pass
   Consolidated picks:
   1. Sign in   — dark layout mirrored in light
   2. Onboard   — voice prompt, no buttons (voice on by default)
   3. Home      — centered CTA, top tabs, no "without coach"
   4. History   — coached cards, top tabs
   5. Metric    — hero number, "Hear summary" at top
   6. Settings  — dark inset rows, top tabs
   ========================================================= */

const Icon = ({ d, size = 22, w = 1.6, fill = "none" }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={fill}
    stroke="currentColor" strokeWidth={w}
    strokeLinecap="round" strokeLinejoin="round">
    {Array.isArray(d) ? d.map((p, i) => <path key={i} d={p} />) : <path d={d} />}
  </svg>
);

const I = {
  play:    <Icon d="M8 5.5l11 6.5-11 6.5z" fill="currentColor" w={0}/>,
  playOut: <Icon d="M8 5.5l11 6.5-11 6.5z"/>,
  mic:     <Icon d={["M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z","M5 11a7 7 0 0 0 14 0","M12 18v3"]} />,
  chev:    <Icon d="M9 5l7 7-7 7" w={2}/>,
  chevR:   <Icon d="M9 5l7 7-7 7"/>,
  back:    <Icon d="M15 5l-7 7 7 7" w={2}/>,
  x:       <Icon d="M6 6l12 12M18 6L6 18"/>,
  apple:   <Icon d={["M16.4 12.5c0-2.4 2-3.5 2.1-3.6-1.1-1.6-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.6.9-.8 0-1.9-.9-3.2-.9-1.6 0-3.2 1-4 2.5-1.7 2.9-.4 7.3 1.2 9.7.8 1.2 1.8 2.5 3.1 2.4 1.2-.05 1.7-.8 3.2-.8 1.4 0 1.9.8 3.2.8 1.3 0 2.2-1.2 3-2.4.9-1.3 1.3-2.7 1.3-2.7s-2.6-1-2.6-4z","M14.3 5.4c.7-.9 1.2-2.1 1-3.4-1.1.05-2.4.7-3.1 1.6-.7.8-1.3 2-1.1 3.2 1.2.1 2.5-.6 3.2-1.4z"]} fill="currentColor" w={0}/>,
  google:  <svg width="20" height="20" viewBox="0 0 24 24"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"/><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.65l-3.57-2.77c-.99.66-2.26 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84A11 11 0 0 0 12 23z"/><path fill="#FBBC05" d="M5.84 14.11A6.6 6.6 0 0 1 5.5 12c0-.73.13-1.44.34-2.11V7.05H2.18a11 11 0 0 0 0 9.9l3.66-2.84z"/><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.05l3.66 2.84C6.71 7.3 9.14 5.38 12 5.38z"/></svg>,
  speak:   <Icon d={["M5 9v6h4l5 4V5L9 9z","M16 8a5 5 0 0 1 0 8","M19 5a9 9 0 0 1 0 14"]} />,
  headph:  <Icon d={["M3 14v-2a9 9 0 0 1 18 0v2","M3 13h4v8H5a2 2 0 0 1-2-2v-6z","M17 13h4v6a2 2 0 0 1-2 2h-2v-8z"]} />,
  person:  <Icon d={["M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2","M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z"]} />,
  question: <Icon d={["M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z","M9.5 9a2.5 2.5 0 0 1 5 0c0 1.5-2.5 1.7-2.5 3.5","M12 17v.01"]} />,
  moon:    <Icon d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>,
  lock:    <Icon d={["M5 11h14v10H5z","M8 11V8a4 4 0 0 1 8 0v3"]}/>,
  mail:    <Icon d={["M3 7l9 6 9-6","M3 7h18v10H3z"]}/>,
  wave:    <Icon d="M3 12h2l2-7 4 14 4-10 2 5h4" w={2}/>,
  ruler:   <Icon d={["M3 8h18v8H3z","M7 8v3","M11 8v4","M15 8v3","M19 8v4"]}/>,
};

const StatusBar = ({ light }) => (
  <div className="statusbar">
    <span>9:41</span>
    <span className="right">
      <svg width="18" height="11" viewBox="0 0 18 11" fill="currentColor"><path d="M0 9a1 1 0 011-1h0a1 1 0 011 1v1a1 1 0 01-1 1H1a1 1 0 01-1-1V9zm4-2a1 1 0 011-1h0a1 1 0 011 1v3a1 1 0 01-1 1H5a1 1 0 01-1-1V7zm4-3a1 1 0 011-1h0a1 1 0 011 1v6a1 1 0 01-1 1H9a1 1 0 01-1-1V4zm4-3a1 1 0 011-1h0a1 1 0 011 1v9a1 1 0 01-1 1h0a1 1 0 01-1-1V1z"/></svg>
      <svg width="22" height="11" viewBox="0 0 22 11" fill="none" stroke="currentColor" strokeWidth="1">
        <rect x="0.5" y="0.5" width="18" height="10" rx="2.5"/>
        <rect x="2" y="2" width="15" height="7" rx="1.2" fill="currentColor"/>
        <rect x="19.5" y="3.5" width="1.5" height="4" rx="0.7" fill="currentColor"/>
      </svg>
    </span>
  </div>
);

/* Top tab — single shared segmented control */
const TopTabs = ({ on = "run" }) => (
  <div className="seg" style={{ marginTop: 10 }}>
    <div className={on === "run" ? "on" : ""}>Run</div>
    <div className={on === "history" ? "on" : ""}>History</div>
    <div className={on === "settings" ? "on" : ""}>Settings</div>
  </div>
);

const Phone = ({ children, backdrop = "bd-mist", dark = false }) => (
  <div className={"phone" + (dark ? " on-dark" : "")}>
    <div className={"backdrop " + backdrop}/>
    <StatusBar/>
    {children}
  </div>
);

/* ============================================================
   1 · SIGN IN — dark layout mirrored to light
   ============================================================ */

const SignInBody = () => (
  <>
    <div style={{ marginTop: 36, textAlign: "left" }}>
      <p className="eyebrow">welcome</p>
      <h1 className="title-xl" style={{ marginTop: 10, fontSize: 56 }}>Momento</h1>
    </div>

    <div style={{ display: "flex", justifyContent: "center" }}>
      <div className="orb" style={{ width: 196, height: 196 }}/>
    </div>

    <div className="glass" style={{ padding: 14, display: "flex", flexDirection: "column", gap: 8 }}>
      <button className="btn btn-block btn-lg btn-dark">
        {I.apple} Continue with Apple
      </button>
      <button className="btn btn-block btn-lg btn-glass">
        {I.google} Continue with Google
      </button>
      <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "2px 6px" }}>
        <div style={{ flex: 1, height: 0.5, background: "var(--hairline)" }}/>
        <span className="caption">or</span>
        <div style={{ flex: 1, height: 0.5, background: "var(--hairline)" }}/>
      </div>
      <button className="btn btn-block" style={{ background: "transparent", color: "var(--text-2)" }}>
        {I.mail} Use email
      </button>
    </div>
  </>
);

const Login_Light = () => (
  <Phone backdrop="bd-dawn">
    <div className="screen" style={{ justifyContent: "space-between", paddingBottom: 38 }}>
      <SignInBody/>
    </div>
  </Phone>
);

const Login_Dark = () => (
  <Phone backdrop="bd-night" dark>
    <div className="screen" style={{ justifyContent: "space-between", paddingBottom: 38 }}>
      <SignInBody/>
    </div>
  </Phone>
);

/* ============================================================
   2 · ONBOARDING — voice on by default, no buttons
   ============================================================ */

const Onboard_Voice = () => (
  <Phone backdrop="bd-mist">
    <div className="screen" style={{ paddingBottom: 38 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 4 }}>
        <button className="btn btn-icon btn-glass">{I.back}</button>
        <div className="segments" style={{ width: 130 }}>
          <div className="on"/><div className="on"/><div/><div/><div/>
        </div>
        <span className="caption">2 / 5</span>
      </div>

      <div style={{ marginTop: 28 }}>
        <p className="eyebrow">echo says</p>
        <h1 className="title-l" style={{ marginTop: 8 }}>What should I call you?</h1>
        <p className="callout muted-2" style={{ marginTop: 6 }}>
          Just say your name — I'm listening.
        </p>
      </div>

      <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 28 }}>
        <div style={{ position: "relative" }}>
          <div className="pulse-ring" style={{ borderColor: "rgba(11, 33, 70, 0.4)" }}/>
          <div className="orb"/>
        </div>
        <div className="wave">
          {[10,18,30,50,40,68,46,28,18,32,52,40,22,12].map((h,i)=>(
            <span key={i} style={{ height: h }}/>
          ))}
        </div>
        <p className="callout" style={{ color: "var(--text-2)", display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{
            width: 8, height: 8, borderRadius: "50%",
            background: "var(--verm)",
            boxShadow: "0 0 0 4px rgba(213, 94, 0, 0.18)",
          }}/>
          Listening
        </p>
      </div>
    </div>
  </Phone>
);

/* ============================================================
   3 · HOME — centered CTA, top tabs, no without-coach
   ============================================================ */

const Home_Center = () => (
  <Phone backdrop="bd-dawn">
    <div className="screen" style={{ paddingBottom: 28 }}>
      <TopTabs on="run"/>

      <div style={{ marginTop: 22, display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <p className="caption">TUE · MAY 23</p>
          <h1 className="title-l" style={{ marginTop: 4, fontSize: 36, letterSpacing: "-0.028em" }}>
            Ready, Priya?
          </h1>
          <p className="callout muted-2" style={{ marginTop: 6 }}>
            Last run was 4.2 km, easy.
          </p>
        </div>
        <span className="pill dot" style={{ marginTop: 6 }}>Watch on</span>
      </div>

      <div style={{ flex: 1, display: "flex", justifyContent: "center", alignItems: "center" }}>
        <button className="start-cta">
          <span className="ico accent" style={{ color: "var(--accent)" }}>{I.play}</span>
          <span className="ttl">Start run</span>
          <span className="lab">Live coach</span>
        </button>
      </div>

      <p className="footnote" style={{ textAlign: "center", margin: "8px 0 0" }}>
        Triple-tap anywhere to start.
      </p>
    </div>
  </Phone>
);

/* ============================================================
   4 · HISTORY — coached cards, top tabs
   ============================================================ */

const HistCard = ({ date, time, km, dur, pace, accent }) => (
  <button className="btn-hero glass" style={{ minHeight: 172, textAlign: "left" }}>
    <div style={{ display: "flex", justifyContent: "space-between", width: "100%" }}>
      <span className="pill" style={{ background: "rgba(228,135,0,0.14)", color: "var(--accent)" }}>
        <span className="ico" style={{ width: 14, height: 14, color: "var(--accent)" }}>{I.headph}</span>
        Coached
      </span>
      <span className="caption">{date} · {time}</span>
    </div>
    <div style={{ marginTop: "auto", width: "100%" }}>
      <div className="metric" style={{ marginBottom: 4 }}>
        <span className="v" style={{ fontSize: 56 }}>{km}</span>
        <span className="u">km</span>
      </div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <p className="callout muted-2 tabular">{dur} · {pace}</p>
        <span className="ico">{I.chev}</span>
      </div>
    </div>
  </button>
);

const History_Cards = () => (
  <Phone backdrop="bd-mist">
    <div className="screen" style={{ paddingBottom: 38 }}>
      <TopTabs on="history"/>

      <div style={{ marginTop: 22 }}>
        <p className="caption">YOUR RUNS</p>
        <h1 className="title-l" style={{ marginTop: 2 }}>History</h1>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 14, marginTop: 18 }}>
        <HistCard date="Yesterday"  time="7:14 AM" km="4.2" dur="34:12" pace="8:08 /mi"/>
        <HistCard date="Sun May 19" time="6:42 AM" km="5.0" dur="41:50" pace="8:22 /mi"/>
      </div>
    </div>
  </Phone>
);

/* ============================================================
   5 · METRIC DETAIL — hero number, summary at top, no share
   ============================================================ */

const Metrics_Hero = () => (
  <Phone backdrop="bd-dawn">
    <div className="screen scroll" style={{ paddingBottom: 20 }}>
      <div style={{ display: "flex", justifyContent: "flex-start", alignItems: "center", marginTop: 4 }}>
        <button className="pill" style={{ paddingLeft: 8 }}>
          <span className="ico" style={{ width: 16, height: 16 }}>{I.back}</span> History
        </button>
      </div>

      <button className="btn btn-block btn-lg btn-glass-strong" style={{ marginTop: 14 }}>
        {I.speak} Hear full summary
      </button>

      <p className="eyebrow" style={{ marginTop: 22 }}>Friday May 22 · 7:14 AM</p>
      <h1 className="title-l" style={{ marginTop: 4 }}>Morning run</h1>

      <div className="metric" style={{ marginTop: 14 }}>
        <span className="v">4.2</span>
        <span className="u">km</span>
      </div>
      <p className="callout muted-2" style={{ marginTop: 4 }}>
        in <b style={{ color: "var(--text)" }} className="tabular">34:12</b> · 8:08 /mi avg · coached
      </p>

      <div className="glass" style={{ marginTop: 18, padding: "4px 0" }}>
        <div className="mrow">
          <span className="label">Heart rate</span>
          <span><span className="v">152</span><span className="u">bpm avg</span></span>
        </div>
        <div className="mrow">
          <span className="label">Cadence</span>
          <span><span className="v">168</span><span className="u">spm</span></span>
        </div>
        <div className="mrow">
          <span className="label">Power</span>
          <span><span className="v">241</span><span className="u">w</span></span>
        </div>
        <div className="mrow">
          <span className="label">Stride length</span>
          <span><span className="v">1.14</span><span className="u">m</span></span>
        </div>
        <div className="mrow">
          <span className="label">Calories</span>
          <span><span className="v">312</span><span className="u">kcal</span></span>
        </div>
        <div className="mrow">
          <span className="label">Blood oxygen</span>
          <span><span className="v">97</span><span className="u">%</span></span>
        </div>
        <div className="mrow">
          <span className="label">Elevation gain</span>
          <span><span className="v">+38</span><span className="u">m</span></span>
        </div>
      </div>
    </div>
  </Phone>
);

/* ============================================================
   6 · SETTINGS — dark layout, top tabs, symmetric rows
   ============================================================ */

const SettingsRow = ({ icon, title, value, last }) => (
  <div className="item" style={{ minHeight: 56, padding: "14px 18px" }}>
    <span className="ico" style={{ width: 26, height: 26, flexShrink: 0 }}>{icon}</span>
    <div className="left">
      <p className="title">{title}</p>
    </div>
    {value && <span className="value" style={{ marginRight: 4 }}>{value}</span>}
    <span className="ico" style={{ width: 16, height: 16, flexShrink: 0 }}>{I.chevR}</span>
  </div>
);

const Settings_Dark = () => (
  <Phone backdrop="bd-mist">
    <div className="screen scroll" style={{ paddingBottom: 28 }}>
      <TopTabs on="settings"/>

      <h1 className="title-l" style={{ marginTop: 22 }}>Settings</h1>

      {/* Profile row */}
      <div className="glass" style={{ marginTop: 18, padding: 16, display: "flex", alignItems: "center", gap: 14 }}>
        <div style={{
          width: 48, height: 48, borderRadius: "50%",
          background: "rgba(11,11,15,0.85)", color: "#FFF",
          display: "flex", alignItems: "center", justifyContent: "center",
          fontWeight: 700, fontSize: 18, letterSpacing: "-0.01em",
          flexShrink: 0,
        }}>P</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <p className="title-s">Priya Shah</p>
          <p className="caption" style={{ marginTop: 2 }}>priya@example.com</p>
        </div>
        <span className="ico" style={{ width: 16, height: 16, flexShrink: 0 }}>{I.chevR}</span>
      </div>

      <p className="eyebrow" style={{ marginTop: 22, marginBottom: 10, paddingLeft: 4 }}>Profile</p>
      <div className="list">
        <SettingsRow icon={I.person}   title="Personal details"/>
      </div>

      <p className="eyebrow" style={{ marginTop: 22, marginBottom: 10, paddingLeft: 4 }}>Coaching</p>
      <div className="list">
        <SettingsRow icon={I.headph}   title="Echo's voice"   value="Maya"/>
        <SettingsRow icon={I.ruler}    title="Units"          value="Imperial"/>
      </div>

      <p className="eyebrow" style={{ marginTop: 22, marginBottom: 10, paddingLeft: 4 }}>Support</p>
      <div className="list">
        <SettingsRow icon={I.question} title="Help center"/>
        <SettingsRow icon={I.mail}     title="Contact us"/>
        <SettingsRow icon={I.lock}     title="Privacy &amp; data"/>
      </div>

      <button className="btn btn-block btn-lg btn-glass" style={{ marginTop: 18, color: "var(--verm)" }}>
        Sign out
      </button>

      <p className="footnote" style={{ textAlign: "center", marginTop: 14 }}>
        Momento v1.0
      </p>
    </div>
  </Phone>
);

/* ============================================================
   Compose
   ============================================================ */

const W = 430, H = 840;

function App() {
  return (
    <DesignCanvas
      title="MOMENTO — Liquid Glass · final"
      subtitle="Consolidated picks. Voice-default onboarding, centered start CTA, coached-only history, hero metric detail, dark settings. Top tabs throughout."
    >
      <DCSection id="login" title="1 · Sign in">
        <DCArtboard id="login-light" label="Sign in" width={W} height={H}><Login_Light/></DCArtboard>
      </DCSection>

      <DCSection id="onboard" title="2 · Onboarding" subtitle="Voice activation on by default.">
        <DCArtboard id="ob-voice" label="Listening" width={W} height={H}><Onboard_Voice/></DCArtboard>
      </DCSection>

      <DCSection id="home" title="3 · Home" subtitle="Centered start CTA.">
        <DCArtboard id="home-center" label="Run" width={W} height={H}><Home_Center/></DCArtboard>
      </DCSection>

      <DCSection id="history" title="4 · Session history">
        <DCArtboard id="hist-cards" label="Recent runs" width={W} height={H}><History_Cards/></DCArtboard>
      </DCSection>

      <DCSection id="metrics" title="5 · Metric detail">
        <DCArtboard id="m-hero" label="Run breakdown" width={W} height={H}><Metrics_Hero/></DCArtboard>
      </DCSection>

      <DCSection id="settings" title="6 · Settings">
        <DCArtboard id="set-dark" label="All settings" width={W} height={H}><Settings_Dark/></DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
