/* global React */
const { DesignCanvas, DCSection, DCArtboard } = window;

/* =========================================================
   MOMENTO — Hi-fi Apple-inspired pass
   Same 6 screens × 3 variants. New visual language:
   - System font stack (SF / Helvetica Neue fallback)
   - iOS HIG patterns: inset lists, segmented control, large titles,
     translucent tab bar, SF Symbols-flavored line icons
   - Button variety per section: filled / tinted / plain / glass / hero
   - Okabe-Ito accent palette retained (colorblind safe)
   ========================================================= */

/* ---------- Icons (line-style, neutral — not branded SF Symbols) ---------- */
const Icon = ({ name, size = 22, stroke = "currentColor", fill = "none", weight = 1.7 }) => {
  const props = {
    width: size, height: size, viewBox: "0 0 24 24",
    fill, stroke, strokeWidth: weight, strokeLinecap: "round", strokeLinejoin: "round",
  };
  switch (name) {
    case "play":      return <svg {...props}><path d="M7 5.5v13l11-6.5z" fill={stroke}/></svg>;
    case "play-out":  return <svg {...props}><path d="M7 5.5v13l11-6.5z"/></svg>;
    case "mic":       return <svg {...props}><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg>;
    case "wave":      return <svg {...props}><path d="M3 12h2M7 8v8M11 5v14M15 8v8M19 12h2"/></svg>;
    case "chev":      return <svg {...props}><path d="M9 6l6 6-6 6"/></svg>;
    case "chev-down": return <svg {...props}><path d="M6 9l6 6 6-6"/></svg>;
    case "back":      return <svg {...props}><path d="M15 6l-6 6 6 6"/></svg>;
    case "list":      return <svg {...props}><path d="M4 6h16M4 12h16M4 18h16"/></svg>;
    case "gear":      return <svg {...props}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1A1.7 1.7 0 0 0 9 19.4a1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.7 1.7 0 0 0 4.6 15a1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1A1.7 1.7 0 0 0 4.6 9a1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1A1.7 1.7 0 0 0 15 4.6a1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1A1.7 1.7 0 0 0 19.4 9c.1.4.5.7 1 1H21a2 2 0 1 1 0 4h-.1A1.7 1.7 0 0 0 19.4 15z"/></svg>;
    case "person":    return <svg {...props}><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-7 8-7s8 3 8 7"/></svg>;
    case "person-fill": return <svg {...props} fill={stroke} stroke="none"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-7 8-7s8 3 8 7"/></svg>;
    case "headphones":return <svg {...props}><path d="M3 14v-2a9 9 0 0 1 18 0v2"/><rect x="3" y="13" width="5" height="7" rx="2"/><rect x="16" y="13" width="5" height="7" rx="2"/></svg>;
    case "support":   return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 0 1 5 0c0 1.5-2.5 2-2.5 3.5M12 17v.5"/></svg>;
    case "heart":     return <svg {...props} fill={stroke} stroke="none"><path d="M12 21s-7-4.35-9.5-9C.83 8.5 3 4.5 6.5 4.5c1.74 0 3.41.81 4.5 2.09A6 6 0 0 1 17.5 4.5C21 4.5 23.17 8.5 21.5 12c-2.5 4.65-9.5 9-9.5 9z"/></svg>;
    case "bolt":      return <svg {...props} fill={stroke} stroke="none"><path d="M13 2L4 14h6l-1 8 9-12h-6l1-8z"/></svg>;
    case "stride":    return <svg {...props}><path d="M5 20l4-8 4 4 6-10"/></svg>;
    case "flame":     return <svg {...props}><path d="M12 3s4 4 4 8a4 4 0 0 1-8 0c0-2 1-3 1-3s-2 1-2 4a5 5 0 0 0 10 0c0-6-5-9-5-9z"/></svg>;
    case "lung":      return <svg {...props}><path d="M12 4v8M6 22c-3 0-3-4-3-8s2-9 5-9c1 0 2 1 2 2v7M18 22c3 0 3-4 3-8s-2-9-5-9c-1 0-2 1-2 2v7"/></svg>;
    case "wind":      return <svg {...props}><path d="M3 8h11a3 3 0 1 0-3-3M3 16h15a3 3 0 1 1-3 3M3 12h18"/></svg>;
    case "altitude":  return <svg {...props}><path d="M3 20l6-10 4 6 3-4 5 8z"/></svg>;
    case "share":     return <svg {...props}><path d="M12 3v13M8 7l4-4 4 4M5 14v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5"/></svg>;
    case "edit":      return <svg {...props}><path d="M4 20h4l10-10-4-4L4 16zM14 6l4 4"/></svg>;
    case "check":     return <svg {...props}><path d="M5 12l4 4 10-10"/></svg>;
    case "lock":      return <svg {...props}><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>;
    case "speaker":   return <svg {...props}><path d="M5 9v6h4l5 4V5L9 9z"/><path d="M16 8a5 5 0 0 1 0 8M19 5a9 9 0 0 1 0 14"/></svg>;
    case "moon":      return <svg {...props} fill={stroke} stroke="none"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>;
    case "apple":     return <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="9" opacity="0.15"/><text x="12" y="16" textAnchor="middle" fontSize="13" fontWeight="700" fill="currentColor" fontFamily="-apple-system, system-ui">A</text></svg>;
    case "google":    return <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="9" opacity="0.15"/><text x="12" y="16" textAnchor="middle" fontSize="13" fontWeight="700" fill="currentColor" fontFamily="-apple-system, system-ui">G</text></svg>;
    case "plus":      return <svg {...props}><path d="M12 5v14M5 12h14"/></svg>;
    case "minus":     return <svg {...props}><path d="M5 12h14"/></svg>;
    case "x":         return <svg {...props}><path d="M6 6l12 12M18 6l-12 12"/></svg>;
    case "dot":       return <svg {...props} fill={stroke} stroke="none"><circle cx="12" cy="12" r="4"/></svg>;
    default: return null;
  }
};

