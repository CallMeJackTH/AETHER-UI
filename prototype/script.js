(() => {
"use strict";
const $=(s,root=document)=>root.querySelector(s), $$=(s,root=document)=>[...root.querySelectorAll(s)];
const state={page:"dashboard",theme:"Dark",configs:{Default:{accent:"#A8B5FF",enabled:true,volume:65}},activeConfig:"Default",accent:"#A8B5FF"};
const pages={
 dashboard:["OVERVIEW","Dashboard","A clear view of your interface system."],
 components:["LIBRARY","Components","Interactive controls and feedback patterns."],
 settings:["PREFERENCES","Settings","Tune the appearance and behavior of AETHER UI."],
 configurations:["PERSISTENCE","Configurations","Save and switch local prototype configurations."],
 showcase:["GALLERY","Showcase","A compact view of the complete component set."],
 notifications:["FEEDBACK","Notifications","Toast messages and status feedback."],
 modals:["OVERLAYS","Modals","Dialogs, modal surfaces and contextual actions."]
};
function card(title,desc,body,extra=""){return `<article class="card ${extra}"><h2>${title}</h2>${desc?`<p>${desc}</p>`:""}${body||""}</article>`}
function field(label,control,hint=""){return `<div class="field"><label>${label}</label>${control}${hint?`<small>${hint}</small>`:""}</div>`}
function toggle(label,checked=false){return `<div class="row"><div><strong>${label}</strong></div><button class="switch ${checked?"on":""}" data-toggle aria-label="${label}"></button></div>`}
function btn(label,action,primary=false){return `<button class="btn ${primary?"primary":""}" data-action="${action}">${label}</button>`}
function dashboard(){return `<div class="grid three">${card("Components","Reusable interactive elements.",'<div class="stat">20</div><span class="chip">AVAILABLE</span>')}${card("Themes","Adaptive color systems.",'<div class="stat">03</div><span class="muted">Dark · Midnight · Light</span>')}${card("Configurations","Local saved profiles.",`<div class="stat">${Object.keys(state.configs).length}</div><span class="muted">Saved in this session</span>`)}</div><div class="grid">${card("Quick controls","Try live state updates.",toggle("Enable interface",true)+toggle("Compact layout",false)+toggle("Acrylic material",true))}${card("System status","Prototype runtime health.",'<div class="row"><strong>HTML runtime</strong><span class="chip">READY</span></div><div class="row"><strong>Theme engine</strong><span class="chip">ACTIVE</span></div><div class="row"><strong>Storage</strong><span class="pill">Session memory</span></div>')}</div><div class="card"><h2>Welcome to AETHER UI</h2><p>This standalone prototype mirrors the Roblox library’s dark acrylic design language. Use the sidebar to explore controls, themes, configurations, notifications and dialogs.</p>${btn("Show welcome notification","toast",true)}</div>`}
function components(){return `<div class="component-grid">
${card("Button","Primary action with callback feedback.",`<button class="btn primary" data-action="buttonDemo">Run action</button>`)}
${card("Toggle","Boolean state with immediate feedback.",toggle("Enable feature",true))}
${card("Slider","Continuous numeric value.",field("Intensity · <b id='sliderVal'>65</b>",'<input class="control" id="demoSlider" type="range" min="0" max="100" value="65">'))}
${card("Dropdown","Single selection.",field("Quality",'<select class="control" id="quality"><option>Performance</option><option>Balanced</option><option>Quality</option></select>'))}
${card("MultiDropdown","Select multiple values.",field("Modules",'<select class="control" id="multi" multiple size="3"><option selected>Core</option><option>Visuals</option><option>Audio</option><option>Input</option></select>'))}
${card("Textbox","Text input with validation.",field("Display name",'<input class="control" id="displayName" placeholder="Enter a name" maxlength="24">'))}
${card("Keybind","Capture a keyboard shortcut.",`<button class="btn" data-action="keybind" id="keybind">Right Shift</button><small class="muted">Click, then press any key.</small>`)}
${card("ColorPicker","Change the active accent.",field("Accent color",'<input class="control" type="color" id="accentPicker" value="'+state.accent+'">'))}
${card("Label","Simple text element.",'<span class="pill">System ready</span>')}
${card("Paragraph","Title and supporting description.",'<h3>Helpful context</h3><p>Keep related information close to the control it describes.</p>')}
${card("Divider","A subtle visual separator.",'<div class="divider"></div><span class="muted">Content below divider</span>')}
${card("SearchBar","Filter component cards live.",'<input class="control" id="componentSearch" placeholder="Search components…">')}
${card("ProgressBar","Animated percentage state.",'<div class="progress"><span id="demoProgress"></span></div><div class="row"><small>Upload progress</small><button class="btn" data-action="progress">Advance</button></div>')}
${card("LoadingIndicator","Indeterminate activity indicator.",'<span class="spinner"></span> <span class="muted">Working…</span>')}
${card("Tooltip","Hover for contextual information.",'<span class="pill" title="Tooltips explain a control without adding permanent visual noise.">Hover me</span>')}
${card("ContextMenu","Right-click the action surface.",'<button class="btn" id="contextTarget">Right-click here</button>')}
${card("Notification","Transient status message.",btn("Send notification","toast"))}
${card("Dialog / Modal","Confirm an action.",btn("Open dialog","modal",true))}
${card("Configuration Manager","Save and restore settings.",btn("Save current state","save"))}
${card("Theme Manager","Switch the entire color palette.",btn("Cycle theme","theme"))}
</div>`}
function settings(){return `<div class="grid">${card("Appearance","Theme and accent customization.",field("Theme",'<select class="control" id="themeSelect"><option>Dark</option><option>Midnight</option><option>Light</option></select>')+field("Custom accent",`<input class="control" id="settingsAccent" type="color" value="${state.accent}">`)+btn("Apply appearance","applyTheme",true))}${card("Behavior","Interface preferences.",toggle("Acrylic surfaces",true)+toggle("Reduce motion",false)+toggle("Show status footer",true))}</div>`}
function configurations(){return `<div class="grid">${card("Save configuration","Store current prototype preferences.",field("Configuration name",'<input class="control" id="configName" value="My Profile" placeholder="Name">')+btn("Save configuration","save",true))}${card("Saved configurations","Select a profile to restore.",`<div class="field"><label>Active profile</label><select class="control" id="configSelect">${Object.keys(state.configs).map(n=>`<option ${n===state.activeConfig?"selected":""}>${n}</option>`).join("")}</select></div>${btn("Load selected","load")}`)}</div>`}
function showcase(){return `<div class="grid">${card("Surface system","Three elevation levels.",'<div class="tag-list"><span class="tag">Background</span><span class="tag">Surface</span><span class="tag">Elevated</span><span class="tag">Border</span></div>')}${card("Typography","Clear hierarchy and readable labels.",'<h2 style="font-size:20px">Heading 20</h2><p>Body copy · 12px · muted</p><code class="pill">JetBrains Mono · tokens</code>')}${card("Feedback states","Success, warning and neutral.",'<span class="chip">SUCCESS</span> <span class="pill">NEUTRAL</span> <span class="tag">WARNING</span>')}${card("Spacing & geometry","Consistent component rhythm.",'<div class="tag-list"><span class="tag">4px grid</span><span class="tag">8px radius</span><span class="tag">12px window</span><span class="tag">6px gaps</span></div>')}</div>`}
function notifications(){return `<div class="grid">${card("Notification center","Toast messages automatically dismiss.",btn("Success notification","success",true)+` `+btn("Info notification","toast")+` `+btn("Warning notification","warning"))}${card("Feedback preview","A toast appears in the top-right corner.",'<p>Notifications are non-blocking and stack when multiple events occur.</p>')}</div>`}
function modals(){return `<div class="grid">${card("Confirmation dialog","A focused decision surface.",btn("Open confirmation","modal",true))}${card("Context menu","Right-click the surface below.",'<div class="pill" id="contextArea">Right-click / long-press this area</div>')}</div>`}
const renderers={dashboard,components,settings,configurations,showcase,notifications,modals};
function render(){const p=pages[state.page];$("#eyebrow").textContent=p[0];$("#pageTitle").textContent=p[1];$("#pageDesc").textContent=p[2];$("#pageContent").innerHTML=renderers[state.page]();$$(".nav").forEach(n=>n.classList.toggle("active",n.dataset.page===state.page));}
function toast(title,msg="Your action was completed.",kind="info"){const el=document.createElement("div");el.className="toast";el.innerHTML=`<b>${title}</b><span>${msg}</span>`;$("#toastStack").append(el);setTimeout(()=>el.remove(),3200)}
function openModal(title="Confirm action",message="Would you like to continue?",callback=()=>toast("Confirmed")){$("#modalTitle").textContent=title;$("#modalText").textContent=message;$("#modalLayer").classList.remove("hidden");$("#modalConfirm").onclick=()=>{$("#modalLayer").classList.add("hidden");callback()};}
function applyTheme(name=state.theme){state.theme=name;const themes={Dark:["#090A0D","#101216","#15181E","#252A33","#F1F3F7","#929BAB"],Midnight:["#070914","#0D1222","#151D34","#2B3655","#EDF1FF","#9AA9CF"],Light:["#EEF1F7","#FAFBFD","#E7EBF3","#D3D9E4","#1C202A","#687184"]};const t=themes[name];["--bg","--surface","--elev","--border","--text","--muted"].forEach((k,i)=>document.documentElement.style.setProperty(k,t[i]));document.documentElement.style.setProperty("--accent",state.accent);document.documentElement.style.setProperty("--accent-soft",state.accent+"22");}
function save(){const name=$("#configName")?.value.trim()||"Default";state.configs[name]={theme:state.theme,accent:state.accent};state.activeConfig=name;toast("Configuration saved",name);if(state.page==="configurations")render()}
function act(action){switch(action){case"toast":toast("AETHER notification","This is a live prototype notification.");break;case"success":toast("Success","Your settings were saved.","success");break;case"warning":toast("Heads up","Review this setting before continuing.","warning");break;case"modal":openModal("Apply changes?","This action will update the active interface.",()=>toast("Changes applied"));break;case"buttonDemo":toast("Button clicked","Callback feedback executed.");break;case"theme":applyTheme(({Dark:"Midnight",Midnight:"Light",Light:"Dark"})[state.theme]);toast("Theme changed",state.theme);break;case"applyTheme":applyTheme($("#themeSelect").value);state.accent=$("#settingsAccent").value;applyTheme();toast("Appearance updated",state.theme);break;case"save":save();break;case"load":{const c=state.configs[$("#configSelect").value];if(c){state.activeConfig=$("#configSelect").value;state.accent=c.accent||state.accent;applyTheme(c.theme||state.theme);toast("Configuration loaded",state.activeConfig)}break}case"progress":{const el=$("#demoProgress");if(el)el.style.width=Math.min(100,(parseInt(el.style.width)||62)+10)+"%";break}}}
$("#navigation").addEventListener("click",e=>{const n=e.target.closest("[data-page]");if(n){state.page=n.dataset.page;render()}});
$("#pageContent").addEventListener("click",e=>{const a=e.target.closest("[data-action]");if(a)act(a.dataset.action);const sw=e.target.closest("[data-toggle]");if(sw)sw.classList.toggle("on")});
$("#pageContent").addEventListener("input",e=>{if(e.target.id==="demoSlider")$("#sliderVal").textContent=e.target.value;if(e.target.id==="accentPicker"){state.accent=e.target.value;applyTheme()}if(e.target.id==="componentSearch"){$$(".component-card").forEach(c=>c.style.display=c.textContent.toLowerCase().includes(e.target.value.toLowerCase())?"":"none") }});
$("#pageContent").addEventListener("change",e=>{if(e.target.id==="quality")toast("Quality changed",e.target.value);if(e.target.id==="multi")toast("Modules selected",[...e.target.selectedOptions].map(o=>o.value).join(", "));if(e.target.id==="configSelect")state.activeConfig=e.target.value});
$("#pageContent").addEventListener("contextmenu",e=>{if(e.target.id==="contextTarget"||e.target.id==="contextArea"){e.preventDefault();toast("Context menu","Inspect · Duplicate · Reset") }});
let keybindCapture=false;
$("#pageContent").addEventListener("click",e=>{if(e.target.id==="keybind"){keybindCapture=true;e.target.textContent="Press a key…";}});
document.addEventListener("keydown",e=>{if(keybindCapture){e.preventDefault();keybindCapture=false;const b=$("#keybind");if(b)b.textContent=e.key===" "?"Space":e.key;toast("Keybind updated",e.key);}});
let pressTimer=null;
$("#pageContent").addEventListener("touchstart",e=>{if(e.target.id==="contextArea"||e.target.id==="contextTarget"){pressTimer=setTimeout(()=>toast("Context menu","Inspect · Duplicate · Reset"),550)}},{passive:true});
$("#pageContent").addEventListener("touchend",()=>{if(pressTimer)clearTimeout(pressTimer);});

$("#sidebarToggle").addEventListener("click",()=>$("#sidebar").classList.toggle("collapsed"));
$("#globalSearch").addEventListener("input",e=>{const q=e.target.value.toLowerCase();if(q){state.page="components";render();$("#componentSearch")?.focus();if($("#componentSearch")){$("#componentSearch").value=q;$("#componentSearch").dispatchEvent(new Event("input",{bubbles:true}))}}});
$("#modalX").onclick=$("#modalCancel").onclick=()=>$("#modalLayer").classList.add("hidden");
document.addEventListener("keydown",e=>{if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==="k"){e.preventDefault();$("#globalSearch").focus()}if(e.key==="Escape")$("#modalLayer").classList.add("hidden")});
render();applyTheme();
})();