const StatusBar = () => (
  <div className="statusbar">
    <span>9:41</span>
    <span className="right">
      <svg width="18" height="11" viewBox="0 0 18 11" fill="currentColor"><path d="M0 9a1 1 0 011-1h0a1 1 0 011 1v1a1 1 0 01-1 1H1a1 1 0 01-1-1V9zm4-2a1 1 0 011-1h0a1 1 0 011 1v3a1 1 0 01-1 1H5a1 1 0 01-1-1V7zm4-3a1 1 0 011-1h0a1 1 0 011 1v6a1 1 0 01-1 1H9a1 1 0 01-1-1V4zm4-3a1 1 0 011-1h0a1 1 0 011 1v9a1 1 0 01-1 1h0a1 1 0 01-1-1V1z"/></svg>
      <svg width="22" height="11" viewBox="0 0 22 11" fill="none" stroke="currentColor" strokeWidth="1"><rect x="0.5" y="0.5" width="18" height="10" rx="2.5"/><rect x="2" y="2" width="15" height="7" rx="1.2" fill="currentColor"/><rect x="19.5" y="3.5" width="1.5" height="4" rx="0.7" fill="currentColor"/></svg>
    </span>
  </div>
);

const TabBar = ({ on = "run", dark }) => {
  const item = (key, label, glyph) => (
    <div className={on === key ? "on" : ""}>
      {glyph}
      <span>{label}</span>
    </div>
  );
  return (
    <div className="tabbar">
      {item("run", "Run", <Icon name="play" size={26} weight={2} />)}
      {item("history", "History", <Icon name="list" size={26} weight={2} />)}
      {item("settings", "Settings", <Icon name="gear" size={26} weight={1.5} />)}
    </div>
  );
};

const Phone = ({ children, dark = false }) => (
  <div className={"phone" + (dark ? " dark" : "")}>
    <StatusBar />
    {children}
  </div>
);

/* =========================================================
   1. LOGIN
   Button variety: filled-dark / filled-blue / tinted / glass
   ========================================================= */

const Login_A = () => (
  <Phone>
    <div className="screen" style={{ justifyContent: "space-between", paddingBottom: 32 }}>
      <div style={{ marginTop: 60 }}>
        <div style={{
          width: 64, height: 64, borderRadius: 18,
          background: "linear-gradient(160deg, var(--accent) 0%, #B86F00 100%)",
          display: "flex", alignItems: "center", justifyContent: "center",
          boxShadow: "0 12px 28px -8px rgba(229,138,0,0.5)",
        }}>
          <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#FFF" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M7 5.5v13l11-6.5z" fill="#FFF"/>
          </svg>
        </div>
        <h1 className="title-large" style={{ marginTop: 28, fontSize: 40 }}>Momento</h1>
        <p className="body muted-2" style={{ marginTop: 8 }}>
          A run-coach you can hear. Built for runners with low vision, blindness, and anyone who prefers their ears.
        </p>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        <button className="btn btn-filled dark btn-block btn-lg">
          <Icon name="apple" size={20}/> Continue with Apple
        </button>
        <button className="btn btn-bordered btn-block btn-lg">
          <Icon name="google" size={20}/> Continue with Google
        </button>
        <p className="footnote" style={{ textAlign: "center", marginTop: 6 }}>
          By continuing, you agree to our <span style={{ color: "var(--accent-2)" }}>Terms</span> &amp; <span style={{ color: "var(--accent-2)" }}>Privacy</span>.
        </p>
      </div>
    </div>
  </Phone>
);

const Login_B = () => (
  <Phone dark>
    <div className="screen" style={{ justifyContent: "space-between", paddingBottom: 30 }}>
      <div style={{ marginTop: 40, textAlign: "center" }}>
        <p className="eyebrow" style={{ color: "var(--accent)" }}>Welcome</p>
        <h1 className="title-large" style={{ marginTop: 8, fontSize: 44, letterSpacing: "-0.03em" }}>Momento</h1>
        <p className="callout" style={{ marginTop: 12, maxWidth: 280, marginLeft: "auto", marginRight: "auto" }}>
          Your coach lives in your ears. Sign in to bring Echo along.
        </p>
      </div>

      <div style={{ display: "flex", justifyContent: "center" }}>
        <div className="orb" style={{ width: 200, height: 200 }} />
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        <button className="btn btn-filled dark btn-block btn-lg">
          <Icon name="apple" size={20}/> Sign in with Apple
        </button>
        <button className="btn btn-glass btn-block btn-lg">
          <Icon name="google" size={20}/> Sign in with Google
        </button>
        <button className="btn btn-plain btn-block" style={{ color: "var(--text-3)", fontWeight: 500 }}>
          Use email instead
        </button>
      </div>
    </div>
  </Phone>
);

const Login_C = () => (
  <Phone>
    <div className="screen" style={{ justifyContent: "space-between", paddingBottom: 30 }}>
      <div style={{ marginTop: 56 }}>
        <h1 className="title-large" style={{ fontSize: 56, letterSpacing: "-0.035em", lineHeight: 0.95 }}>
          Hi.<br/>
          <span style={{ color: "var(--accent)" }}>It's us.</span>
        </h1>
        <p className="body muted-2" style={{ marginTop: 16, fontSize: 18 }}>
          Pick how you'd like to come in. We'll never read your runs to anyone but you.
        </p>
      </div>

      <div className="card elev" style={{ padding: 14, display: "flex", flexDirection: "column", gap: 8 }}>
        <button className="btn btn-filled dark btn-block btn-lg">
          <Icon name="apple" size={20}/> Continue with Apple
        </button>
        <button className="btn btn-tinted blue btn-block btn-lg">
          <Icon name="google" size={20}/> Continue with Google
        </button>
        <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "4px 4px 0" }}>
          <div style={{ flex: 1, height: 0.5, background: "var(--separator)" }} />
          <span className="caption" style={{ textTransform: "uppercase", letterSpacing: "0.06em" }}>or</span>
          <div style={{ flex: 1, height: 0.5, background: "var(--separator)" }} />
        </div>
        <button className="btn btn-plain btn-block">
          <Icon name="mic" size={18}/> Hold to hear my options
        </button>
      </div>
    </div>
  </Phone>
);

/* =========================================================
   2. ONBOARDING
   ========================================================= */

const Onboard_A = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 28 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 4 }}>
        <button className="pill"><Icon name="back" size={16}/> Back</button>
        <div className="dots">
          <span className="on"/><span className="on"/><span/><span/><span/>
        </div>
        <span className="caption">Step 2/5</span>
      </div>

      <h1 className="title-1" style={{ marginTop: 22, fontSize: 30 }}>
        What should I call you?
      </h1>
      <p className="callout muted-2" style={{ marginTop: 6 }}>
        Speak when you hear the chime, or type below.
      </p>

      <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 22 }}>
        <div style={{ position: "relative" }}>
          <div className="pulse" />
          <div className="orb" style={{ width: 180, height: 180 }} />
        </div>
        <div className="wave">
          {[12,22,38,56,42,68,48,30,18,34,56,42,24,14].map((h,i)=>(
            <span key={i} style={{ height: h }} />
          ))}
        </div>
        <p className="headline" style={{ color: "var(--accent-2)" }}>Listening…</p>
      </div>

      <div style={{ display: "flex", gap: 10 }}>
        <button className="btn btn-tinted gray" style={{ flex: 1 }}>Type instead</button>
        <button className="btn btn-filled" style={{ flex: 2 }}>
          <Icon name="mic" size={18}/> Tap to speak
        </button>
      </div>
    </div>
  </Phone>
);

const Onboard_B = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 28 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 4 }}>
        <button className="pill"><Icon name="back" size={16}/> Back</button>
        <span className="caption">3 OF 5</span>
        <span style={{ width: 50 }} />
      </div>

      {/* Progress segments */}
      <div style={{ display: "flex", gap: 4, marginTop: 14 }}>
        {[1,2,3,4,5].map(i => (
          <div key={i} style={{
            flex: 1, height: 4, borderRadius: 2,
            background: i <= 3 ? "var(--accent)" : "var(--separator)",
          }} />
        ))}
      </div>

      <h1 className="title-large" style={{ marginTop: 22 }}>Your height</h1>
      <p className="callout muted-2" style={{ marginTop: 6 }}>
        Helps Echo dial in pace and stride.
      </p>

      <div className="card elev" style={{ marginTop: 22, padding: "26px 18px", textAlign: "center" }}>
        <p className="eyebrow">Current</p>
        <div style={{ marginTop: 8, fontSize: 64, fontWeight: 700, letterSpacing: "-0.04em", lineHeight: 1 }}>
          5′ 9″
        </div>
        <p className="footnote" style={{ marginTop: 4 }}>175 cm</p>
        <div style={{ display: "flex", justifyContent: "center", gap: 14, marginTop: 18 }}>
          <button className="btn btn-tinted gray btn-icon" style={{ width: 56, height: 56 }}>
            <Icon name="minus" size={22} weight={2.2}/>
          </button>
          <button className="btn btn-tinted gray btn-icon" style={{ width: 56, height: 56 }}>
            <Icon name="plus" size={22} weight={2.2}/>
          </button>
        </div>
      </div>

      <div className="seg" style={{ marginTop: 14 }}>
        <div className="on">Imperial</div>
        <div>Metric</div>
      </div>

      <div style={{ flex: 1 }} />
      <div style={{ display: "flex", gap: 10 }}>
        <button className="btn btn-tinted gray btn-lg" style={{ flex: 1 }}>Skip</button>
        <button className="btn btn-filled btn-lg" style={{ flex: 2 }}>
          Continue <Icon name="chev" size={18}/>
        </button>
      </div>
    </div>
  </Phone>
);

const Onboard_C = () => (
  <Phone dark>
    <div className="screen" style={{ paddingBottom: 22 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 12, marginTop: 6 }}>
        <div className="orb" style={{ width: 44, height: 44, boxShadow: "0 6px 14px -4px rgba(31,107,176,0.5)" }} />
        <div style={{ flex: 1 }}>
          <p className="headline">Echo</p>
          <p className="caption" style={{ color: "var(--green)" }}>● Listening</p>
        </div>
        <button className="btn btn-icon" style={{ background: "rgba(255,255,255,0.08)" }}>
          <Icon name="x" size={18}/>
        </button>
      </div>

      <div style={{
        display: "flex", flexDirection: "column", gap: 10, marginTop: 18,
        flex: 1, overflow: "hidden",
      }}>
        <div className="bubble">Nice to meet you. What should I call you?</div>
        <div className="bubble user">Priya</div>
        <div className="bubble">Hi Priya — how old are you?</div>
        <div className="bubble user">Thirty-four</div>
        <div className="bubble">And your weight, roughly?</div>
        <div className="bubble" style={{ opacity: 0.7, fontStyle: "italic" }}>
          <span style={{ display: "inline-flex", gap: 4 }}>
            <span style={{ width: 6, height: 6, borderRadius: 3, background: "currentColor", opacity: 0.9 }}/>
            <span style={{ width: 6, height: 6, borderRadius: 3, background: "currentColor", opacity: 0.6 }}/>
            <span style={{ width: 6, height: 6, borderRadius: 3, background: "currentColor", opacity: 0.3 }}/>
          </span>
        </div>
      </div>

      <button className="btn btn-filled btn-block btn-xl" style={{ marginTop: 14, borderRadius: 999, gap: 12 }}>
        <Icon name="mic" size={22}/> Hold to speak
      </button>
    </div>
  </Phone>
);

/* =========================================================
   3. HOME
   ========================================================= */

const Home_A = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <div style={{ marginTop: 4, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <p className="caption">Tuesday, May 23</p>
          <h1 className="title-large" style={{ marginTop: 2 }}>Hi, Priya</h1>
        </div>
        <div className="avatar">P</div>
      </div>

      <div className="seg" style={{ marginTop: 18 }}>
        <div className="on">Start run</div>
        <div>History</div>
        <div>Settings</div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 14, marginTop: 18, flex: 1 }}>
        <button className="btn btn-hero" style={{
          background: "linear-gradient(160deg, var(--accent) 0%, #B86F00 100%)",
          color: "#FFF", flex: 1.1,
          boxShadow: "0 14px 30px -10px rgba(229,138,0,0.5)",
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <Icon name="headphones" size={26} weight={2}/>
            <span className="caption" style={{ color: "rgba(255,255,255,0.85)", letterSpacing: "0.08em" }}>WITH LIVE COACH</span>
          </div>
          <div style={{ alignSelf: "stretch", display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
            <span>Start run with Echo</span>
            <Icon name="chev" size={24} weight={2.2}/>
          </div>
        </button>

        <button className="btn btn-hero btn-bordered" style={{ flex: 1 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <Icon name="play-out" size={24} weight={2}/>
            <span className="caption" style={{ letterSpacing: "0.08em" }}>SOLO · METRICS ONLY</span>
          </div>
          <div style={{ alignSelf: "stretch", display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
            <span>Start without coach</span>
            <Icon name="chev" size={24} weight={2.2} stroke="var(--text-3)"/>
          </div>
        </button>
      </div>
    </div>
    <TabBar on="run" />
  </Phone>
);

const Home_B = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 4 }}>
        <p className="caption">MOMENTO</p>
        <span className="pill green"><span style={{ width: 6, height: 6, borderRadius: 3, background: "var(--green)" }}/> Watch connected</span>
      </div>

      <h1 className="title-large" style={{ marginTop: 18, fontSize: 38, letterSpacing: "-0.03em" }}>
        Hi Priya.<br/>
        <span style={{ color: "var(--text-3)" }}>Let's move.</span>
      </h1>

      <div style={{ display: "flex", justifyContent: "center", margin: "32px 0 22px" }}>
        <button className="rec-cta">
          Start run
          <small>With live coach</small>
        </button>
      </div>

      <button className="btn btn-tinted gray btn-block btn-lg">
        <Icon name="play-out" size={18}/> Start without coach
      </button>

      <p className="footnote" style={{ textAlign: "center", marginTop: 12 }}>
        Triple-tap anywhere to start with coach
      </p>

      <div style={{ flex: 1 }} />
    </div>
    <TabBar on="run" />
  </Phone>
);

const Home_C = () => (
  <Phone dark>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <div style={{ marginTop: 4 }}>
        <p className="caption">TODAY · TUE MAY 23</p>
        <h1 className="title-large" style={{ marginTop: 4 }}>Good morning, Priya</h1>
      </div>

      <button className="btn btn-hero" style={{
        marginTop: 18,
        background: "linear-gradient(165deg, var(--accent) 0%, #B86F00 100%)",
        color: "#FFF",
        minHeight: 168,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <Icon name="headphones" size={26} weight={2}/>
          <span className="caption" style={{ color: "rgba(255,255,255,0.85)", letterSpacing: "0.08em" }}>RECOMMENDED</span>
        </div>
        <div style={{ alignSelf: "stretch" }}>
          <div style={{ fontSize: 30, fontWeight: 700, letterSpacing: "-0.025em" }}>Start run</div>
          <div style={{ fontSize: 16, opacity: 0.85, fontWeight: 500, marginTop: 2 }}>Echo coaches you live</div>
        </div>
      </button>

      <button className="btn btn-block btn-lg" style={{
        marginTop: 12, background: "rgba(255,255,255,0.08)", color: "#FFF",
        justifyContent: "space-between",
      }}>
        <span style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <Icon name="play-out" size={20}/> Start without coach
        </span>
        <Icon name="chev" size={20} stroke="rgba(255,255,255,0.5)"/>
      </button>

      <div className="hr" />
      <p className="eyebrow" style={{ marginTop: 4 }}>Last run</p>
      <div className="card" style={{ marginTop: 8, background: "rgba(255,255,255,0.06)", padding: 14, display: "flex", alignItems: "center", gap: 14 }}>
        <div className="ico-tile ico-orange" style={{ width: 38, height: 38, borderRadius: 10 }}>
          <Icon name="play" size={18}/>
        </div>
        <div style={{ flex: 1 }}>
          <p className="headline">Yesterday · 4.2 km</p>
          <p className="caption">34:12 · avg 8:08 /mi · coached</p>
        </div>
        <Icon name="chev" size={18} stroke="rgba(255,255,255,0.4)"/>
      </div>

      <div style={{ flex: 1 }} />
    </div>
    <TabBar on="run" dark />
  </Phone>
);

/* =========================================================
   4. HISTORY
   ========================================================= */

const History_A = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <div style={{ marginTop: 4 }}>
        <p className="caption">YOUR RUNS</p>
        <h1 className="title-large" style={{ marginTop: 2 }}>History</h1>
      </div>

      <div className="seg" style={{ marginTop: 16 }}>
        <div>Start run</div>
        <div className="on">History</div>
        <div>Settings</div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 12, marginTop: 18 }}>
        <button className="card elev" style={{
          border: "none", textAlign: "left", padding: 18, cursor: "pointer",
          background: "var(--bg-elev)",
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <span className="pill accent"><Icon name="headphones" size={13}/> Coached</span>
            <span className="caption">Yesterday · 7:14 AM</span>
          </div>
          <div className="hero-stat" style={{ marginTop: 12 }}>
            <span className="big" style={{ fontSize: 56 }}>4.2</span>
            <span className="unit">km</span>
          </div>
          <p className="callout muted-2" style={{ marginTop: 4 }}>34:12 · avg 8:08 /mi</p>
          <div className="hr" />
          <div style={{ display: "flex", justifyContent: "space-between", color: "var(--accent-2)" }}>
            <span className="headline" style={{ color: "var(--accent-2)" }}>See full breakdown</span>
            <Icon name="chev" size={20}/>
          </div>
        </button>

        <button className="card elev" style={{
          border: "none", textAlign: "left", padding: 18, cursor: "pointer",
          background: "var(--bg-elev)",
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <span className="pill"><Icon name="play-out" size={12}/> Solo</span>
            <span className="caption">Sun May 19 · 6:42 AM</span>
          </div>
          <div className="hero-stat" style={{ marginTop: 12 }}>
            <span className="big" style={{ fontSize: 56 }}>5.0</span>
            <span className="unit">km</span>
          </div>
          <p className="callout muted-2" style={{ marginTop: 4 }}>41:50 · avg 8:22 /mi</p>
          <div className="hr" />
          <div style={{ display: "flex", justifyContent: "space-between", color: "var(--accent-2)" }}>
            <span className="headline" style={{ color: "var(--accent-2)" }}>See full breakdown</span>
            <Icon name="chev" size={20}/>
          </div>
        </button>
      </div>

      <div style={{ flex: 1 }} />
      <p className="footnote" style={{ textAlign: "center", paddingBottom: 14 }}>
        Older runs sync to your phone's Health app.
      </p>
    </div>
    <TabBar on="history" />
  </Phone>
);

const History_B = () => (
  <Phone>
    <div className="screen scroll" style={{ paddingBottom: 0 }}>
      <h1 className="title-large" style={{ marginTop: 4 }}>History</h1>
      <p className="callout muted-2" style={{ marginTop: 4 }}>2 sessions</p>

      <p className="eyebrow" style={{ marginTop: 22, marginBottom: 8, paddingLeft: 4 }}>This week</p>
      <div className="list">
        <div className="item large">
          <div className="ico-tile ico-orange" style={{ width: 40, height: 40, borderRadius: 10 }}>
            <Icon name="headphones" size={20}/>
          </div>
          <div className="left">
            <p className="title" style={{ fontWeight: 600 }}>4.2 km</p>
            <p className="subtitle">Yesterday · 34:12 · coached</p>
          </div>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
        <div className="item large">
          <div className="ico-tile ico-blue" style={{ width: 40, height: 40, borderRadius: 10 }}>
            <Icon name="play-out" size={20}/>
          </div>
          <div className="left">
            <p className="title" style={{ fontWeight: 600 }}>5.0 km</p>
            <p className="subtitle">Sun May 19 · 41:50 · solo</p>
          </div>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
      </div>

      <p className="eyebrow" style={{ marginTop: 22, marginBottom: 8, paddingLeft: 4 }}>Totals</p>
      <div className="list">
        <div className="item">
          <div className="left">
            <p className="title">Distance this week</p>
          </div>
          <p className="headline">9.2 km</p>
        </div>
        <div className="item">
          <div className="left">
            <p className="title">Time on feet</p>
          </div>
          <p className="headline">1h 16m</p>
        </div>
        <div className="item">
          <div className="left">
            <p className="title">Avg pace</p>
          </div>
          <p className="headline">8:15 /mi</p>
        </div>
      </div>

      <p className="footnote" style={{ textAlign: "center", paddingBottom: 14, marginTop: 16 }}>
        Older runs sync to the Health app.
      </p>
    </div>
    <TabBar on="history" />
  </Phone>
);

const History_C = () => (
  <Phone dark>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginTop: 4 }}>
        <div>
          <p className="caption">RECENT</p>
          <h1 className="title-large" style={{ marginTop: 2 }}>Runs</h1>
        </div>
        <button className="btn btn-icon" style={{ background: "rgba(255,255,255,0.08)" }}>
          <Icon name="share" size={18}/>
        </button>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 14, marginTop: 22 }}>
        <button className="btn btn-hero" style={{
          background: "linear-gradient(160deg, var(--accent) 0%, #9F5F00 100%)",
          color: "#FFF", minHeight: 180,
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", width: "100%" }}>
            <span className="caption" style={{ color: "rgba(255,255,255,0.85)" }}>YESTERDAY · COACHED</span>
            <Icon name="headphones" size={20}/>
          </div>
          <div style={{ alignSelf: "stretch" }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
              <span style={{ fontSize: 64, fontWeight: 700, letterSpacing: "-0.04em", lineHeight: 0.95 }}>4.2</span>
              <span style={{ fontSize: 16, fontWeight: 600, opacity: 0.85 }}>km</span>
            </div>
            <div style={{ marginTop: 4, opacity: 0.9, fontSize: 15 }}>34:12 · 8:08 /mi</div>
          </div>
        </button>

        <button className="btn btn-hero" style={{
          background: "rgba(10, 132, 255, 0.18)",
          color: "#FFF", minHeight: 180,
          boxShadow: "inset 0 0 0 0.5px rgba(255,255,255,0.08)",
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", width: "100%" }}>
            <span className="caption" style={{ color: "rgba(235,235,245,0.6)" }}>SUN MAY 19 · SOLO</span>
            <Icon name="play-out" size={20}/>
          </div>
          <div style={{ alignSelf: "stretch" }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
              <span style={{ fontSize: 64, fontWeight: 700, letterSpacing: "-0.04em", lineHeight: 0.95 }}>5.0</span>
              <span style={{ fontSize: 16, fontWeight: 600, opacity: 0.85 }}>km</span>
            </div>
            <div style={{ marginTop: 4, opacity: 0.9, fontSize: 15 }}>41:50 · 8:22 /mi</div>
          </div>
        </button>
      </div>

      <div style={{ flex: 1 }} />
    </div>
    <TabBar on="history" dark />
  </Phone>
);

/* =========================================================
   5. METRIC DETAIL
   ========================================================= */

const MetricTile = ({ icon, label, value, unit, color = "ico-gray" }) => (
  <div className="tile">
    <div className="tile-label">
      <span className={"ico-tile " + color} style={{ width: 22, height: 22, borderRadius: 6 }}>
        <Icon name={icon} size={13} weight={2}/>
      </span>
      {label}
    </div>
    <div className="tile-value">{value}</div>
    <div className="tile-unit">{unit}</div>
  </div>
);

const Metrics_A = () => (
  <Phone>
    <div className="screen scroll" style={{ paddingBottom: 16 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 4 }}>
        <button className="pill"><Icon name="back" size={16}/> History</button>
        <button className="btn btn-icon"><Icon name="share" size={18}/></button>
      </div>

      <p className="caption" style={{ marginTop: 18 }}>FRIDAY MAY 22 · 7:14 AM</p>
      <h1 className="title-large" style={{ marginTop: 2 }}>Morning run</h1>

      <div className="hero-stat" style={{ marginTop: 14 }}>
        <span className="big">4.2</span>
        <span className="unit">km</span>
      </div>
      <p className="callout muted-2" style={{ marginTop: 4 }}>
        in <b>34:12</b> · 8:08 /mi avg pace · coached by Echo
      </p>

      <div className="hr" />

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        <MetricTile icon="heart" label="Heart rate" value="152" unit="AVG BPM" color="ico-verm"/>
        <MetricTile icon="stride" label="Cadence" value="168" unit="STEPS / MIN" color="ico-orange"/>
        <MetricTile icon="bolt" label="Power" value="241" unit="WATTS" color="ico-yellow"/>
        <MetricTile icon="stride" label="Stride" value="1.14" unit="METERS" color="ico-blue"/>
        <MetricTile icon="flame" label="Calories" value="312" unit="KCAL" color="ico-orange"/>
        <MetricTile icon="lung" label="SpO₂" value="97" unit="PERCENT" color="ico-sky"/>
        <MetricTile icon="altitude" label="Elevation" value="+38" unit="METERS" color="ico-green"/>
        <MetricTile icon="wind" label="Resp. rate" value="22" unit="BREATHS / MIN" color="ico-sky"/>
      </div>

      <button className="btn btn-tinted btn-block btn-lg" style={{ marginTop: 16 }}>
        <Icon name="speaker" size={20}/> Hear full summary
      </button>
    </div>
  </Phone>
);

const Metrics_B = () => (
  <Phone>
    <div className="screen scroll" style={{ paddingBottom: 16 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 4 }}>
        <button className="pill"><Icon name="back" size={16}/> Back</button>
        <button className="pill"><Icon name="share" size={14}/> Share</button>
      </div>

      <div className="card dark-fill" style={{
        marginTop: 16, padding: 20,
        background: "#0B0B0F", color: "#FFF",
        borderRadius: 22,
      }}>
        <p className="caption" style={{ color: "rgba(255,255,255,0.6)" }}>FRI MAY 22 · MORNING RUN</p>
        <div style={{ display: "flex", alignItems: "baseline", gap: 10, marginTop: 10 }}>
          <span style={{ fontSize: 68, fontWeight: 700, letterSpacing: "-0.04em", color: "var(--accent)", lineHeight: 0.9 }}>4.2</span>
          <span style={{ fontSize: 16, color: "rgba(255,255,255,0.7)", fontWeight: 600 }}>KM</span>
        </div>
        <div style={{ display: "flex", gap: 18, marginTop: 12 }}>
          <div>
            <p className="caption" style={{ color: "rgba(255,255,255,0.5)" }}>TIME</p>
            <p style={{ fontSize: 18, fontWeight: 600, marginTop: 2 }}>34:12</p>
          </div>
          <div style={{ width: 0.5, background: "rgba(255,255,255,0.15)" }}/>
          <div>
            <p className="caption" style={{ color: "rgba(255,255,255,0.5)" }}>AVG PACE</p>
            <p style={{ fontSize: 18, fontWeight: 600, marginTop: 2 }}>8:08 /mi</p>
          </div>
          <div style={{ width: 0.5, background: "rgba(255,255,255,0.15)" }}/>
          <div>
            <p className="caption" style={{ color: "rgba(255,255,255,0.5)" }}>CALS</p>
            <p style={{ fontSize: 18, fontWeight: 600, marginTop: 2 }}>312</p>
          </div>
        </div>
      </div>

      <p className="eyebrow" style={{ marginTop: 18, marginBottom: 8, paddingLeft: 4 }}>The heart of it</p>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8 }}>
        <MetricTile icon="heart" label="Avg HR" value="152" unit="BPM" color="ico-verm"/>
        <MetricTile icon="heart" label="Peak HR" value="171" unit="BPM" color="ico-verm"/>
        <MetricTile icon="dot" label="HRV" value="52" unit="MS" color="ico-orange"/>
      </div>

      <p className="eyebrow" style={{ marginTop: 16, marginBottom: 8, paddingLeft: 4 }}>Form</p>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8 }}>
        <MetricTile icon="stride" label="Cadence" value="168" unit="SPM" color="ico-orange"/>
        <MetricTile icon="stride" label="Stride" value="1.14" unit="M" color="ico-blue"/>
        <MetricTile icon="bolt" label="Power" value="241" unit="W" color="ico-yellow"/>
      </div>

      <p className="eyebrow" style={{ marginTop: 16, marginBottom: 8, paddingLeft: 4 }}>Body</p>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8 }}>
        <MetricTile icon="lung" label="SpO₂" value="97" unit="%" color="ico-sky"/>
        <MetricTile icon="wind" label="Resp" value="22" unit="/MIN" color="ico-sky"/>
        <MetricTile icon="altitude" label="Elev" value="+38" unit="M" color="ico-green"/>
      </div>
    </div>
  </Phone>
);

const Metrics_C = () => (
  <Phone dark>
    <div className="screen scroll" style={{ paddingBottom: 16 }}>
      <button className="pill" style={{ alignSelf: "flex-start", marginTop: 4, background: "rgba(255,255,255,0.08)" }}>
        <Icon name="back" size={16}/> All runs
      </button>

      <p className="caption" style={{ marginTop: 18, color: "var(--accent)" }}>YESTERDAY MORNING</p>
      <h1 className="title-large" style={{ marginTop: 4 }}>
        Your run,<br/>by the numbers.
      </h1>

      <div style={{
        marginTop: 18, padding: 22,
        borderRadius: 24,
        background: "linear-gradient(160deg, rgba(255,159,10,0.25) 0%, rgba(255,159,10,0.06) 100%)",
        border: "0.5px solid rgba(255,159,10,0.3)",
      }}>
        <p className="caption" style={{ color: "var(--accent)" }}>DISTANCE</p>
        <div style={{ display: "flex", alignItems: "baseline", gap: 8, marginTop: 4 }}>
          <span style={{ fontSize: 88, fontWeight: 700, letterSpacing: "-0.045em", lineHeight: 0.9 }}>4.2</span>
          <span style={{ fontSize: 18, fontWeight: 600, color: "var(--text-3)" }}>km</span>
        </div>
        <p className="callout muted-2" style={{ marginTop: 6 }}>34:12 · 8:08 /mi avg</p>
      </div>

      <div className="list" style={{ marginTop: 16, background: "rgba(255,255,255,0.05)" }}>
        {[
          ["heart","Heart rate (avg)","152","BPM","ico-verm"],
          ["stride","Cadence","168","STEPS/MIN","ico-orange"],
          ["bolt","Running power","241","WATTS","ico-yellow"],
          ["stride","Stride length","1.14","METERS","ico-blue"],
          ["flame","Calories","312","KCAL","ico-orange"],
          ["lung","Blood oxygen","97","PERCENT","ico-sky"],
          ["altitude","Elevation gain","+38","METERS","ico-green"],
        ].map(([icon,label,v,u,c],i)=>(
          <div className="item" key={i}>
            <span className={"ico-tile " + c}>
              <Icon name={icon} size={16} weight={2}/>
            </span>
            <div className="left">
              <p className="title" style={{ color: "#FFF" }}>{label}</p>
            </div>
            <div style={{ textAlign: "right" }}>
              <p style={{ fontSize: 18, fontWeight: 700, color: "#FFF", letterSpacing: "-0.015em", lineHeight: 1 }}>{v}</p>
              <p className="caption" style={{ marginTop: 2 }}>{u}</p>
            </div>
          </div>
        ))}
      </div>

      <button className="btn btn-filled btn-block btn-lg" style={{ marginTop: 16, borderRadius: 999, gap: 10 }}>
        <Icon name="speaker" size={20}/> Play summary
      </button>
    </div>
  </Phone>
);

/* =========================================================
   6. SETTINGS
   ========================================================= */

const Settings_A = () => (
  <Phone>
    <div className="screen scroll" style={{ paddingBottom: 0 }}>
      <h1 className="title-large" style={{ marginTop: 4 }}>Settings</h1>

      <div className="card" style={{
        marginTop: 18, padding: 14, display: "flex", alignItems: "center", gap: 14,
      }}>
        <div className="avatar" style={{ width: 52, height: 52, fontSize: 20 }}>P</div>
        <div style={{ flex: 1 }}>
          <p className="headline">Priya Shah</p>
          <p className="caption" style={{ marginTop: 2 }}>34 · 5′9″ · 142 lb · she/they</p>
        </div>
        <Icon name="chev" size={18} stroke="var(--text-4)"/>
      </div>

      <p className="eyebrow" style={{ marginTop: 22, marginBottom: 8, paddingLeft: 4 }}>Account</p>
      <div className="list">
        <div className="item large">
          <span className="ico-tile ico-blue"><Icon name="person" size={16} weight={2}/></span>
          <div className="left">
            <p className="title">Profile</p>
            <p className="subtitle">Name, age, body, goals</p>
          </div>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
        <div className="item large">
          <span className="ico-tile ico-orange"><Icon name="headphones" size={16} weight={2}/></span>
          <div className="left">
            <p className="title">Coaching</p>
            <p className="subtitle">Echo's voice, cadence, tone</p>
          </div>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
        <div className="item large">
          <span className="ico-tile ico-green"><Icon name="support" size={16} weight={2}/></span>
          <div className="left">
            <p className="title">Support</p>
            <p className="subtitle">Help, contact, about</p>
          </div>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
      </div>

      <p className="eyebrow" style={{ marginTop: 22, marginBottom: 8, paddingLeft: 4 }}>App</p>
      <div className="list">
        <div className="item">
          <span className="ico-tile ico-gray"><Icon name="moon" size={14}/></span>
          <div className="left"><p className="title">Appearance</p></div>
          <p className="caption">System</p>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
        <div className="item">
          <span className="ico-tile ico-gray"><Icon name="lock" size={14} weight={2}/></span>
          <div className="left"><p className="title">Privacy</p></div>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
      </div>

      <p className="footnote" style={{ textAlign: "center", marginTop: 18, paddingBottom: 12 }}>
        Momento · v1.0 (build 23)
      </p>
    </div>
    <TabBar on="settings" />
  </Phone>
);

const Settings_B = () => (
  <Phone>
    <div className="screen" style={{ paddingBottom: 0 }}>
      <h1 className="title-large" style={{ marginTop: 4 }}>Settings</h1>
      <p className="callout muted-2" style={{ marginTop: 4 }}>Yours. Tweak it.</p>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginTop: 20 }}>
        <button className="card elev" style={{
          padding: 18, textAlign: "left", border: "none", cursor: "pointer",
          minHeight: 158, display: "flex", flexDirection: "column", justifyContent: "space-between",
          background: "var(--bg-elev)",
        }}>
          <div className="ico-tile ico-blue" style={{ width: 36, height: 36, borderRadius: 10 }}>
            <Icon name="person-fill" size={18}/>
          </div>
          <div>
            <p className="headline" style={{ fontSize: 18 }}>Profile</p>
            <p className="caption" style={{ marginTop: 2 }}>Your details</p>
          </div>
        </button>

        <button className="card elev" style={{
          padding: 18, textAlign: "left", border: "none", cursor: "pointer",
          minHeight: 158, display: "flex", flexDirection: "column", justifyContent: "space-between",
          background: "var(--accent)", color: "#FFF",
        }}>
          <div style={{
            width: 36, height: 36, borderRadius: 10,
            background: "rgba(255,255,255,0.2)",
            display: "flex", alignItems: "center", justifyContent: "center",
          }}>
            <Icon name="headphones" size={18} weight={2}/>
          </div>
          <div>
            <p className="headline" style={{ fontSize: 18 }}>Coaching</p>
            <p className="caption" style={{ marginTop: 2, color: "rgba(255,255,255,0.85)" }}>Echo's voice</p>
          </div>
        </button>

        <button className="card elev" style={{
          padding: 18, textAlign: "left", border: "none", cursor: "pointer",
          minHeight: 158, display: "flex", flexDirection: "column", justifyContent: "space-between",
          background: "var(--bg-elev)",
        }}>
          <div className="ico-tile ico-green" style={{ width: 36, height: 36, borderRadius: 10 }}>
            <Icon name="support" size={18} weight={2}/>
          </div>
          <div>
            <p className="headline" style={{ fontSize: 18 }}>Support</p>
            <p className="caption" style={{ marginTop: 2 }}>Help &amp; contact</p>
          </div>
        </button>

        <button className="card" style={{
          padding: 18, textAlign: "left", border: "0.5px dashed var(--separator-strong)",
          minHeight: 158, display: "flex", flexDirection: "column", justifyContent: "space-between",
          background: "transparent", cursor: "pointer",
        }}>
          <div className="ico-tile" style={{
            width: 36, height: 36, borderRadius: 10,
            background: "var(--tint-gray)", color: "var(--text-2)",
          }}>
            <Icon name="moon" size={18}/>
          </div>
          <div>
            <p className="headline" style={{ fontSize: 18 }}>Appearance</p>
            <p className="caption" style={{ marginTop: 2 }}>Light · Dark · System</p>
          </div>
        </button>
      </div>

      <button className="btn btn-tinted btn-block btn-lg" style={{
        marginTop: 18, background: "rgba(213, 94, 0, 0.12)", color: "var(--verm)",
      }}>
        Sign out
      </button>

      <div style={{ flex: 1 }} />
      <p className="footnote" style={{ textAlign: "center", paddingBottom: 14 }}>
        Made for runners, accessible to all.
      </p>
    </div>
    <TabBar on="settings" />
  </Phone>
);

const Settings_C = () => (
  <Phone dark>
    <div className="screen scroll" style={{ paddingBottom: 0 }}>
      <h1 className="title-large" style={{ marginTop: 4 }}>Settings</h1>

      <p className="eyebrow" style={{ marginTop: 22, marginBottom: 8, paddingLeft: 4 }}>Profile</p>
      <div className="list" style={{ background: "var(--bg-elev)" }}>
        <div className="item large">
          <div className="avatar" style={{ width: 40, height: 40 }}>P</div>
          <div className="left">
            <p className="title">Priya Shah</p>
            <p className="subtitle">priya@example.com</p>
          </div>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
      </div>

      <p className="eyebrow" style={{ marginTop: 22, marginBottom: 8, paddingLeft: 4 }}>Coaching</p>
      <div className="list" style={{ background: "var(--bg-elev)" }}>
        <div className="item">
          <span className="ico-tile ico-orange"><Icon name="headphones" size={14} weight={2}/></span>
          <div className="left"><p className="title">Echo's voice</p></div>
          <p className="caption">Maya — warm</p>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
        <div className="item">
          <span className="ico-tile ico-blue"><Icon name="wave" size={14} weight={2}/></span>
          <div className="left"><p className="title">Chattiness</p></div>
          <p className="caption">Balanced</p>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
        <div className="item">
          <span className="ico-tile ico-green"><Icon name="check" size={14} weight={2.5}/></span>
          <div className="left"><p className="title">Units</p></div>
          <p className="caption">Imperial</p>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
      </div>

      <p className="eyebrow" style={{ marginTop: 22, marginBottom: 8, paddingLeft: 4 }}>Help</p>
      <div className="list" style={{ background: "var(--bg-elev)" }}>
        <div className="item">
          <span className="ico-tile ico-gray"><Icon name="support" size={14} weight={2}/></span>
          <div className="left"><p className="title">Support</p></div>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
        <div className="item">
          <span className="ico-tile ico-gray"><Icon name="lock" size={14} weight={2}/></span>
          <div className="left"><p className="title">Privacy &amp; data</p></div>
          <Icon name="chev" size={18} stroke="var(--text-4)"/>
        </div>
      </div>

      <button className="btn btn-block btn-lg" style={{
        marginTop: 18, color: "var(--verm)", background: "rgba(213, 94, 0, 0.18)",
      }}>
        Sign out
      </button>

      <p className="footnote" style={{ textAlign: "center", marginTop: 14, paddingBottom: 12 }}>
        Momento · v1.0
      </p>
    </div>
    <TabBar on="settings" dark />
  </Phone>
);

/* =========================================================
   Compose
   ========================================================= */

const W = 430, H = 840;

function App() {
  return (
    <DesignCanvas
      title="MOMENTO — Hi-fi"
      subtitle="Apple-inspired refinement. System type, refined button treatments (filled / tinted / plain / glass / hero), iOS list & segmented control patterns, OLED dark-mode variants. Okabe-Ito accent palette retained for colorblind safety."
    >
      <DCSection id="login" title="1 · Sign in" subtitle="Apple + Google. Filled-dark vs glass vs tinted treatments.">
        <DCArtboard id="login-a" label="A · Light, bordered Google" width={W} height={H}><Login_A /></DCArtboard>
        <DCArtboard id="login-b" label="B · Dark with glass button" width={W} height={H}><Login_B /></DCArtboard>
        <DCArtboard id="login-c" label="C · Card-housed CTAs" width={W} height={H}><Login_C /></DCArtboard>
      </DCSection>

      <DCSection id="onboard" title="2 · Onboarding" subtitle="Name, age, gender, height, weight — guided by Echo.">
        <DCArtboard id="ob-a" label="A · Voice-first orb" width={W} height={H}><Onboard_A /></DCArtboard>
        <DCArtboard id="ob-b" label="B · Step form, ± controls" width={W} height={H}><Onboard_B /></DCArtboard>
        <DCArtboard id="ob-c" label="C · Conversation log (dark)" width={W} height={H}><Onboard_C /></DCArtboard>
      </DCSection>

      <DCSection id="home" title="3 · Home — start a run" subtitle="Two clear CTAs: coached vs solo.">
        <DCArtboard id="home-a" label="A · Twin hero buttons" width={W} height={H}><Home_A /></DCArtboard>
        <DCArtboard id="home-b" label="B · Big record CTA" width={W} height={H}><Home_B /></DCArtboard>
        <DCArtboard id="home-c" label="C · Dark + last-run peek" width={W} height={H}><Home_C /></DCArtboard>
      </DCSection>

      <DCSection id="history" title="4 · Session history" subtitle="Latest two runs, tappable for full breakdown.">
        <DCArtboard id="hist-a" label="A · Elevated cards" width={W} height={H}><History_A /></DCArtboard>
        <DCArtboard id="hist-b" label="B · Inset grouped list" width={W} height={H}><History_B /></DCArtboard>
        <DCArtboard id="hist-c" label="C · Dark color blocks" width={W} height={H}><History_C /></DCArtboard>
      </DCSection>

      <DCSection id="metrics" title="5 · Metric detail" subtitle="Every metric from the spec — minimal, scannable.">
        <DCArtboard id="m-a" label="A · 2-up tile grid" width={W} height={H}><Metrics_A /></DCArtboard>
        <DCArtboard id="m-b" label="B · Grouped by theme" width={W} height={H}><Metrics_B /></DCArtboard>
        <DCArtboard id="m-c" label="C · Story scroll (dark)" width={W} height={H}><Metrics_C /></DCArtboard>
      </DCSection>

      <DCSection id="settings" title="6 · Settings" subtitle="Profile · Coaching · Support.">
        <DCArtboard id="set-a" label="A · Profile + grouped lists" width={W} height={H}><Settings_A /></DCArtboard>
        <DCArtboard id="set-b" label="B · 2×2 card grid" width={W} height={H}><Settings_B /></DCArtboard>
        <DCArtboard id="set-c" label="C · Dark inset rows" width={W} height={H}><Settings_C /></DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
