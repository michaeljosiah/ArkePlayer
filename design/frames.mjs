// Arke Player · the frames, turn by turn. The sample is The Undersong, shared by Helen Marsh with
// Jonah Pike, beside Copper Saints (shared by Ama Mensah) and Meridian Dust (added from a file).
// Every picture is in design/assets, recompressed from ArkeStudio's design-system/assets; nothing here is generated.
import { A, ic, seek, sb, hi, tabs, pill, dock, frame, cc, tile, wc, sh, row, sheet, gb } from './view.mjs';

// ---- the sample ------------------------------------------------------------------------------
const W = {
  undersong: { img: 'world-undersong.jpg', name: 'The Undersong', by: 'Helen Marsh', count: '6 productions', logline: 'A drowned god still sings beneath the harbour of Saltmouth.' },
  copper: { img: 'world-copper-saints.jpg', name: 'Copper Saints', by: 'Ama Mensah', count: '2 productions' },
  meridian: { img: 'world-meridian-dust.jpg', name: 'Meridian Dust', count: '3 productions', size: '1.4 GB' },
};
const PR = {
  saltlight: { img: 'saltlight-shot15.jpg', pos: '38% 50%', title: 'Saltlight', kind: 'Film · 1 h 32 m' },
  bell: { img: 'char-sereth.jpg', pos: '50% 28%', title: 'The Bell Watch', kind: 'Micro drama · 40 episodes' },
  low: { img: 'drowned-quarter.jpg', pos: '30% 50%', title: 'Low Water', kind: 'Interactive movie · 14 scenes' },
  lantern: { img: 'art-direction-illustrated.jpg', pos: '34% 40%', title: 'The Lantern Road', kind: 'Visual novel · 9 scenes' },
  tenth: { img: 'banner-story.jpg', pos: '50% 40%', title: 'The Tenth Key', kind: 'Audiobook · Book · 9 h 40 m' },
  undertow: { img: 'banner-audio.jpg', pos: '50% 50%', title: 'Undertow', kind: 'Audio drama · 8 episodes' },
};
// What Add a file takes (P2c, P7): one data line, never a sentence.
const FORMATS = 'Arke package · EPUB · PDF · CBZ · M4B · M4A · MP3 · MP4 · MOV';
const back = gb('left', 22);
const more = gb('more', 20);
const close = '<span class="ib">' + ic('down', 26, 2) + '</span>';
const media = (cls = '') => `phone media${cls ? ' ' + cls : ''}`;

// ---- P1 · the shape -------------------------------------------------------------------------
const P1 = [
  frame('P1a', 'First open', media(), `<img class="pic" src="${A}world-undersong.jpg" alt="" style="height:66%;object-position:56% 50%"><div class="sbot" style="height:600px"></div>${sb(true)}
<div style="position:absolute;left:0;right:0;top:432px;text-align:center"><div class="wm">Arke</div><div class="wm2">Player</div></div>
<div style="position:absolute;left:20px;right:20px;bottom:54px;display:flex;flex-direction:column;gap:10px"><span class="btn pri wide">Sign in with Arke ${ic('out', 16, 2)}</span><span class="btn wide">${ic('plus', 18, 2)}Add a file</span></div>${hi()}`),

  frame('P1b', 'Home', 'phone', `${sb()}<div class="hd"><h1>Home</h1><span class="av">JP</span></div><div class="body">
${sh('Continue')}<div class="hrow">${cc({ img: PR.tenth.img, pos: '50% 40%', kind: 'Audiobook', title: 'The Tenth Key', where: 'Chapter 7 · 19 min left', at: 55 })}${cc({ img: PR.saltlight.img, pos: PR.saltlight.pos, kind: 'Film', title: 'Saltlight', where: '38 min left', at: 59 })}</div>
${sh('New')}<div class="hrow">${tile({ ...PR.bell, kind: 'Micro drama · The Undersong' })}${tile({ ...PR.undertow, kind: 'Audio drama · The Undersong' })}${tile({ img: 'world-copper-saints.jpg', pos: '70% 50%', title: 'Foundry Hymns', kind: 'Audiobook · Copper Saints' })}</div>
${sh('Worlds')}<div class="hrow">${wc({ ...W.undersong, meta: 'Helen Marsh', cls: 'mini', pos: '60% 50%' })}${wc({ ...W.copper, meta: 'Ama Mensah', cls: 'mini' })}</div>
</div>${tabs('Home')}${hi()}`),

  frame('P1c', 'Library', 'phone', `${sb()}<div class="hd"><h1>Library</h1><span class="icb">${ic('plus', 20, 2)}</span></div><div class="chips"><span class="chip on">All</span><span class="chip">Shared</span><span class="chip">Added</span></div><div class="body" style="padding-top:16px">
${wc({ ...W.undersong, meta: 'Helen Marsh · 6 productions', pos: '60% 50%' })}${wc({ ...W.copper, meta: 'Ama Mensah · 2 productions' })}${wc({ ...W.meridian, meta: 'Added · 3 productions · 1.4 GB', pos: '40% 50%' })}
</div>${tabs('Library')}${hi()}`),

  frame('P1d', 'A world', 'phone', `${sb(true)}<div class="body"><div class="hero" style="padding-top:226px"><img src="${A}world-undersong.jpg" alt="" style="height:300px;object-position:60% 50%"><div class="fade" style="top:100px;height:201px"></div><div class="top">${back}${more}</div><div class="in"><h1>The Undersong</h1><div class="meta">Helen Marsh · 6 productions</div><div class="lg">${W.undersong.logline}</div></div></div>
${sh('Watch')}<div class="hrow">${tile({ ...PR.saltlight, at: 59 })}${tile({ ...PR.bell, kind: 'Micro drama · 40 episodes', at: 30 })}</div>
${sh('Play')}<div class="hrow">${tile(PR.low)}${tile(PR.lantern)}</div>
</div>${dock({ img: 'scene4-shot15.jpg', title: 'The Tenth Key', where: 'Chapter 7 · 12:04', at: 38 })}${tabs('Library')}${hi()}`),

  frame('P1e', 'A production · audiobook and book', 'phone', `${sb(true)}<div class="body"><div class="hero" style="padding-top:218px"><img src="${A}banner-story.jpg" alt="" style="height:290px;object-position:50% 40%"><div class="fade" style="top:90px;height:201px"></div><div class="top">${back}${more}</div><div class="in"><h1>The Tenth Key</h1><div class="meta">Audiobook · Book · 9 h 40 m · Read by Odile’s voice</div>
<div style="margin-top:16px"><span class="btn pri wide">${ic('play', 16)}Continue <em>· Chapter 7 · 12:04</em></span></div><div class="acts"><span class="btn" style="flex:1">${ic('book', 18)}Read</span><span class="btn" style="flex:1">${ic('download', 18)}412 MB</span><span class="btn" style="width:44px;padding:0">${ic('more')}</span></div></div></div>
${sh('Chapters')}
${[['scene4-shot12.jpg', '6 · The Weir', '41 min', 100, true], ['scene4-shot15.jpg', '7 · The Tenth Key', '32 min', 38, true], ['scene4-shot14b.jpg', '8 · Saltmouth Bells', '38 min', 0, true], ['scene4-shot13.jpg', '9 · A Choir Underwater', '44 min', 0, false]].map(([img, t, d, at, dl]) => `<div class="ep"><div class="th"><img src="${A}${img}" alt="">${at ? `<div class="pl"><i style="width:${at}%"></i></div>` : ''}</div><div class="grow"><div class="t">${t}</div><div class="m"><span>${d}</span>${dl ? ic('downloaded', 14) : ''}</div></div></div>`).join('')}
</div>${tabs('Library')}${hi()}`),

  frame('P1f', 'A production · micro drama', 'phone', `${sb(true)}<div class="body"><div class="hero" style="padding-top:218px"><img src="${A}char-sereth.jpg" alt="" style="height:290px;object-position:50% 26%"><div class="fade" style="top:90px;height:201px"></div><div class="top">${back}${more}</div><div class="in"><h1>The Bell Watch</h1><div class="meta">Micro drama · 40 episodes · 1 h 52 m</div>
<div style="margin-top:16px"><span class="btn pri wide">${ic('play', 16)}Continue <em>· Episode 13</em></span></div><div class="acts"><span class="btn" style="flex:1">${ic('download', 18)}640 MB</span><span class="btn" style="width:44px;padding:0">${ic('more')}</span></div></div></div>
${sh('Episodes')}<div class="grid4">${['char-maren.jpg', 'scene4-shot12.jpg', 'scene4-shot14b.jpg', 'char-ilo.jpg', 'scene4-shot15.jpg', 'char-bray.jpg', 'scene4-shot13.jpg', 'char-chorister.jpg'].map((img, i) => `<div class="vt"><img src="${A}${img}" alt="" style="object-position:50% 30%"><span class="n">${i + 1}</span><div class="pl"><i style="width:100%"></i></div></div>`).join('')}</div>
</div>${tabs('Library')}${hi()}`),
];

// ---- P2 · getting worlds in ------------------------------------------------------------------
const firstOpenBehind = `<img class="pic" src="${A}world-undersong.jpg" alt="" style="height:66%;object-position:56% 50%"><div class="sbot" style="height:600px"></div>${sb(true)}<div style="position:absolute;left:0;right:0;top:432px;text-align:center"><div class="wm">Arke</div><div class="wm2">Player</div></div>`;
const shareCard = `<div style="padding:2px 16px 0"><div class="on-media" style="position:relative;height:196px;border-radius:14px;overflow:hidden;background:var(--media-overlay-bg)"><img src="${A}world-undersong.jpg" alt="" style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:60% 50%"><div class="shade"></div><div style="position:absolute;left:14px;bottom:12px"><div class="k">World</div><div style="margin-top:3px;font:var(--weight-semibold) var(--text-xl)/1.2 var(--font-sans);letter-spacing:var(--tracking-tight)">The Undersong</div></div></div>
<div style="display:flex;align-items:center;gap:12px;margin-top:14px"><span class="av" style="width:40px;height:40px"><img src="${A}char-odile.jpg" alt="" style="object-position:50% 20%"></span><div class="grow"><div style="font:var(--type-ui);font-size:var(--text-base)">Helen Marsh</div><div class="mute" style="font:var(--type-meta)">6 productions</div></div></div></div>`;
const libraryBehind = (extra = '') => `${sb()}<div class="hd"><h1>Library</h1><span class="icb">${ic('plus', 20, 2)}</span></div><div class="chips"><span class="chip on">All</span><span class="chip">Shared</span><span class="chip">Added</span></div><div class="body" style="padding-top:16px">${wc({ ...W.undersong, meta: 'Helen Marsh · 6 productions', pos: '60% 50%' })}${wc({ ...W.copper, meta: 'Ama Mensah · 2 productions' })}${extra}</div>${tabs('Library')}`;
const meridianThumb = (pos) => `<div class="th" style="width:96px;height:54px"><img class="crop" src="${A}world-meridian-dust.jpg" alt="" style="transform-origin:${pos}"></div>`;

const P2 = [
  frame('P2a', 'A share link, signed out', media(), `${firstOpenBehind}<div class="veil"></div>${sheet('Shared with you', `${shareCard}<div style="display:flex;flex-direction:column;gap:8px;padding:20px 16px 0"><span class="btn pri wide">Sign in with Arke ${ic('out', 16, 2)}</span><span class="btn ghost wide">Not now</span></div>`)}<div class="hi" style="color:var(--foreground)"></div>`),

  frame('P2b', 'Waiting for the browser', media(), `${firstOpenBehind}<div class="veil"></div>${sheet('Shared with you', `${shareCard}<div style="display:flex;flex-direction:column;gap:8px;padding:20px 16px 0"><span class="btn wide" style="gap:10px"><span class="spin"></span>waiting for the browser</span><span class="btn ghost wide">Cancel</span></div>`)}<div class="hi" style="color:var(--foreground)"></div>`),

  frame('P2c', 'Add a file', 'phone', `${libraryBehind()}<div class="veil"></div>${sheet('Add', `<div class="opt">${ic('folder', 22)}<span class="l">Choose files</span><span class="mute">${ic('right', 18)}</span></div><div class="opt">${ic('link', 22)}<span class="l">Paste a link</span><span class="mute">${ic('right', 18)}</span></div><div class="mute" style="padding:10px 16px 0;font:var(--type-meta)">${FORMATS}</div>`)}${hi()}`),

  frame('P2d', 'Checking a package', 'phone', `${libraryBehind()}<div class="veil"></div>${sheet('Checking', `<div style="display:flex;align-items:center;gap:14px;padding:6px 16px 0"><span class="icb" style="width:52px;height:52px;border-radius:14px">${ic('package', 26)}</span><div class="grow"><div style="font:var(--type-ui);font-size:var(--text-base)">meridian-dust.arke</div><div class="mute num" style="font:var(--type-meta)">1.4 GB</div></div></div><div style="padding:18px 16px 0"><div class="bar"><i style="width:51%"></i></div><div class="mute num" style="margin-top:8px;font:var(--type-meta)">212 of 418 files</div></div><div style="padding:18px 16px 0"><span class="btn wide">Cancel</span></div>`, { close: false })}${hi()}`),

  frame('P2e', 'A package, ready', 'phone', `${sb()}<div class="hd"><span class="icb">${ic('x', 18, 2)}</span><span class="grow"></span></div><div class="body">
<div class="on-media" style="position:relative;margin:4px 16px 0;height:200px;border-radius:16px;overflow:hidden;background:var(--media-overlay-bg)"><img src="${A}world-meridian-dust.jpg" alt="" style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:40% 50%"><div class="shade"></div><div style="position:absolute;left:16px;bottom:14px"><div class="k">Package</div><div style="margin-top:3px;font:var(--weight-semibold) var(--text-2xl)/1.15 var(--font-sans);letter-spacing:var(--tracking-tighter)">Meridian Dust</div></div></div>
<div class="mute num" style="padding:10px 16px 0;font:var(--type-ui)">made 12 Oct 2026 · 3 productions · 1.4 GB</div>
${sh('Inside')}${[['12% 22%', 'Dust Line', 'Interactive movie · 820 MB'], ['72% 62%', 'The Long Haul', 'Audiobook · 380 MB'], ['92% 70%', 'Rail Song', 'Film · 210 MB']].map(([p, t, m]) => `<div class="ep">${meridianThumb(p)}<div class="grow"><div class="t">${t}</div><div class="m"><span>${m}</span></div></div></div>`).join('')}
<div style="height:14px"></div><div class="grp">${row('Space', '1.4 GB of 38 GB free', '')}</div>
</div><div style="flex:none;padding:12px 16px 34px"><span class="btn pri wide">Add to library</span></div>${hi()}`),

  frame('P2f', 'A package, refused', 'phone', `${libraryBehind()}<div class="veil"></div>${sheet('', `<div style="display:flex;flex-direction:column;align-items:center;text-align:center;gap:8px;padding:14px 20px 0"><span class="warn">${ic('alert', 34, 1.8)}</span><div style="margin-top:4px;font:var(--type-h3)">3 files do not match</div><div class="mute num" style="font:var(--type-ui)">meridian-dust.arke · 1.4 GB</div></div><div style="display:flex;flex-direction:column;gap:8px;padding:20px 16px 0"><span class="btn pri wide">Choose another file</span><span class="btn ghost wide">Close</span></div>`)}${hi()}`),

  frame('P2g', 'A share that ended', 'phone', `${sb()}<div class="hd"><h1>Library</h1><span class="icb">${ic('plus', 20, 2)}</span></div><div class="chips"><span class="chip on">All</span><span class="chip">Shared</span><span class="chip">Added</span></div><div class="body" style="padding-top:16px">
${wc({ ...W.undersong, meta: 'Helen Marsh · 6 productions', pos: '60% 50%' })}<div class="wc ended" style="height:190px"><img src="${A}world-copper-saints.jpg" alt=""><div class="shade"></div><div class="tg"><span class="tag glass">No longer shared</span></div><div class="tx" style="right:110px"><h3>Copper Saints</h3><div class="m">Ama Mensah</div></div><span class="btn" style="position:absolute;right:12px;bottom:12px;height:40px">Remove</span></div>${wc({ ...W.meridian, meta: 'Added · 3 productions · 1.4 GB', pos: '40% 50%' })}
</div>${tabs('Library')}${hi()}`),
];

// ---- P3 · watching -------------------------------------------------------------------------
const filmPortrait = (withCaption = true) => `<img src="${A}saltlight-shot15.jpg" alt="" style="position:absolute;left:0;top:318px;width:390px;height:167px;object-fit:cover"><div class="st"></div><div class="sbot" style="height:300px"></div>${sb(true)}
<div class="ptop">${close}<div class="ttl"><div class="eb">The Undersong</div><div class="sc">Saltlight</div></div><span class="ib">${ic('cast', 20)}</span></div>
${withCaption ? '<div class="cap" style="top:500px">The tide is lower than it has ever been.</div>' : ''}
<div style="position:absolute;z-index:4;left:20px;right:20px;bottom:44px"><div class="scrub"><u style="width:68%"></u><i style="width:59%"></i><b style="left:59%"></b></div><div class="times"><span>54:40</span><span>1:32:40</span></div>
<div class="trow" style="margin-top:14px"><span class="ib on">${ic('captions', 20)}</span><span class="ib">${seek(10, true, 24)}</span><span class="play">${ic('pause', 24)}</span><span class="ib">${seek(10, false, 24)}</span><span class="ib">${ic('full', 20)}</span></div></div>${hi()}`;
const feed = `<img class="pic" src="${A}char-sereth.jpg" alt="" style="object-position:50% 30%"><div class="st"></div><div class="sbot" style="height:360px"></div>${sb(true)}
<div class="ptop">${close}<div class="ttl"><div class="eb">The Bell Watch</div><div class="sc">Episode 13</div></div></div>`;

const P3 = [
  frame('P3a', 'A film, held upright', media(), filmPortrait()),

  frame('P3b', 'A film, turned', 'turned media', `<img class="pic fit" src="${A}saltlight-shot15.jpg" alt=""><div class="st" style="height:140px"></div><div class="sbot" style="height:170px"></div>
<div class="ptop" style="top:14px;left:40px;right:40px">${close}<div class="ttl"><div class="eb">The Undersong</div><div class="sc">Saltlight</div></div><span class="ib">${ic('cast', 20)}</span><span class="ib on">${ic('captions', 20)}</span></div>
<div class="cap" style="bottom:104px;max-width:600px">The tide is lower than it has ever been.</div>
<div style="position:absolute;z-index:4;left:48px;right:48px;bottom:16px"><div class="scrub"><u style="width:68%"></u><i style="width:59%"></i><b style="left:59%"></b></div><div class="trow" style="margin-top:10px"><span style="display:flex;align-items:center;gap:6px"><span class="ib">${ic('pause', 22)}</span><span class="ib">${seek(10, true, 22)}</span><span class="ib">${seek(10, false, 22)}</span><span class="num" style="margin-left:8px;font:var(--type-ui);color:color-mix(in srgb,var(--media-overlay-fg) 82%,transparent)">54:40 / 1:32:40</span></span><span class="ib">${ic('unfull', 20)}</span></div></div>`),

  frame('P3c', 'A micro drama, playing', media(), `${feed}
<div class="cap" style="top:470px">Ring it once. Only once.</div>
<div style="position:absolute;z-index:5;right:8px;bottom:132px;display:flex;flex-direction:column;gap:14px"><span class="ib col"><i style="background:color-mix(in srgb,var(--media-overlay-bg) 42%,transparent)">${ic('grid', 20)}</i>Episodes</span><span class="ib col"><i style="background:color-mix(in srgb,var(--media-overlay-fg) 18%,transparent)">${ic('captions', 20)}</i>Captions</span><span class="ib col"><i style="background:color-mix(in srgb,var(--media-overlay-bg) 42%,transparent)">${ic('more', 20)}</i>More</span></div>
<div style="position:absolute;z-index:4;left:16px;right:84px;bottom:66px"><div style="font:var(--type-h3);letter-spacing:var(--tracking-tight)">13 · The lamp in the tower</div><div class="mute" style="margin-top:2px;font:var(--type-ui)">1:58 · 2:46</div></div>
<div style="position:absolute;z-index:4;left:16px;right:16px;bottom:42px"><div class="scrub" style="height:3px"><i style="width:71%"></i></div></div>${hi()}`),

  frame('P3d', 'Episodes', media(), `${feed}<div class="veil" style="background:color-mix(in srgb,var(--media-overlay-bg) 30%,transparent)"></div>${sheet('Episodes', `<div class="seg"><span class="on">1–20</span><span>21–40</span></div><div class="nts">${Array.from({ length: 20 }, (_, i) => `<span class="nt${i + 1 < 13 ? ' seen' : i + 1 === 13 ? ' now' : ''}">${i + 1}</span>`).join('')}</div>`, { glass: true, count: '40' })}${hi()}`),

  frame('P3e', 'Captions', media(), `${filmPortrait(false)}<div class="veil" style="background:color-mix(in srgb,var(--media-overlay-bg) 30%,transparent)"></div>${sheet('Captions', `${['Off', 'English', 'Español', 'Français'].map((l) => `<div class="opt"><span class="l">${l}</span>${l === 'English' ? ic('check', 20, 2.2) : ''}</div>`).join('')}<div class="sht" style="padding-top:14px"><h3 style="font:var(--type-ui);font-size:var(--text-base);opacity:.7">Size</h3></div><div class="seg"><span>S</span><span class="on">M</span><span>L</span></div>`, { glass: true })}${hi()}`),
];

// ---- P4 · playing ---------------------------------------------------------------------------
const lowWater = `<img class="pic" src="${A}drowned-quarter.jpg" alt="" style="object-position:30% 50%"><div class="dim"></div><div class="st"></div>${sb(true)}
<div class="ptop">${close}<div class="ttl"><div class="eb">Low Water</div><div class="sc">The drowned quarter</div></div><span class="ib glass">${ic('captions', 18)}</span><span class="ib glass" style="margin-left:6px">${ic('route', 18)}</span></div>`;
const lantern = `<img class="pic" src="${A}art-direction-illustrated.jpg" alt="" style="object-position:34% 40%"><div class="st" style="height:220px"></div>${sb(true)}
<div class="ptop">${close}<div class="ttl"><div class="eb">The Lantern Road</div><div class="sc">The lamp market</div></div><span class="ib">${ic('more', 20)}</span></div><div style="position:absolute;z-index:5;left:14px;top:104px;display:flex;gap:6px"><span class="ib lab on" style="height:40px">${ic('auto', 16)}Auto</span><span class="ib lab" style="height:40px">${ic('list', 16)}Log</span></div>`;
const still = (img, pos = 'center', ring = false, w = 96, h = 54) => `<span class="still${ring ? ' ring' : ''}" style="width:${w}px;height:${h}px"><img src="${A}${img}" alt="" style="object-position:${pos}"></span>`;

const P4 = [
  frame('P4a', 'An interactive movie · the choice', media(), `${lowWater}<div class="sbot" style="height:430px"></div>
<div style="position:absolute;z-index:4;left:16px;right:16px;bottom:96px;display:flex;flex-direction:column;gap:12px"><div class="choice focus"><span class="kn">1</span><span>Follow the lantern</span></div><div class="choice"><span class="kn">2</span><span>Stay with the boat</span></div></div>
<div style="position:absolute;z-index:4;left:0;right:0;bottom:36px;display:flex;justify-content:center"><span class="btn ghost" style="height:40px;color:color-mix(in srgb,var(--media-overlay-fg) 82%,transparent)">${ic('replay', 16)}Replay scene</span></div>${hi()}`),

  frame('P4b', 'An interactive movie · the route', media(), `${lowWater}<div class="veil" style="background:color-mix(in srgb,var(--media-overlay-bg) 30%,transparent)"></div>${sheet('Route', `<div class="rt">${still('launch-harbour.jpg', '50% 60%')}<div class="grow"><div class="t">The harbour at dusk</div><div class="d num">1:12</div></div></div>
<div class="rc">${ic('right', 14, 2)}<span class="grow">Take the skiff</span><span class="btn">Choose again</span></div>
<div class="rt">${still('scene4-shot15.jpg')}<div class="grow"><div class="t">Under the pier</div><div class="d num">0:54</div></div></div>
<div class="rc">${ic('right', 14, 2)}<span class="grow">Follow the lantern</span><span class="btn">Choose again</span></div>
<div class="rt">${still('drowned-quarter.jpg', '30% 50%', true)}<div class="grow"><div class="t">The drowned quarter</div><div class="d">now</div></div></div>
<div style="padding:16px 16px 0"><span class="btn wide">${ic('replay', 16)}Start over</span></div>`, { glass: true })}${hi()}`),

  frame('P4c', 'An interactive movie · an ending', media(), `<img class="pic" src="${A}scene4-shot15.jpg" alt="" style="object-position:50% 40%"><div class="st"></div><div class="sbot" style="height:560px"></div>${sb(true)}<div class="ptop">${close}</div>
<div style="position:absolute;z-index:4;left:20px;right:20px;bottom:44px"><div class="eb">Ending</div><div style="margin-top:8px;font:var(--weight-bold) var(--text-4xl)/1.08 var(--font-sans);letter-spacing:var(--tracking-tighter)">The Bell Rings Twice</div>
<div style="display:flex;align-items:center;gap:6px;margin-top:20px">${still('launch-harbour.jpg', '50% 60%', false, 64, 36)}${ic('right', 14, 2)}${still('scene4-shot15.jpg', 'center', false, 64, 36)}${ic('right', 14, 2)}${still('drowned-quarter.jpg', '30% 50%', false, 64, 36)}${ic('right', 14, 2)}${still('scene4-shot13.jpg', 'center', true, 64, 36)}</div>
<div class="mute" style="margin-top:10px;font:var(--type-meta)">Take the skiff · Follow the lantern · Ring the bell</div>
<div style="display:flex;flex-direction:column;gap:8px;margin-top:22px"><span class="btn pri wide">${ic('replay', 16)}Start again</span><span class="btn wide">Back to last choice</span></div></div>${hi()}`),

  frame('P4d', 'A visual novel · a line', media(), `${lantern}<div class="sbot" style="height:400px"></div>
<div class="vnbox"><span class="who">Maren</span><div class="vnline">Somebody lit a window down there. Nobody lives in the quarter now.</div><span style="position:absolute;right:16px;bottom:10px;color:color-mix(in srgb,var(--media-overlay-fg) 70%,transparent)">${ic('right', 16, 2)}</span></div><div class="beats"><i class="done"></i><i class="done"></i><i class="done"></i><i></i><i></i><i></i></div>${hi()}`),

  frame('P4e', 'A visual novel · the log', media(), `${lantern}<div class="veil" style="background:color-mix(in srgb,var(--media-overlay-bg) 30%,transparent)"></div>${sheet('Log', `${[['', 'The market shut at the second bell. One lamp stayed lit.', 'nar'], ['Maren', 'Somebody lit a window down there.', ''], ['Ilo', 'Then somebody lives there.', ''], ['Maren', 'Nobody lives in the quarter now.', 'now']].map(([s, t, c]) => `<div class="lr${c === 'nar' ? ' nar' : c === 'now' ? ' now' : ''}"><div class="grow">${s ? `<div class="spk">${s}</div>` : ''}<div class="tx">${t}</div></div><span class="ib">${ic('play', 14)}</span></div>`).join('')}`, { glass: true, count: 'Scene 3' })}${hi()}`),
];

// ---- P5 · listening and reading ----------------------------------------------------------------
const book = (where = '7 · The Tenth Key') => `<img class="pic" src="${A}scene4-shot15.jpg" alt="" style="height:62%;object-position:50% 45%"><div class="st"></div><div class="sbot" style="height:520px"></div>${sb(true)}
<div class="ptop">${close}<div class="ttl"><div class="eb">The Tenth Key</div><div class="sc">${where}</div></div><span class="ib">${ic('list', 20)}</span><span class="ib">${ic('more', 20)}</span></div>
<div style="position:absolute;z-index:5;left:16px;top:106px"><span class="ib lab glass" style="height:44px;gap:10px;padding:0 10px 0 14px">Slow push<span class="sw sm on"></span></span></div>`;
const audioBar = (row2) => `<div style="position:absolute;z-index:4;left:20px;right:20px;bottom:40px"><div class="scrub"><i style="width:44%"></i><b style="left:44%"></b></div><div class="times"><span>13:58</span><span>31:40</span></div>
<div class="trow" style="margin-top:14px"><span class="ib">${ic('prev', 20)}</span><span class="ib">${seek(15)}</span><span class="play">${ic('pause', 24)}</span><span class="ib">${seek(30, false)}</span><span class="ib">${ic('next', 20)}</span></div>
<div class="trow" style="margin-top:14px">${row2}</div></div>`;
const bookRow2 = `<span class="ib lab">1.0×</span><span class="ib lab">${ic('moon', 16)}End of chapter</span><span class="ib lab on">${ic('text', 16)}Text</span>`;

const P5 = [
  frame('P5a', 'An audiobook', media(), `${book()}<div class="words" style="bottom:286px">Odile did not answer. She held the lamp lower.</div>${audioBar(bookRow2)}${hi()}`),

  frame('P5b', 'Chapters', media(), `${book()}<div class="veil" style="background:color-mix(in srgb,var(--media-overlay-bg) 30%,transparent)"></div>${sheet('Chapters', `${[['5', 'The Weigh House', '39:12', 'done'], ['6', 'The Weir', '41:20', 'done'], ['7', 'The Tenth Key', '31:40', 'now'], ['8', 'Saltmouth Bells', '38:05', 'dl'], ['9', 'A Choir Underwater', '44:10', ''], ['10', 'The Keeper’s Ledger', '36:48', '']].map(([n, t, d, s]) => `<div class="chr${s === 'now' ? ' now' : ''}"><span class="no">${n}</span><div class="grow"><div class="t">${t}</div>${s === 'now' ? '<div class="ln2"><i style="width:44%"></i></div>' : ''}</div><span class="d">${d}</span><span style="width:20px;opacity:.7">${s === 'done' ? ic('check', 18, 2.2) : s === 'dl' || s === 'now' ? ic('downloaded', 18) : ''}</span></div>`).join('')}`, { glass: true, count: '22' })}${hi()}`),

  frame('P5c', 'Speed and sleep', media(), `${book()}<div class="veil" style="background:color-mix(in srgb,var(--media-overlay-bg) 30%,transparent)"></div>${sheet('Speed', `<div class="seg"><span>0.8×</span><span class="on">1.0×</span><span>1.2×</span><span>1.5×</span><span>2×</span></div><div class="sht" style="padding-top:22px"><h3>Sleep</h3></div>${['Off', 'End of chapter', '15 min', '30 min', '60 min'].map((l) => `<div class="opt"><span class="l">${l}</span>${l === 'End of chapter' ? ic('check', 20, 2.2) : ''}</div>`).join('')}`, { glass: true })}${hi()}`),

  frame('P5d', 'An audio drama · the transcript', media(), `${sb(true)}<div class="ptop">${close}<div class="ttl"><div class="eb">Undertow</div><div class="sc">3 · The Weir Gate</div></div><span class="ib">${ic('more', 20)}</span></div>
<div style="position:absolute;left:16px;right:16px;top:108px;height:150px;border-radius:14px;overflow:hidden"><img src="${A}banner-audio.jpg" alt="" style="width:100%;height:100%;object-fit:cover;object-position:50% 40%"></div>
<div class="mask" style="position:absolute;left:0;right:0;top:268px;height:300px;overflow:hidden;padding-top:26px">${[['Sereth', 'You said the gate would hold.', ''], ['Maren', 'I said it would hold until the tide turned.', ''], ['', '[Bells, far off. Water rising.]', 'fx'], ['Bray', 'Then it’s turned. Listen.', 'now'], ['Maren', 'That isn’t the tide.', '']].map(([s, t, c]) => `<div class="tl${c ? ' ' + c : ''}">${s ? `<div class="spk">${s}</div>` : ''}<div class="ln">${t}</div></div>`).join('')}</div>
${audioBar(`<span class="ib lab">1.0×</span><span class="ib lab">${ic('moon', 16)}Off</span><span class="ib lab on">${ic('text', 16)}Transcript</span><span class="ib">${ic('list', 18)}</span>`).replace('width:44%"></i><b style="left:44%', 'width:38%"></i><b style="left:38%').replace('<span>13:58</span><span>31:40</span>', '<span>9:12</span><span>24:30</span>')}${hi()}`),

  frame('P5e', 'A book', 'phone', `${sb()}<div class="hd" style="gap:6px;padding-bottom:0"><span class="icb" style="background:none">${ic('down', 24, 2)}</span><span class="grow mute" style="text-align:center;font:var(--type-ui)">7 · The Tenth Key</span><span class="icb" style="background:none;font:var(--type-ui);font-size:var(--text-md)">Aa</span><span class="icb" style="background:none">${ic('list', 20)}</span></div>
<div class="body"><div class="page"><div class="no" style="margin-top:18px">Chapter 7</div><h2>The Tenth Key</h2><p class="first">The key had no teeth. Odile turned it over twice in the lamplight before she understood that it was not meant for a lock at all.</p><p>Below the window the harbour lay flat and black. The bells had stopped an hour ago, and the silence they left behind was louder than any of them.</p><p>“You found it,” Bray said from the door. He did not come in.</p><p>“It found me.” She closed her hand around it. “Where is the tenth door?”</p><p>He looked at the water for a long time before he answered.</p></div></div>
<div style="flex:none;display:flex;align-items:center;gap:12px;padding:10px 20px 40px"><span class="mute num" style="font:var(--type-meta)">12 of 30</span><div class="bar grow"><i style="width:40%"></i></div><span class="btn" style="height:40px">${ic('headphones', 16)}Listen</span></div>${hi()}`),
];

// ---- P6 · offline, You, the Fold -------------------------------------------------------------
const FOLDWC = 'width:270px;height:152px';
const dlRow = (img, pos, title, state, end, at) => `<div class="ep"><div class="th" style="width:96px;height:54px"><img src="${A}${img}" alt="" style="object-position:${pos}"></div><div class="grow"><div class="t">${title}</div><div class="m">${state}</div>${at != null ? `<div class="bar" style="margin-top:7px;height:3px"><i style="width:${at}%"></i></div>` : ''}</div><span class="end">${end}</span></div>`;

const P6 = [
  frame('P6a', 'Downloads', 'phone', `${sb()}<div class="hd"><h1>Downloads</h1></div><div class="body">
<div style="padding:8px 16px 0"><div class="sbar"><i class="me" style="width:7%"></i><i class="other" style="width:58%"></i></div><div class="leg"><span><i></i>Arke Player 3.2 GB</span><span><i class="other"></i>Other 29 GB</span><span><i class="free"></i>41 GB free</span></div></div>
${sh('Shared')}${dlRow(PR.saltlight.img, PR.saltlight.pos, 'Saltlight', `<span class="num">1.9 GB</span>${ic('downloaded', 14)}`, ic('more', 18))}${dlRow(PR.tenth.img, '50% 40%', 'The Tenth Key', '<span class="num">Downloading · 42%</span>', ic('pausec', 22), 42)}${dlRow(PR.bell.img, '50% 26%', 'The Bell Watch', `${ic('clock', 14)}<span>Waiting for Wi-Fi</span>`, ic('more', 18))}
${sh('Added')}${dlRow(W.meridian.img, '40% 50%', 'Meridian Dust', '<span class="num">3 productions · 1.4 GB</span>', ic('more', 18))}${dlRow('char-maren.jpg', '50% 20%', 'The Salt Almanac', '<span class="num">EPUB · 2.1 MB</span>', ic('more', 18))}
</div>${tabs('Downloads')}${hi()}`),

  frame('P6b', 'You', 'phone', `${sb()}<div class="hd"><h1>You</h1></div><div class="body" style="padding-top:8px">
<div class="grp"><div class="r" style="min-height:72px"><span class="av" style="width:46px;height:46px;font:var(--type-ui)">JP</span><span class="l"><span style="display:block">Jonah Pike</span><span class="mute" style="display:block;font:var(--type-meta)">jonah@pike.house</span></span><span class="c">${ic('out', 16, 2)}</span></div>${row('Sign out', '', '')}</div>
<div class="gl">Playback</div><div class="grp">${row('Captions', 'English')}${row('Text', '', 'off')}${row('Slow push', '', 'on')}${row('Autoplay next', '', 'on')}</div>
<div class="gl">Downloads</div><div class="grp">${row('Wi-Fi only', '', 'on')}${row('Storage', '3.2 GB')}</div>
<div class="gl">Content</div><div class="grp">${row('Adult content', 'Off')}</div>
</div>${tabs('You')}${hi()}`),

  frame('P6c', 'Adult content', 'phone', `${sb(true)}<div class="body"><div class="hero" style="padding-top:226px"><img src="${A}world-copper-saints.jpg" alt="" style="height:300px"><div class="fade" style="top:100px;height:201px"></div><div class="top">${back}${more}</div><div class="in"><h1>Copper Saints</h1><div class="meta">Ama Mensah · 2 productions</div></div></div>
${sh('Watch')}<div class="hrow">${tile({ img: 'world-copper-saints.jpg', pos: '20% 50%', title: 'Vigil', kind: 'Film · 48 min', cls: 'adult', tag: '<span class="tag glass">18+</span>', mid: ic('eyeoff', 26) })}</div>
${sh('Listen')}<div class="hrow">${tile({ img: 'world-copper-saints.jpg', pos: '70% 50%', title: 'Foundry Hymns', kind: 'Audiobook · 11 chapters' })}</div>
</div>${tabs('Library')}<div class="veil"></div>${sheet('', `<div style="display:flex;flex-direction:column;align-items:center;text-align:center;gap:8px;padding:14px 20px 0">${ic('eyeoff', 32)}<div style="margin-top:4px;font:var(--type-h3)">Adult content is off</div><div class="mute" style="font:var(--type-ui)">Vigil · 18+</div></div><div style="display:flex;flex-direction:column;gap:8px;padding:20px 16px 0"><span class="btn pri wide">I am 18 or older · Turn on</span><span class="btn ghost wide">Not now</span></div>`)}${hi()}`),

  frame('P6d', 'Offline', 'phone', `${sb(false, true)}<div class="hd"><h1>Home</h1><span class="tag line" style="height:28px;padding:0 10px;font-size:var(--text-xs)">${ic('wifioff', 14, 2)}Offline</span><span class="av">JP</span></div><div class="body">
${sh('Continue')}<div class="hrow">${cc({ img: PR.saltlight.img, pos: PR.saltlight.pos, kind: 'Film', title: 'Saltlight', where: '38 min left', at: 59 })}<div class="cc off" style="width:300px;height:169px"><img src="${A}drowned-quarter.jpg" alt="" style="object-position:30% 50%"><div class="shade"></div><div class="tx"><div class="k">Interactive movie</div><div class="t">Low Water</div><div class="w">offline</div></div></div></div>
${sh('New')}<div class="hrow">${tile({ ...PR.bell, kind: 'offline', cls: 'off' })}${tile({ ...PR.undertow, kind: 'offline', cls: 'off' })}${tile({ img: 'world-meridian-dust.jpg', pos: '30% 50%', title: 'Dust Line', kind: 'Interactive movie · Meridian Dust' })}</div>
${sh('Worlds')}<div class="hrow">${wc({ ...W.undersong, meta: 'Helen Marsh', cls: 'mini', pos: '60% 50%' })}${wc({ ...W.meridian, meta: 'Added', cls: 'mini', pos: '40% 50%' })}</div>
</div>${tabs('Home')}${hi()}`),

  frame('P6e', 'Home on a Fold', 'fold', `${tabs('Home', true)}<div class="grow" style="display:flex;flex-direction:column;min-width:0;position:relative">${sb()}<div class="hd" style="padding:6px 28px 6px 24px"><h1>Home</h1><span class="av">JP</span></div><div class="body">
<div class="sh" style="padding:0 24px">${'<h2>Continue</h2>'}</div><div class="hrow" style="padding:0 24px;gap:16px">${cc({ img: PR.tenth.img, pos: '50% 40%', kind: 'Audiobook', title: 'The Tenth Key', where: 'Chapter 7 · 19 min left', at: 55, w: 420 })}${cc({ img: PR.saltlight.img, pos: PR.saltlight.pos, kind: 'Film', title: 'Saltlight', where: '38 min left', at: 59, w: 420 })}</div>
<div class="sh" style="padding:0 24px"><h2>New</h2></div><div class="hrow" style="padding:0 24px;gap:16px">${tile({ ...PR.bell, kind: 'Micro drama · The Undersong', w: 200 })}${tile({ ...PR.undertow, kind: 'Audio drama · The Undersong', w: 200 })}${tile({ img: 'world-copper-saints.jpg', pos: '70% 50%', title: 'Foundry Hymns', kind: 'Audiobook · Copper Saints', w: 200 })}${tile({ ...PR.lantern, kind: 'Visual novel · The Undersong', w: 200 })}</div>
<div class="sh" style="padding:0 24px"><h2>Worlds</h2></div><div class="hrow" style="padding:0 24px;gap:16px">${wc({ ...W.undersong, meta: 'Helen Marsh', cls: 'mini', pos: '60% 50%', style: FOLDWC })}${wc({ ...W.copper, meta: 'Ama Mensah', cls: 'mini', style: FOLDWC })}${wc({ ...W.meridian, meta: 'Added', cls: 'mini', pos: '40% 50%', style: FOLDWC })}</div>
</div>${hi()}</div>`),

  frame('P6f', 'An audiobook on a Fold', 'fold media', `<img src="${A}scene4-shot15.jpg" alt="" style="position:absolute;left:0;top:0;width:984px;height:553px;object-fit:cover;object-position:50% 45%"><div style="position:absolute;left:0;right:0;top:380px;height:174px;background:linear-gradient(to bottom,transparent,var(--media-overlay-bg))"></div><div class="st"></div>${sb(true)}
<div class="ptop" style="left:20px;right:20px">${close}<div class="ttl"><div class="eb">The Tenth Key</div><div class="sc">7 · The Tenth Key</div></div><span class="ib lab glass" style="height:44px;gap:10px;padding:0 10px 0 14px">Slow push<span class="sw sm on"></span></span><span class="ib">${ic('list', 20)}</span><span class="ib">${ic('more', 20)}</span></div>
<div class="fold-words" style="top:688px">Odile did not answer. She held the lamp lower.</div>
<div style="position:absolute;z-index:4;left:172px;width:640px;bottom:64px"><div class="scrub"><i style="width:44%"></i><b style="left:44%"></b></div><div class="times"><span>13:58</span><span>31:40</span></div>
<div class="trow" style="margin-top:16px;justify-content:center;gap:28px"><span class="ib">${ic('prev', 20)}</span><span class="ib">${seek(15)}</span><span class="play">${ic('pause', 24)}</span><span class="ib">${seek(30, false)}</span><span class="ib">${ic('next', 20)}</span></div>
<div class="trow" style="margin-top:16px;justify-content:center;gap:12px">${bookRow2}</div></div>${hi()}`),
];

// ---- P7 · files in standard formats ----------------------------------------------------------
const FILES = {
  almanac: { img: 'char-maren.jpg', pos: '50% 20%', title: 'The Salt Almanac', m: 'EPUB · Ines Varga · 2.1 MB' },
  boards: { img: 'scene4-board-sheet.jpg', pos: '0% 0%', title: 'Saltlight boards', m: 'PDF · 24 pages · 18 MB' },
  tide: { img: 'launch-harbour.jpg', pos: '50% 50%', title: 'Tidewater Sessions', m: 'M4B · 6 h 12 m · 288 MB' },
  reel: { img: 'banner-video.jpg', pos: '60% 50%', title: 'Lighthouse reel', m: 'MP4 · 12 min · 410 MB' },
};
const frow = ({ img, pos, title, m }, end, cls = '') => `<div class="frow${cls ? ' ' + cls : ''}"><span class="fth">${img ? `<img src="${A}${img}" alt="" style="object-position:${pos}">` : 'EPUB'}</span><div class="grow"><div class="t">${title}</div><div class="m">${m}</div></div><span class="end">${end}</span></div>`;
const addedLibrary = `${sb()}<div class="hd"><h1>Library</h1><span class="icb">${ic('plus', 20, 2)}</span></div><div class="chips"><span class="chip">All</span><span class="chip">Shared</span><span class="chip on">Added</span></div><div class="body" style="padding-top:16px">${wc({ ...W.meridian, meta: 'Added · 3 productions · 1.4 GB', pos: '40% 50%' })}
${sh('Files')}${[FILES.almanac, FILES.boards, FILES.tide, FILES.reel].map((f) => frow(f, ic('more', 18))).join('')}
</div>${tabs('Library')}`;

const P7 = [
  frame('P7a', 'Adding files', 'phone', `${addedLibrary}<div class="veil"></div>${sheet('Add', `${frow(FILES.almanac, ic('check', 18, 2.2))}${frow(FILES.boards, ic('check', 18, 2.2))}${frow(FILES.tide, ic('check', 18, 2.2))}${frow({ title: 'Dune Road', m: 'Protected file' }, `<span class="warn">${ic('alert', 18)}</span>`, 'no')}<div style="display:flex;flex-direction:column;gap:8px;padding:16px 16px 0"><span class="btn pri wide">Add 3</span><span class="btn ghost wide">Cancel</span></div>`, { count: '4 files' })}${hi()}`),

  frame('P7b', 'Library · Added, with files', 'phone', `${addedLibrary}${hi()}`),

  frame('P7c', 'A PDF', 'phone pdf', `${sb()}<div class="hd" style="gap:6px;padding-bottom:10px"><span class="icb" style="background:none">${ic('down', 24, 2)}</span><span class="grow" style="text-align:center;font:var(--type-ui)">Saltlight boards</span><span class="icb" style="background:none">${ic('list', 20)}</span><span class="icb" style="background:none">${ic('more', 20)}</span></div>
<div class="body"><div class="pg" style="margin-top:-120px"><img src="${A}maren-sheet-pitchboard.jpg" alt=""></div><div class="pg"><img src="${A}scene4-board-sheet.jpg" alt=""></div><div class="pg"><img src="${A}board-source.jpg" alt=""></div></div>
<div style="flex:none;display:flex;align-items:center;gap:12px;padding:10px 20px 40px;background:var(--secondary)"><span class="mute num" style="font:var(--type-meta)">3 of 24</span><div class="bar grow" style="background:color-mix(in srgb,var(--foreground) 12%,transparent)"><i style="width:12%"></i></div></div>${hi()}`),

  frame('P7d', 'An audiobook file', media(), `${sb(true)}<div class="ptop">${close}<div class="ttl"><div class="eb">Tidewater Sessions</div><div class="sc">Chapter 4</div></div><span class="ib">${ic('list', 20)}</span><span class="ib">${ic('more', 20)}</span></div>
<img src="${A}launch-harbour.jpg" alt="" style="position:absolute;left:45px;top:126px;width:300px;height:300px;object-fit:cover;border-radius:14px;box-shadow:var(--shadow-xl)">
<div style="position:absolute;left:24px;right:24px;top:452px;text-align:center"><div style="font:var(--type-h3);letter-spacing:var(--tracking-tight)">Tidewater Sessions</div><div class="mute" style="margin-top:2px;font:var(--type-ui)">Amaal Reyes</div></div>
${audioBar(`<span class="ib lab">1.0×</span><span class="ib lab">${ic('moon', 16)}Off</span>`).replace('width:44%"></i><b style="left:44%', 'width:62%"></i><b style="left:62%').replace('<span>13:58</span><span>31:40</span>', '<span>27:05</span><span>43:30</span>').replace('<div class="trow" style="margin-top:14px"><span class="ib lab">', '<div class="trow" style="margin-top:14px;justify-content:center;gap:24px"><span class="ib lab">')}${hi()}`),
];

// ---- P8 · before an account, and a library of files only (the MVP) --------------------------------
const MINE = {
  tide: { img: 'launch-harbour.jpg', pos: '50% 50%', title: 'Tidewater Sessions', m: 'M4B · Amaal Reyes · 6 h 12 m · 288 MB', fmt: 'M4B · 6 h 12 m' },
  songs: { img: 'banner-audio.jpg', pos: '30% 50%', title: 'Harbour Songs', m: 'MP3 · 3:42 · 8 MB', fmt: 'MP3 · 3:42' },
  almanac: { img: 'char-maren.jpg', pos: '50% 20%', title: 'The Salt Almanac', m: 'EPUB · Ines Varga · 2.1 MB', fmt: 'EPUB · Ines Varga' },
  boards: { img: 'scene4-board-sheet.jpg', pos: '0% 0%', title: 'Saltlight boards', m: 'PDF · 24 pages · 18 MB', fmt: 'PDF · 24 pages' },
  ferry: { img: 'drowned-quarter.jpg', pos: '30% 50%', title: 'Night Ferry', m: 'MOV · 1 h 48 m · 2.4 GB', fmt: 'MOV · 1 h 48 m' },
  reel: { img: 'banner-video.jpg', pos: '60% 50%', title: 'Lighthouse reel', m: 'MP4 · 12 min · 410 MB', fmt: 'MP4 · 12 min' },
};
const ALL_MINE = [MINE.tide, MINE.songs, MINE.almanac, MINE.boards, MINE.ferry, MINE.reel];
const sq = ({ img, pos, title, fmt }) => `<div class="sq"><div class="im"><img src="${A}${img}" alt="" style="object-position:${pos}"></div><div class="t">${title}</div><div class="m">${fmt}</div></div>`;
const kindChips = `<div class="chips"><span class="chip on">All</span><span class="chip">Listen</span><span class="chip">Read</span><span class="chip">Watch</span></div>`;
const filesLibrary = (rail = false) => `${sb()}<div class="hd"${rail ? ' style="padding:6px 28px 6px 24px"' : ''}><h1>Library</h1><span class="icb">${ic('plus', 20, 2)}</span></div>${kindChips.replace('class="chips"', rail ? 'class="chips" style="padding:2px 24px 0"' : 'class="chips"')}<div class="body" style="padding-top:12px">${rail ? `<div class="cols2">${ALL_MINE.map((f) => frow(f, ic('more', 18))).join('')}</div>` : ALL_MINE.map((f) => frow(f, ic('more', 18))).join('')}</div>`;

const P8 = [
  frame('P8a', 'First open, before sign-in', media(), `<img class="pic" src="${A}launch-harbour.jpg" alt="" style="height:66%;object-position:50% 40%"><div class="sbot" style="height:600px"></div>${sb(true)}
<div style="position:absolute;left:0;right:0;top:432px;text-align:center"><div class="wm">Arke</div><div class="wm2">Player</div></div>
<div style="position:absolute;left:20px;right:20px;bottom:54px"><span class="btn pri wide">${ic('plus', 18, 2)}Add a file</span></div>${hi()}`),

  frame('P8b', 'Home, nothing added', 'phone', `${sb()}<div class="hd"><h1>Home</h1></div><div class="body"><div class="empty"><div class="state">Nothing added</div><span class="btn pri">${ic('plus', 18, 2)}Add a file</span></div></div>${tabs('Home')}${hi()}`),

  frame('P8c', 'Library, files only', 'phone', `${filesLibrary()}${tabs('Library')}${hi()}`),

  frame('P8d', 'Home, with files', 'phone', `${sb()}<div class="hd"><h1>Home</h1></div><div class="body">
${sh('Continue')}<div class="hrow">${cc({ img: MINE.tide.img, pos: '50% 50%', kind: 'Audiobook', title: 'Tidewater Sessions', where: 'Chapter 4 · 16 min left', at: 62 })}${cc({ img: MINE.ferry.img, pos: MINE.ferry.pos, kind: 'Film', title: 'Night Ferry', where: '52 min left', at: 52 })}</div>
${sh('Added')}<div class="hrow">${[MINE.almanac, MINE.boards, MINE.reel, MINE.songs].map(sq).join('')}</div>
</div>${tabs('Home')}${hi()}`),

  frame('P8e', 'Library on a Fold, files only', 'fold', `${tabs('Library', true)}<div class="grow" style="display:flex;flex-direction:column;min-width:0;position:relative">${filesLibrary(true)}${hi()}</div>`),

  frame('P8f', 'You, before sign-in', 'phone', `${sb()}<div class="hd"><h1>You</h1></div><div class="body" style="padding-top:8px">
<div class="gl" style="margin-top:6px">Playback</div><div class="grp">${row('Captions', 'English')}</div>
<div class="gl">Storage</div><div class="grp">${row('On this phone', '3.2 GB')}</div>
<div class="gl">About</div><div class="grp">${row('Version', '0.1.0', '')}${row('Licences')}</div>
</div>${tabs('You')}${hi()}`),
];

// ---- P9 · worlds to install ---------------------------------------------------------------------
// The demo is The Undersong as Arke publishes it: The Ledger of Nights, 16 illustrated chapters with
// the narration of 6 (ArkeStudio release undersong-2026-10-19-r3). Its Player package does not exist
// yet, so its size and file count are samples.
const DEMO = { size: '386 MB', ledger: { img: 'banner-story.jpg', pos: '50% 40%', title: 'The Ledger of Nights', kind: 'Audiobook · Book · 2 h 3 m' } };
const demoMeta = `1 production · ${DEMO.size}`;
const installHero = (cta, { meta = demoMeta, top = back } = {}) => `<div class="hero" style="padding-top:218px"><img src="${A}${W.undersong.img}" alt="" style="height:290px;object-position:60% 50%"><div class="fade" style="top:90px;height:201px"></div><div class="top">${top}</div><div class="in"><h1>${W.undersong.name}</h1><div class="meta num">${meta}</div><div class="lg">${W.undersong.logline}</div>${cta}</div></div>`;
const installPress = (style = 'margin-top:16px') => `<div style="${style}"><span class="btn pri wide">${ic('download', 18)}Install <em>· ${DEMO.size}</em></span></div>`;
const installing = `<div style="margin-top:20px"><div class="bar"><i style="width:42%"></i></div><div style="display:flex;align-items:center;gap:10px;margin-top:10px"><span class="grow mute num" style="font:var(--type-ui)">Downloading · 162 MB of ${DEMO.size}</span><span class="btn" style="height:40px">Cancel</span></div></div>`;
const inside = `${sh('Inside')}<div class="ep"><div class="th"><img src="${A}${DEMO.ledger.img}" alt="" style="object-position:${DEMO.ledger.pos}"></div><div class="grow"><div class="t">${DEMO.ledger.title}</div><div class="m"><span class="num">${DEMO.ledger.kind}</span></div></div></div>
<div style="height:14px"></div><div class="grp">${row('Space', `${DEMO.size} of 41 GB free`, '')}</div>`;

const P9 = [
  frame('P9a', 'First open, with a world to install', media(), `<img class="pic" src="${A}launch-harbour.jpg" alt="" style="height:66%;object-position:50% 40%"><div class="sbot" style="height:600px"></div>${sb(true)}
<div style="position:absolute;left:0;right:0;top:400px;text-align:center"><div class="wm">Arke</div><div class="wm2">Player</div></div>
<div style="position:absolute;left:20px;right:20px;bottom:54px;display:flex;flex-direction:column;gap:10px"><span class="btn pri wide">${ic('plus', 18, 2)}Add a file</span><span class="btn wide">${ic('download', 18)}Install a world</span></div>${hi()}`),

  frame('P9b', 'Available', 'phone', `${sb()}<div class="hd"><span class="icb">${ic('left', 20, 2)}</span><h1>Available</h1></div><div class="body" style="padding-top:12px">${wc({ ...W.undersong, meta: demoMeta, pos: '60% 50%' })}</div>${hi()}`),

  frame('P9c', 'A world, before it is installed', 'phone', `${sb(true)}<div class="body">${installHero(installPress())}${inside}</div>${tabs('Home')}${hi()}`),

  frame('P9d', 'Installing', 'phone', `${sb(true)}<div class="body">${installHero(installing)}${inside}</div>${tabs('Home')}${hi()}`),

  frame('P9e', 'Not installed', 'phone', `${sb(true)}<div class="body">${installHero(installPress())}${inside}</div>${tabs('Home')}<div class="veil"></div>${sheet('', `<div style="display:flex;flex-direction:column;align-items:center;text-align:center;gap:8px;padding:14px 20px 0"><span class="mute">${ic('wifioff', 34, 1.8)}</span><div style="margin-top:4px;font:var(--type-h3)">No connection</div><div class="mute num" style="font:var(--type-ui)">The Undersong · ${DEMO.size}</div></div><div style="display:flex;flex-direction:column;gap:8px;padding:20px 16px 0"><span class="btn pri wide">Try again</span><span class="btn ghost wide">Close</span></div>`)}${hi()}`),

  frame('P9f', 'The Undersong, installed', 'phone', `${sb(true)}<div class="body">${installHero('', { meta: `Installed · ${demoMeta}`, top: back + more })}
${sh('Listen')}<div class="hrow">${tile({ ...DEMO.ledger, w: 358 })}</div></div>${tabs('Home')}${hi()}`),

  frame('P9g', 'Home, with a world to install', 'phone', `${sb()}<div class="hd"><h1>Home</h1></div><div class="body">
${sh('Continue')}<div class="hrow">${cc({ img: MINE.tide.img, pos: '50% 50%', kind: 'Audiobook', title: 'Tidewater Sessions', where: 'Chapter 4 · 16 min left', at: 62 })}${cc({ img: MINE.ferry.img, pos: MINE.ferry.pos, kind: 'Film', title: 'Night Ferry', where: '52 min left', at: 52 })}</div>
${sh('Added')}<div class="hrow">${[MINE.almanac, MINE.boards, MINE.reel, MINE.songs].map(sq).join('')}</div>
${sh('Available')}<div class="hrow">${wc({ ...W.undersong, meta: demoMeta, cls: 'mini', pos: '60% 50%' })}</div>
</div>${tabs('Home')}${hi()}`),

  frame('P9h', 'A world to install, on a Fold', 'fold', `${tabs('Home', true)}<div class="grow" style="display:flex;flex-direction:column;min-width:0;position:relative">${sb(true)}<div class="body"><div class="hero" style="padding:300px 32px 28px"><img src="${A}${W.undersong.img}" alt="" style="height:400px;object-position:60% 45%"><div class="fade" style="top:200px;height:201px"></div><div class="top" style="left:20px;right:20px">${back}</div><div class="in" style="max-width:640px"><h1>${W.undersong.name}</h1><div class="meta num">${demoMeta}</div><div class="lg">${W.undersong.logline}</div>${installPress('margin-top:18px;width:320px')}</div></div>
<div style="max-width:672px;padding:0 16px">${inside}</div></div>${hi()}</div>`),
];

// ---- P10 · a world already in Library -------------------------------------------------------------
// SPEC-058 R-21: a package of a world the library holds. Another edition offers Replace; the same
// edition is refused. The sample is the Studio's Export → Arke Player (Studio 233) of The Undersong,
// made a day after the edition in Library.
const undersongReady = (foot) => `${sb()}<div class="hd"><span class="icb">${ic('x', 18, 2)}</span><span class="grow"></span></div><div class="body">
<div class="on-media" style="position:relative;margin:4px 16px 0;height:200px;border-radius:16px;overflow:hidden;background:var(--media-overlay-bg)"><img src="${A}world-undersong.jpg" alt="" style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:60% 50%"><div class="shade"></div><div style="position:absolute;left:16px;bottom:14px"><div class="k">Package</div><div style="margin-top:3px;font:var(--weight-semibold) var(--text-2xl)/1.15 var(--font-sans);letter-spacing:var(--tracking-tighter)">The Undersong</div></div></div>
<div class="mute num" style="padding:10px 16px 0;font:var(--type-ui)">made 21 Oct 2026 · 1 production · 228 MB</div>
${sh('Inside')}<div class="ep"><div class="th"><img src="${A}banner-story.jpg" alt="" style="object-position:50% 40%"></div><div class="grow"><div class="t">The Ledger of Nights</div><div class="m"><span class="num">Audiobook · Book · 3 h 49 m</span></div></div></div>
<div style="height:14px"></div><div class="grp">${row('In Library', '20 Oct 2026 · 182 MB', '')}${row('Space', '+46 MB of 41 GB free', '')}</div>
</div>${foot}${hi()}`;

const P10 = [
  frame('P10a', 'Another edition: Replace', 'phone', undersongReady(`<div style="flex:none;display:flex;flex-direction:column;gap:8px;padding:12px 16px 34px"><span class="btn pri wide">Replace</span><span class="btn ghost wide">Cancel</span></div>`)),

  frame('P10b', 'The same edition: Already in Library', 'phone', `${libraryBehind()}<div class="veil"></div>${sheet('', `<div style="display:flex;flex-direction:column;align-items:center;text-align:center;gap:8px;padding:14px 20px 0"><span class="mute">${ic('library', 34, 1.8)}</span><div style="margin-top:4px;font:var(--type-h3)">Already in Library</div><div class="mute num" style="font:var(--type-ui)">The Undersong · 21 Oct 2026</div></div><div style="display:flex;flex-direction:column;gap:8px;padding:20px 16px 0"><span class="btn pri wide">Open</span><span class="btn ghost wide">Close</span></div>`)}${hi()}`),
];

// ---- P11 · worlds to explore: characters, places, lore --------------------------------------------
// The guide is what the author made public in the Studio (Studio 234): The Undersong's cast, places and
// canon, from ArkeStudio's fixture world. Copper Saints and Meridian Dust stand for the worlds to come.
const CAST = {
  maren: { img: 'char-maren.jpg', pos: '50% 18%', name: 'Maren Kest', role: 'Tide-caller' },
  bray: { img: 'char-bray.jpg', pos: '50% 20%', name: 'Bray Half-Hitch', role: 'Rigger' },
  chorister: { img: 'char-chorister.jpg', pos: '50% 20%', name: 'The Chorister', role: 'Keeper of the drowned verse' },
  perrin: { ini: 'PT', name: 'Perrin Tallow', role: 'Council actuary' },
};
const PLACES = {
  vigil: { img: 'scene4-shot13.jpg', pos: '70% 20%', title: 'The Vigil', kind: 'Place' },
  saltmarket: { img: 'launch-harbour.jpg', pos: '50% 62%', title: 'The Saltmarket', kind: 'Place' },
  chapel: { img: 'drowned-quarter.jpg', pos: '40% 50%', title: 'The Drowned Chapel', kind: 'Place' },
};
const LORE = [['Lore', 'The Undersong'], ['Rule', 'Tide-calling'], ['Timeline', 'The drowning of the god'], ['Rule', 'The ledger is never wrong'], ['Lore', 'The Departure'], ['Rule', 'The Seven Anchors']];
const pc = (c, w = 120) => `<div class="pc" style="width:${w}px"><div class="im">${c.img ? `<img src="${A}${c.img}" alt="" style="object-position:${c.pos}">` : `<span class="ini">${c.ini}</span>`}</div><div class="t">${c.name}</div><div class="m">${c.role}</div></div>`;
const pcGated = (after, w = 120) => `<div class="pc gated" style="width:${w}px"><div class="im">${ic('eyeoff', 26, 1.7)}</div><div class="t mute">${after}</div><div class="m">Character</div></div>`;
const lr = ([kind, title]) => `<div class="lr"><div class="grow"><div class="lk">${kind}</div><div class="t">${title}</div></div><span class="mute">${ic('right', 16)}</span></div>`;
const gate = (after) => `<div class="lr"><span class="mute">${ic('eyeoff', 20, 1.8)}</span><div class="grow"><div class="t mute">${after}</div></div><span class="btn" style="height:36px;padding:0 15px">Reveal</span></div>`;
const castRow = `${[CAST.maren, CAST.bray, CAST.perrin].map((c) => pc(c)).join('')}${pcGated('After Chapter 9')}`;
const placesRow = [PLACES.vigil, PLACES.saltmarket, PLACES.chapel].map((p) => tile(p)).join('');
const guide = (lore = 3) => `${sh('Characters', '<span class="ct num">5</span>')}<div class="hrow">${castRow}</div>
${sh('Places', '<span class="ct num">6</span>')}<div class="hrow">${placesRow}</div>
${lore ? `${sh('Lore', '<span class="ct num">8</span>')}${LORE.slice(0, lore).map(lr).join('')}${gate('After Chapter 6')}` : ''}`;
const withChips = (items) => `<div class="chips" style="flex-wrap:wrap;gap:8px">${items.map(([label, img]) => `<span class="chip" style="padding-left:${img === undefined ? 15 : 14}px">${img ? `<img src="${A}${img}" alt="">` : img === null ? `<span class="dot">${ic('globe', 13, 1.8)}</span>` : ''}${label}</span>`).join('')}</div>`;
const scrolledHead = (title) => `<div class="hd"><span class="icb">${ic('left', 20, 2)}</span><span class="grow" style="font:var(--type-h3);letter-spacing:var(--tracking-tight)">${title}</span><span class="icb">${ic('more', 20)}</span></div>`;
const revealSheet = sheet('', `<div style="display:flex;flex-direction:column;align-items:center;text-align:center;gap:8px;padding:14px 20px 0"><span class="mute">${ic('eyeoff', 34, 1.8)}</span><div style="margin-top:4px;font:var(--type-h3)">After Chapter 6</div><div class="mute num" style="font:var(--type-ui)">The Ledger of Nights · you are at Chapter 3</div></div><div style="display:flex;flex-direction:column;gap:8px;padding:20px 16px 0"><span class="btn pri wide">Reveal</span><span class="btn ghost wide">Not now</span></div>`);
const characterPage = (overlay = '') => `${sb(true)}<div class="body"><div class="hero" style="padding-top:238px"><img src="${A}${CAST.maren.img}" alt="" style="height:318px;object-position:50% 16%"><div class="fade" style="top:108px;height:211px"></div><div class="top">${back}</div><div class="in"><h1>Maren Kest</h1><div class="meta">Tide-caller · The Undersong</div><div class="acts"><span class="btn" style="flex:1">${ic('volume', 18)}Voice <em class="num">· 0:08</em></span></div></div></div>
<div class="prose"><div class="lk">Essence</div><p>Tide-caller. She hears the verse under the harbour and pulls the water where it needs to go. She has paid for it: her left ear is done, and she knows the right is next.</p><div class="lk">Appearance</div><p>Salt-crusted braids, pale grey eyes, oilskin coat with a bioluminescent thread at the collar.</p></div>
<div style="height:10px"></div>${gate('After Chapter 6')}
${sh('With')}${withChips([['Bray Half-Hitch', CAST.bray.img], ['The Vigil', PLACES.vigil.img]])}
</div>${tabs('Worlds', false, true)}${overlay}${hi()}`;

const P11 = [
  frame('P11a', 'Worlds', 'phone', `${sb()}<div class="hd"><h1>Worlds</h1></div><div class="body">
${sh('In Library')}${wc({ ...W.undersong, meta: 'In Library · 1 production · 5 characters', pos: '60% 50%' })}
${sh('Available')}${wc({ ...W.copper, meta: '2 productions · 9 characters · 240 MB' })}${wc({ ...W.meridian, meta: '3 productions · 7 characters · 1.4 GB', pos: '40% 50%' })}
</div>${tabs('Worlds', false, true)}${hi()}`),

  frame('P11b', 'A world before it is installed, its guide open', 'phone', `${sb(true)}<div class="body">${installHero(installPress())}${guide(0)}</div>${tabs('Worlds', false, true)}${hi()}`),

  // Scrolled past the hero and Listen (P9f), to the guide.
  frame('P11c', 'The Undersong installed, scrolled to its guide', 'phone', `${sb()}${scrolledHead('The Undersong')}<div class="body" style="margin-top:-12px">${guide(3)}</div>${tabs('Worlds', false, true)}${hi()}`),

  frame('P11d', 'A character', 'phone', characterPage()),

  frame('P11e', 'A place', 'phone', `${sb(true)}<div class="body"><div class="hero" style="padding-top:238px"><img src="${A}${PLACES.vigil.img}" alt="" style="height:318px;object-position:70% 30%"><div class="fade" style="top:108px;height:211px"></div><div class="top">${back}</div><div class="in"><h1>The Vigil</h1><div class="meta">Place · The Undersong</div></div></div>
<div class="prose"><div class="lk">Look</div><p>A watchtower of black stone at the harbour mouth, ringed by a rail worn smooth by two hundred years of gripping hands. Lamps burn green-white.</p><div class="lk">Sound</div><p>Bells under the water on the worst nights. The rail hums a fifth below the wind.</p></div>
${sh('Here')}<div class="hrow">${[CAST.maren, CAST.bray].map((c) => pc(c, 96)).join('')}</div>
</div>${tabs('Worlds', false, true)}${hi()}`),

  frame('P11f', 'Lore', 'phone', `${sb()}<div class="hd"><span class="icb">${ic('left', 20, 2)}</span><h1>Lore</h1></div><div class="chips"><span class="chip on">All</span><span class="chip">Lore</span><span class="chip">Rules</span><span class="chip">Timeline</span></div><div class="body" style="padding-top:12px">${LORE.map(lr).join('')}${gate('After Chapter 6')}${gate('After Chapter 11')}</div>${tabs('Worlds', false, true)}${hi()}`),

  frame('P11g', 'A lore entry', 'phone', `${sb()}<div class="hd"><span class="icb">${ic('left', 20, 2)}</span><span class="grow"></span></div><div class="body"><div style="padding:6px 16px 0"><div class="lk">Lore</div><h1 style="margin-top:6px;font:var(--weight-bold) var(--text-3xl)/1.15 var(--font-sans);letter-spacing:var(--tracking-tighter)">The Undersong</h1></div>
<div class="prose" style="padding-top:14px"><p>Beneath the harbour lies a drowned god, and it is still singing. The song is slow — one verse a season — and the harbour’s luck rises and falls with the verse. Most people have never heard it. Everyone has felt it.</p></div>
${sh('With')}${withChips([['Maren Kest', CAST.maren.img], ['The Chorister', CAST.chorister.img], ['The Vigil', PLACES.vigil.img]])}
</div>${tabs('Worlds', false, true)}${hi()}`),

  frame('P11h', 'Reveal, asked once', 'phone', characterPage(`<div class="veil"></div>${revealSheet}`)),

  frame('P11i', 'A world’s guide on a Fold', 'fold', `${tabs('Worlds', true, true)}<div class="grow" style="display:flex;flex-direction:column;min-width:0;position:relative">${sb()}<div class="hd" style="padding:6px 28px 6px 24px"><span class="icb">${ic('left', 20, 2)}</span><span class="grow" style="font:var(--type-h3);letter-spacing:var(--tracking-tight)">The Undersong</span><span class="icb">${ic('more', 20)}</span></div><div class="body" style="padding:0 8px">
${sh('Characters', '<span class="ct num">5</span>')}<div class="hrow">${[CAST.maren, CAST.bray, CAST.chorister, CAST.perrin].map((c) => pc(c, 160)).join('')}${pcGated('After Chapter 9', 160)}</div>
${sh('Places', '<span class="ct num">6</span>')}<div class="hrow">${[PLACES.vigil, PLACES.saltmarket, PLACES.chapel].map((p) => tile({ ...p, w: 280 })).join('')}</div>
${sh('Lore', '<span class="ct num">8</span>')}<div class="cols2g"><div>${LORE.slice(0, 4).map(lr).join('')}</div><div>${LORE.slice(4).map(lr).join('')}${gate('After Chapter 6')}${gate('After Chapter 11')}</div></div>
</div>${hi()}</div>`),
];

// ---- P12 · a world's newer edition ---------------------------------------------------------------
// Asked: when the Studio makes a new edition of a world's package, the Player sees it and offers the
// download. The sample: The Undersong installed at its 20 October edition (182 MB), Arke's list
// naming the 22 October edition (228 MB), made by the Studio's Export → Arke Player (Studio 233).
const NEW = { date: '22 Oct 2026', size: '228 MB', more: '+46 MB of 41 GB free' };
const OLD = { date: '20 Oct 2026', size: '182 MB' };
const ledgerTile = (extra = {}) => `<div class="hrow">${tile({ ...DEMO.ledger, kind: 'Audiobook · Book · 3 h 49 m', w: 358, ...extra })}</div>`;
const updatePress = `<div style="margin-top:16px"><span class="btn pri wide">${ic('download', 18)}Update <em>· ${NEW.size}</em></span></div>`;
const updating = `<div style="margin-top:20px"><div class="bar"><i style="width:53%"></i></div><div style="display:flex;align-items:center;gap:10px;margin-top:10px"><span class="grow mute num" style="font:var(--type-ui)">Downloading · 120 MB of ${NEW.size}</span><span class="btn" style="height:40px">Cancel</span></div></div>`;
const edition = (more = NEW.more) => `<div style="height:16px"></div><div class="grp">${row('New edition', `${NEW.date} · ${NEW.size}`, '')}${row('Space', more, '')}</div>`;
const installedPage = (cta, meta, after = '', tileExtra = {}) => `${sb(true)}<div class="body">${installHero(cta, { meta, top: back + more })}${after}
${sh('Listen')}${ledgerTile(tileExtra)}</div>${tabs('Worlds', false, true)}${hi()}`;

const P12 = [
  frame('P12a', 'Worlds, with an update', 'phone', `${sb()}<div class="hd"><h1>Worlds</h1></div><div class="body">
${sh('In Library')}${wc({ ...W.undersong, meta: 'In Library · 1 production · 5 characters', pos: '60% 50%', tag: '<span class="tag glass">Update</span>' })}
${sh('Available')}${wc({ ...W.copper, meta: '2 productions · 9 characters · 240 MB' })}
</div>${tabs('Worlds', false, true)}${hi()}`),

  frame('P12b', 'A world with a newer edition', 'phone', installedPage(updatePress, `Installed · ${OLD.date} · ${OLD.size}`, edition())),

  frame('P12c', 'Updating', 'phone', installedPage(updating, `Installed · ${OLD.date} · ${OLD.size}`, edition())),

  frame('P12d', 'Updated, the place kept', 'phone', installedPage('', `Installed · ${NEW.date} · ${NEW.size}`, '', { kind: 'Audiobook · Book · 8 h 2 m', at: 31 })),

  frame('P12e', 'Downloads, while a world updates', 'phone', `${sb()}<div class="hd"><h1>Downloads</h1></div><div class="body">
<div style="padding:8px 16px 0"><div class="sbar"><i class="me" style="width:7%"></i><i class="other" style="width:58%"></i></div><div class="leg"><span><i></i>Arke Player 3.2 GB</span><span><i class="other"></i>Other 29 GB</span><span><i class="free"></i>41 GB free</span></div></div>
${sh('Worlds')}${dlRow(W.undersong.img, '60% 50%', 'The Undersong', `<span class="num">Updating · 53%</span>`, ic('pausec', 22), 53)}
${sh('Added')}${dlRow(W.meridian.img, '40% 50%', 'Meridian Dust', '<span class="num">3 productions · 1.4 GB</span>', ic('more', 18))}${dlRow('char-maren.jpg', '50% 20%', 'The Salt Almanac', '<span class="num">EPUB · 2.1 MB</span>', ic('more', 18))}
</div>${tabs('Downloads', false, true)}${hi()}`),

  frame('P12f', 'Not updated', 'phone', `${installedPage(updatePress, `Installed · ${OLD.date} · ${OLD.size}`, edition('+46 MB of 20 MB free')).replace(`${tabs('Worlds', false, true)}${hi()}`, '')}${tabs('Worlds', false, true)}<div class="veil"></div>${sheet('', `<div style="display:flex;flex-direction:column;align-items:center;text-align:center;gap:8px;padding:14px 20px 0"><span class="mute">${ic('alert', 34, 1.8)}</span><div style="margin-top:4px;font:var(--type-h3)">Needs 46 MB · 20 MB free</div><div class="mute num" style="font:var(--type-ui)">The Undersong · ${NEW.date}</div></div><div style="display:flex;flex-direction:column;gap:8px;padding:20px 16px 0"><span class="btn pri wide">Try again</span><span class="btn ghost wide">Close</span></div>`)}${hi()}`),
];

// P13 extends the existing Worlds header; the cards and navigation stay as P11/P12.
const refreshWorlds = (state = '', wide = false) => {
  const head = `<div class="hd"><h1 class="grow">Worlds</h1><span class="icb" title="Check for updates" style="background:var(--secondary);width:44px;height:44px">${state === 'Checking for updates' ? '<span style="width:22px;height:22px;border:2px solid var(--muted-foreground);border-right-color:transparent;border-radius:50%"></span>' : ic('replay', 22)}</span></div>`;
  const result = state ? `<div class="mute" style="padding:0 16px 6px;font:var(--type-ui)">${state}</div>` : '';
  const body = `<div class="body">${sh('In Library')}${wc({ ...W.undersong, meta: 'In Library · 1 production · 5 characters', pos: '60% 50%', ...(state === 'Checked' ? { tag: '<span class="tag glass">Update</span>' } : {}) })}${sh('Available')}${wc({ ...W.copper, meta: '2 productions · 9 characters · 240 MB' })}</div>`;
  return wide ? `${tabs('Worlds', true, true)}<div class="grow" style="display:flex;flex-direction:column;min-width:0">${sb()}${head}${result}${body}</div>` : `${sb()}${head}${result}${body}${tabs('Worlds', false, true)}${hi()}`;
};
const P13 = [
  frame('P13a', 'Check for updates', 'phone', refreshWorlds()),
  frame('P13b', 'Checking, the current worlds stay', 'phone', refreshWorlds('Checking for updates')),
  frame('P13c', 'Checked, a newer edition available', 'phone', refreshWorlds('Checked')),
  frame('P13d', 'Check failed, retry from the same press', 'phone', refreshWorlds('Couldn’t check for updates')),
  frame('P13e', 'Check for updates on a tablet', 'fold', refreshWorlds('Checked', true)),
  frame('P13f', 'Check for updates on desktop', 'desktop', refreshWorlds('Checked', true)),
];

// ---- P14 · a picture made for the screen ------------------------------------------------------------
// The owner, 23 October 2026: the listen screen letterboxes a wide picture into a phone's top 62%. A
// moment's picture now comes Wide and Tall, the Tall made in the Studio from the Wide, and a phone in
// portrait shows the Tall one over the whole screen. P5a's chrome, scrims and words, unchanged. The
// sample is The Undersong's p004, Maren at the ledger, made Tall from its Wide picture; its focus is at
// the right edge, so a phone trims the door on the left and keeps the lamp whole.
const tallBook = book().replace(`<img class="pic" src="${A}scene4-shot15.jpg" alt="" style="height:62%;object-position:50% 45%">`, `<img class="pic" src="${A}maren-ledger-tall.jpg" alt="" style="object-position:100% 50%">`);
const textOff = bookRow2.replace('<span class="ib lab on">', '<span class="ib lab">');

const P14 = [
  frame('P14a', 'An audiobook, a Tall picture', media(), `${tallBook}${audioBar(textOff)}${hi()}`),

  // With Text on, the foot scrim is solid to 240 px and fades by 600, so the words read on any picture.
  frame('P14b', 'An audiobook, a Tall picture, Text on', media(), `${tallBook.replace('<div class="sbot" style="height:520px"></div>', '<div class="sbot" style="height:600px;background:linear-gradient(to top,color-mix(in srgb,var(--media-overlay-bg) 92%,transparent) 40%,transparent)"></div>')}<div class="words" style="bottom:286px">Odile did not answer. She held the lamp lower.</div>${audioBar(bookRow2)}${hi()}`),
];

// ---- P15 · Discover, a world's kinds, and chapters released over time -------------------------------
// The owner, 24 October 2026: should Worlds become Discover, showing worlds, their productions and
// other things made for them; and how does a world released a chapter at a time bring its audience
// back. Drawn on the calls approved that day. Legend of Dumah, The Red Quiet and Embers of the Fallen
// are Arke's own worlds on Available, their pictures from the app's list; The Undersong's six
// productions are the sample of P1. Chapter dates, the schedules and the episode counts are samples.
const NEWTAG = '<span class="tag new">New</span>';
const DUMAH = { img: 'dumah-key-art.jpg', pos: '24% 62%', name: 'Legend of Dumah', logline: 'Twice the world has stood at the edge of ending. The third time begins with a thief in the City of Light.' };
const QUIET = { img: 'red-quiet-key-art.jpg', pos: '50% 40%', name: 'The Red Quiet' };
const EMBERS = { img: 'embers-key-art.jpg', pos: '62% 40%', name: 'Embers of the Fallen' };
const STORY = {
  whispers: { img: 'dumah-whispers.jpg', pos: '50% 50%', title: 'Whispers from the Void' },
  ledger: { img: 'ledger-of-nights.jpg', pos: '50% 40%', title: 'The Ledger of Nights' },
  quiet: { img: 'red-quiet-cover.jpg', pos: '70% 50%', title: 'The Red Quiet' },
  threshold: { img: 'embers-cover.jpg', pos: '30% 40%', title: 'Threshold — Book One' },
};
const discoverChips = (style = '') => `<div class="chips"${style ? ` style="${style}"` : ''}><span class="chip on">All</span><span class="chip">Listen</span><span class="chip">Watch</span><span class="chip">Play</span><span class="chip">Read</span></div>`;
const discoverHead = (style = '') => `<div class="hd"${style ? ` style="${style}"` : ''}><h1 class="grow">Discover</h1><span class="icb" title="Check for updates">${ic('replay', 20)}</span></div>`;
// One tile in every row, 16:9 and as wide as a world's card in a row (wc.mini), so a page's rows line
// up whatever they hold: a chapter, a film, a micro drama, a character. The owner, 24 October 2026:
// rows of different sizes and shapes look unkempt. A Fold's rows take its world cards' 300.
const TW = 240;
const charTile = (c, kind = c.role, w = TW) => c.img ? tile({ img: c.img, pos: c.pos, title: c.name, kind, w }) : `<div class="tile" style="width:${w}px"><div class="im"><span class="mid ini">${c.ini}</span></div><div class="t">${c.name}</div><div class="m">${kind}</div></div>`;
const gatedTile = (after, w = TW) => `<div class="tile gated" style="width:${w}px"><div class="im"><span class="mid">${ic('eyeoff', 26, 1.7)}</span></div><div class="t mute">${after}</div><div class="m">Character</div></div>`;
const newChapters = (w = TW) => `${tile({ ...STORY.whispers, kind: 'Chapter 3 · Legend of Dumah', w, tag: NEWTAG })}${tile({ ...PR.bell, kind: 'Episodes 41–45 · The Undersong', w, tag: NEWTAG })}${tile({ ...STORY.threshold, kind: 'Chapter 6 · Embers of the Fallen', w })}`;
const stories = (w = TW) => `${tile({ ...STORY.ledger, kind: 'Audiobook · The Undersong', w })}${tile({ ...STORY.quiet, kind: 'Audiobook · The Red Quiet', w })}${tile({ ...PR.saltlight, kind: 'Film · The Undersong', w })}${tile({ ...PR.low, kind: 'Interactive movie · The Undersong', w })}`;
const teasers = (w = TW) => `${charTile(CAST.maren, 'Character · The Undersong', w)}${tile({ img: 'scene4-shot14b.jpg', pos: '50% 50%', title: 'Saltmouth bells', kind: 'Clip · 0:24 · The Undersong', w, mid: `<span class="ib glass">${ic('play', 18)}</span>` })}${tile({ ...PLACES.vigil, kind: 'Place · The Undersong', w })}`;
const castTiles = `${[CAST.maren, CAST.bray, CAST.perrin].map((c) => charTile(c)).join('')}${gatedTile('After Chapter 9')}`;
// A world's page groups its productions by how they are taken, each in the one tile.
const kindsHero = `<div class="hero" style="padding-top:200px"><img src="${A}${W.undersong.img}" alt="" style="height:272px;object-position:60% 50%"><div class="fade" style="top:72px;height:201px"></div><div class="top">${back}${more}</div><div class="in"><h1>${W.undersong.name}</h1><div class="meta num">6 productions · 1.9 GB</div><div class="lg">${W.undersong.logline}</div><div style="margin-top:16px"><span class="btn pri wide">${ic('download', 18)}Install <em>· 1.9 GB</em></span></div></div></div>`;
const listenRow = `${sh('Listen', '<span class="ct num">2</span>')}<div class="hrow">${tile({ ...STORY.ledger, kind: 'Audiobook · Book · 23 chapters', w: TW })}${tile({ ...PR.undertow, kind: 'Audio drama · 8 episodes', w: TW })}</div>`;
const watchRow = `${sh('Watch', '<span class="ct num">2</span>')}<div class="hrow">${tile({ ...PR.bell, kind: 'Micro drama · 45 episodes', w: TW, tag: NEWTAG })}${tile({ ...PR.saltlight, kind: 'Film · 1 h 32 m', w: TW })}</div>`;
const playRow = `${sh('Play', '<span class="ct num">2</span>')}<div class="hrow">${tile({ ...PR.low, kind: 'Interactive movie · 14 scenes', w: TW })}${tile({ ...PR.lantern, kind: 'Visual novel · 9 scenes', w: TW })}</div>`;
// A chapter as a row of data: its name, its length and the day it came out, and where you are in it.
const chr = (name, data, end, { fresh = false, soon = false } = {}) => `<div class="chr${soon ? ' soon' : ''}"><div class="grow"><div class="t">${name}</div><div class="m">${fresh ? NEWTAG : ''}<span class="num">${data}</span></div></div><span class="end">${end}</span></div>`;
const heard = ic('downloaded', 22, 1.7);
const sched = (text) => `<div class="sched num">${ic('calendar', 15)}${text}</div>`;
const dumahInstalled = `${sb(true)}<div class="body"><div class="hero" style="padding-top:218px"><img src="${A}${DUMAH.img}" alt="" style="height:290px;object-position:${DUMAH.pos}"><div class="fade" style="top:90px;height:201px"></div><div class="top">${back}${more}</div><div class="in"><h1>${DUMAH.name}</h1><div class="meta num">Installed · 1 production · 106 MB</div><div class="lg">${DUMAH.logline}</div></div></div>
${sh('Listen')}<div class="hrow">${tile({ ...STORY.whispers, kind: 'Audiobook · 4 chapters', w: 358, tag: NEWTAG })}</div></div>${tabs('Library', false, 'discover')}`;
const lock = `<img class="pic" src="${A}${DUMAH.img}" alt="" style="object-position:30% 50%"><div class="st" style="height:260px"></div><div class="sbot" style="height:360px"></div>${sb(true)}
<div style="position:absolute;left:0;right:0;top:92px;text-align:center"><div class="lkd">Saturday 24 October</div><div class="lkt num">9:41</div></div>`;

const P15 = [
  frame('P15a', 'Discover', 'phone', `${sb()}${discoverHead()}${discoverChips()}<div class="body">
${sh('New chapters')}<div class="hrow">${newChapters()}</div>
${sh('Stories')}<div class="hrow">${stories()}</div>
${sh('Teasers')}<div class="hrow">${teasers()}</div>
</div>${tabs('Discover', false, 'discover')}${hi()}`),

  frame('P15b', 'Discover, further down: teasers and worlds', 'phone', `${sb()}${discoverHead()}${discoverChips()}<div class="body">
${sh('Teasers')}<div class="hrow">${teasers()}</div>
${sh('Worlds')}${wc({ ...DUMAH, meta: 'In Library · 1 production · 4 chapters' })}${wc({ ...QUIET, meta: '1 production · 4 characters · 23 MB' })}${wc({ ...EMBERS, meta: '1 production · 6 characters · 127 MB' })}
</div>${tabs('Discover', false, 'discover')}${hi()}`),

  frame('P15c', 'A world with several kinds of production', 'phone', `${sb(true)}<div class="body">${kindsHero}${listenRow}${watchRow}</div>${tabs('Discover', false, 'discover')}${hi()}`),

  frame('P15d', 'The same world, further down: Watch and Play', 'phone', `${sb()}${scrolledHead('The Undersong')}<div class="body" style="margin-top:-12px">${watchRow}${playRow}${sh('Characters', '<span class="ct num">5</span>')}<div class="hrow">${castTiles}</div></div>${tabs('Discover', false, 'discover')}${hi()}`),

  frame('P15e', 'An audiobook released a chapter at a time', 'phone', `${sb(true)}<div class="body"><div class="hero" style="padding-top:218px"><img src="${A}${STORY.whispers.img}" alt="" style="height:290px;object-position:${STORY.whispers.pos}"><div class="fade" style="top:90px;height:201px"></div><div class="top">${back}${more}</div><div class="in"><h1>${STORY.whispers.title}</h1><div class="meta num">Audiobook · Legend of Dumah · 4 chapters · 1 h 18 m</div>${sched('Fridays')}
<div style="margin-top:16px"><span class="btn pri wide">${ic('play', 16)}Play <em>· Chapter 3</em></span></div></div></div>
${sh('Chapters', '<span class="ct num">4</span>')}
${chr('Prologue', '12 min · 9 Oct', heard)}${chr('Chapter 1', '22 min · 9 Oct', heard)}${chr('Chapter 2', '26 min · 16 Oct', heard)}${chr('Chapter 3', '18 min · 23 Oct', '<span class="ring"></span>', { fresh: true })}${chr('Chapter 4', '30 Oct', ic('calendar', 20, 1.7), { soon: true })}
</div>${tabs('Library', false, 'discover')}${hi()}`),

  frame('P15f', 'A micro drama released in episodes', 'phone', `${sb(true)}<div class="body"><div class="hero" style="padding-top:218px"><img src="${A}${PR.bell.img}" alt="" style="height:290px;object-position:50% 26%"><div class="fade" style="top:90px;height:201px"></div><div class="top">${back}${more}</div><div class="in"><h1>${PR.bell.title}</h1><div class="meta num">Micro drama · The Undersong · 45 episodes</div>${sched('Mondays · Next 26 Oct')}
<div style="margin-top:16px"><span class="btn pri wide">${ic('play', 16)}Play <em>· Episode 41</em></span></div></div></div>
${sh('Episodes', '<span class="ct num">45</span>')}<div class="grid4">${['char-maren.jpg', 'scene4-shot12.jpg', 'scene4-shot14b.jpg', 'char-ilo.jpg', 'scene4-shot15.jpg', 'char-bray.jpg', 'scene4-shot13.jpg', 'char-chorister.jpg'].map((img, i) => `<div class="vt"><img src="${A}${img}" alt="" style="object-position:50% 30%">${i >= 3 ? `<span class="tg">${NEWTAG}</span>` : ''}<span class="n">${38 + i}</span>${i < 3 ? '<div class="pl"><i style="width:100%"></i></div>' : ''}</div>`).join('')}</div>
</div>${tabs('Library', false, 'discover')}${hi()}`),

  frame('P15g', 'Home, a new chapter to continue', 'phone', `${sb()}<div class="hd"><h1>Home</h1></div><div class="body">
${sh('Continue')}<div class="hrow">${cc({ ...STORY.whispers, kind: 'Audiobook', where: `${NEWTAG}Chapter 3 · 18 min`, at: 0 })}${cc({ ...STORY.ledger, kind: 'Audiobook', where: 'Chapter 12 · 21 min left', at: 44 })}</div>
${sh('New chapters')}<div class="hrow">${tile({ ...PR.bell, kind: 'Episodes 41–45 · The Undersong', w: TW, tag: NEWTAG })}${tile({ ...STORY.ledger, kind: 'Chapter 24 · The Undersong', w: TW, tag: NEWTAG })}</div>
${sh('Discover')}<div class="hrow">${wc({ ...QUIET, meta: '1 production · 23 MB', cls: 'mini' })}${wc({ ...EMBERS, meta: '1 production · 127 MB', cls: 'mini' })}</div>
</div>${tabs('Home', false, 'discover')}${hi()}`),

  frame('P15h', 'Library, what is on the phone', 'phone', `${sb()}<div class="hd"><h1 class="grow">Library</h1><span class="icb">${ic('plus', 20, 2)}</span></div>${discoverChips()}<div class="body">
${sh('Worlds')}${wc({ ...DUMAH, meta: 'Installed · 1 production · 106 MB', tag: NEWTAG })}${wc({ ...W.undersong, meta: 'Installed · 6 productions · 1.9 GB', pos: '60% 50%', tag: '<span class="tag glass">Update</span>' })}
${sh('Added')}${[MINE.almanac, MINE.tide].map((f) => frow(f, ic('more', 18))).join('')}
</div>${tabs('Library', false, 'discover')}${hi()}`),

  frame('P15i', 'A new chapter, on the lock screen', media(), `${lock}<div class="nt" style="position:absolute;left:12px;right:12px;top:262px"><span class="app">A</span><div class="grow"><div class="nth"><span>Arke Player</span><span>now</span></div><div class="t">${DUMAH.name}</div><div class="m">Chapter 3 · ${STORY.whispers.title}</div></div><img src="${A}${STORY.whispers.img}" alt=""></div>${hi()}`),

  frame('P15j', 'Notify, per world', 'phone', `${dumahInstalled}<div class="veil"></div>${sheet(DUMAH.name, `<div class="lk" style="padding:6px 16px 8px">Notify</div><div class="grp">${row('New chapters', '', 'on')}</div><div style="height:16px"></div><div class="grp">${row('Edition', '23 Oct 2026', '')}${row('Space', '106 MB', '')}</div>`)}${hi()}`),

  frame('P15k', 'Downloads, a chapter arriving', 'phone', `${sb()}<div class="hd"><h1>Downloads</h1></div><div class="body">
<div style="padding:8px 16px 0"><div class="sbar"><i class="me" style="width:8%"></i><i class="other" style="width:58%"></i></div><div class="leg"><span><i></i>Arke Player 3.4 GB</span><span><i class="other"></i>Other 29 GB</span><span><i class="free"></i>40 GB free</span></div></div>
${sh('Worlds')}${dlRow(STORY.whispers.img, STORY.whispers.pos, DUMAH.name, '<span class="num">Chapter 3 · 9 of 18 MB</span>', ic('pausec', 22), 50)}${dlRow(PR.bell.img, '50% 28%', 'The Undersong', '<span class="num">Episodes 41–45 · 64 MB · Waiting</span>', ic('more', 18))}
${sh('Added')}${dlRow(W.meridian.img, '40% 50%', 'Meridian Dust', '<span class="num">3 productions · 1.4 GB</span>', ic('more', 18))}
</div>${tabs('Downloads', false, 'discover')}${hi()}`),

  frame('P15l', 'Discover on a Fold', 'fold', `${tabs('Discover', true, 'discover')}<div class="grow" style="display:flex;flex-direction:column;min-width:0;position:relative">${sb()}${discoverHead('padding:6px 28px 6px 24px')}${discoverChips('padding:2px 24px 0')}<div class="body" style="padding:0 8px">
${sh('New chapters')}<div class="hrow">${newChapters(300)}</div>
${sh('Stories')}<div class="hrow">${stories(300)}</div>
${sh('Teasers')}<div class="hrow">${teasers(300)}</div>
${sh('Worlds')}<div class="hrow">${[DUMAH, QUIET, EMBERS].map((w) => wc({ ...w, meta: w === DUMAH ? 'In Library' : '1 production', cls: 'mini', style: 'width:300px;height:169px' })).join('')}</div>
</div>${hi()}</div>`),
];

// ---- P16 · Rows of different sizes ------------------------------------------------------------
// The owner, 24 October 2026, with Netflix's Home on a phone and a tablet: boxes of different sizes
// give some titles emphasis. Netflix keeps every row one size and varies the size between rows; what
// looked unkempt in P15's first draw was sizes mixed inside one row. So a row is one size and one
// shape, and a page is a rhythm of rows: the feature, posters, wide tiles, small posters, a band.
// A poster is the production's Tall cover. Arke's covers are wide today, so one without a Tall shows
// its Wide whole over its own blur. Na Love or Juju's book cover is the middle of its published cover.
const JUJU = { img: 'juju-key-art.jpg', pos: '30% 40%', name: 'Na Love or Juju', logline: 'A disciplined Lagos man in his forties falls for a woman who loves him in private and denies him in public, and by the time he learns her hold on him is more than charm, he can no longer tell which of his feelings were ever his own.' };
const TALL = { ledger: 'maren-ledger-tall.jpg', juju: 'juju-cover-tall.jpg', quiet: 'red-quiet-key-art.jpg', bell: 'char-sereth.jpg' };
/** A poster: 2:3 from a Tall picture; without one, the Wide whole over its own blur. */
const poster = ({ tall, img, pos = 'center', title, kind, w = 172, tag = '', mid = '' }) => `<div class="po" style="width:${w}px"><div class="im${tall ? '' : ' fb'}">${tall ? `<img src="${A}${tall}" alt="" style="object-position:${pos}">` : `<img class="bl" src="${A}${img}" alt=""><img class="wd" src="${A}${img}" alt="" style="object-position:${pos}">`}${tag ? `<span class="tg">${tag}</span>` : ''}${mid ? `<span class="mid">${mid}</span>` : ''}</div><div class="t">${title}</div><div class="m">${kind}</div></div>`;
const castPoster = (c, kind, w) => c.img ? poster({ tall: c.img, pos: c.pos, title: c.name, kind, w }) : `<div class="po" style="width:${w}px"><div class="im"><span class="mid ini">${c.ini}</span></div><div class="t">${c.name}</div><div class="m">${kind}</div></div>`;
const gatedPoster = (after, w) => `<div class="po gated" style="width:${w}px"><div class="im"><span class="mid">${ic('eyeoff', 24, 1.7)}</span></div><div class="t mute">${after}</div><div class="m">Character</div></div>`;
/** The feature: one production, its Tall cover upright on a phone, its Wide on a Fold. */
const feature = (wide = false) => `<div class="ft on-media${wide ? ' wide' : ''}"><img src="${A}${wide ? STORY.ledger.img : TALL.ledger}" alt="" style="object-position:${wide ? '50% 40%' : '50% 30%'}"><div class="shade"></div><div class="in"><div class="fk">${NEWTAG}<span class="num">Chapter 24</span></div><h1>${STORY.ledger.title}</h1><div class="meta">Audiobook · Book · The Undersong</div><span class="btn pri${wide ? '' : ' wide'}">${ic('download', 18)}Install <em>· 1.9 GB</em></span></div></div>`;
const storyPosters = (w = 172) => `${poster({ tall: TALL.quiet, pos: '50% 40%', title: 'The Red Quiet', kind: 'Audiobook · The Red Quiet', w })}${poster({ img: STORY.whispers.img, title: STORY.whispers.title, kind: 'Audiobook · Legend of Dumah', w })}${poster({ tall: TALL.bell, pos: '50% 28%', title: PR.bell.title, kind: 'Micro drama · The Undersong', w, tag: NEWTAG })}${poster({ img: PR.saltlight.img, pos: PR.saltlight.pos, title: PR.saltlight.title, kind: 'Film · The Undersong', w })}`;
const teaserPosters = (w = 112) => `${castPoster(CAST.maren, 'Character', w)}${poster({ img: 'scene4-shot14b.jpg', title: 'Saltmouth bells', kind: 'Clip · 0:24', w, mid: `<span class="ib glass">${ic('play', 16)}</span>` })}${castPoster(CAST.chorister, 'Character', w)}${poster({ img: PLACES.vigil.img, title: PLACES.vigil.title, kind: 'Place', w })}`;
/** The band: one world across the page, its key art blurred behind, its productions and people as small posters. */
const band = (w = 112, style = '') => `<div class="band on-media"${style ? ` style="${style}"` : ''}><img class="bg" src="${A}${JUJU.img}" alt=""><div class="dk"></div><div class="bh"><img src="${A}${JUJU.img}" alt="" style="object-position:${JUJU.pos}"><div class="grow"><h3>${JUJU.name}</h3><div class="m num">1 production · 808 MB</div></div><span class="bi"><span>${ic('download', 20, 2)}</span>Install</span></div><div class="lg">${JUJU.logline}</div><div class="hrow">${poster({ tall: TALL.juju, title: 'Na love or Juju', kind: 'Audiobook · 11 h 55 m', w })}${[['juju-ife.jpg', 'Ife'], ['juju-ade.jpg', 'Ade Akinola'], ['juju-tunde.jpg', 'Tunde']].map(([img, name]) => poster({ tall: img, pos: '50% 22%', title: name, kind: 'Character', w })).join('')}</div></div>`;
const foldBody = (inner) => `${tabs('Discover', true, 'discover')}<div class="grow" style="display:flex;flex-direction:column;min-width:0;position:relative">${sb()}${discoverHead('padding:6px 28px 6px 24px')}${discoverChips('padding:2px 24px 0')}<div class="body" style="padding:0 8px">${inner}</div>${hi()}</div>`;

const P16 = [
  frame('P16a', 'Discover opens on a feature', 'phone', `${sb()}${discoverHead()}${discoverChips()}<div class="body">${feature()}
${sh('New chapters')}<div class="hrow">${newChapters()}</div>
</div>${tabs('Discover', false, 'discover')}${hi()}`),

  frame('P16b', 'Further down: wide tiles, then posters', 'phone', `${sb()}${discoverHead()}${discoverChips()}<div class="body">
${sh('New chapters')}<div class="hrow">${newChapters()}</div>
${sh('Stories')}<div class="hrow">${storyPosters()}</div>
</div>${tabs('Discover', false, 'discover')}${hi()}`),

  frame('P16c', 'Further down: small posters, then a world’s band', 'phone', `${sb()}${discoverHead()}${discoverChips()}<div class="body">
${sh('Teasers')}<div class="hrow">${teaserPosters()}</div>
${band()}
</div>${tabs('Discover', false, 'discover')}${hi()}`),

  frame('P16d', 'A world’s page: Listen as posters', 'phone', `${sb(true)}<div class="body">${kindsHero}${sh('Listen', '<span class="ct num">2</span>')}<div class="hrow">${poster({ tall: TALL.ledger, pos: '50% 30%', title: STORY.ledger.title, kind: 'Audiobook · Book · 23 chapters' })}${poster({ img: PR.undertow.img, title: PR.undertow.title, kind: 'Audio drama · 8 episodes' })}</div></div>${tabs('Discover', false, 'discover')}${hi()}`),

  frame('P16e', 'The same world, further down: wide tiles, then its people', 'phone', `${sb()}${scrolledHead('The Undersong')}<div class="body" style="margin-top:-12px">${watchRow}${sh('Characters', '<span class="ct num">5</span>')}<div class="hrow">${[CAST.maren, CAST.bray, CAST.chorister, CAST.perrin].map((c) => castPoster(c, c.role, 112)).join('')}${gatedPoster('After Chapter 9', 112)}</div>
${sh('Places', '<span class="ct num">6</span>')}<div class="hrow">${[PLACES.vigil, PLACES.saltmarket, PLACES.chapel].map((p) => tile({ ...p, w: TW })).join('')}</div></div>${tabs('Discover', false, 'discover')}${hi()}`),

  frame('P16f', 'Discover on a Fold: the feature wide, then posters', 'fold', foldBody(`${feature(true)}
${sh('Stories')}<div class="hrow">${storyPosters(260)}</div>`)),

  frame('P16g', 'Discover on a Fold, further down', 'fold', foldBody(`${sh('New chapters')}<div class="hrow">${newChapters(300)}</div>
${sh('Teasers')}<div class="hrow">${teaserPosters(160)}${castPoster(CAST.bray, 'Character', 160)}</div>
${band(160, 'margin:28px -8px 0;padding:24px 8px')}`)),

  // Call 16, asked to be seen: the tabs as Netflix's floating pill. The page runs to the foot under
  // it; a playing chapter's dock floats above it; on a Fold the rail goes and the page takes the width.
  frame('P16h', 'The tabs as a pill', 'phone', `${sb()}${discoverHead()}${discoverChips()}<div class="body">${feature()}
${sh('New chapters')}<div class="hrow">${newChapters()}</div>
</div><div class="ffoot"></div>${pill('Discover')}${hi()}`),

  frame('P16i', 'The pill with a chapter playing', 'phone', `${sb(true)}<div class="body">${kindsHero}${sh('Listen', '<span class="ct num">2</span>')}<div class="hrow">${poster({ tall: TALL.ledger, pos: '50% 30%', title: STORY.ledger.title, kind: 'Audiobook · Book · 23 chapters' })}${poster({ img: PR.undertow.img, title: PR.undertow.title, kind: 'Audio drama · 8 episodes' })}</div></div><div class="ffoot"></div>${dock({ img: STORY.whispers.img, title: STORY.whispers.title, where: 'Chapter 3 · 4:12', at: 24 }).replace('class="dock"', 'class="dock float"')}${pill('Discover')}${hi()}`),

  frame('P16j', 'The pill on a Fold, in the rail’s place', 'fold', `<div class="grow" style="display:flex;flex-direction:column;min-width:0;position:relative">${sb()}${discoverHead('padding:6px 28px 6px 24px')}${discoverChips('padding:2px 24px 0')}<div class="body" style="padding:0 8px">${feature(true)}
${sh('Stories')}<div class="hrow">${storyPosters(260)}</div></div><div class="ffoot"></div>${pill('Discover', true)}${hi()}</div>`),
];

// ---- P17 · Music ------------------------------------------------------------------------------
// The owner, 24 October 2026: if music is supported as a production, or just an artifact, how is it
// shown within a world? Drawn on the recommendations approved that day: music is a production
// (Album, Single, Soundtrack), its own group with square tiles, played by the audio player with a
// track list, tied to where it is heard and whose theme it is, and a Song teaser. Studio 238 draws
// the author's half. The tracks, lengths and lyrics are samples; the covers are pictures already here.
// The covers and lyrics are Studio 238's, so the author's page and the listener's show the same album.
const ALBUM = { img: 'scene4-shot15.jpg', pos: '50% 50%', title: 'Songs of the Drowned Quarter' };
const SINGLE = { img: 'launch-harbour.jpg', pos: '50% 62%', title: 'Saltmouth Bells' };
const SCORE = { img: 'scene4-shot14b.jpg', pos: '50% 50%', title: 'The Bell Watch — Soundtrack' };
const TRACKS = [
  ['The Drowned Verse', '4:12', 'Theme · The Chorister'],
  ['Slack Water', '3:05', ''],
  ['Saltmouth Bells', '3:42', 'Heard in · The Ledger of Nights, Chapter 8'],
  ['Tide-caller', '3:58', 'Theme · Maren Kest'],
  ['The Vigil', '4:40', ''],
  ['Lantern Road', '3:20', ''],
  ['Ledger Hymn', '2:55', ''],
  ['Low Water', '3:33', ''],
  ['Undersong', '5:01', ''],
];
/** A square tile: a music production, 1:1 as album art is everywhere (P17 rule 3). */
const square = ({ img, pos = 'center', title, kind, w = 160 }) => `<div class="mt" style="width:${w}px"><div class="im"><img src="${A}${img}" alt="" style="object-position:${pos}"></div><div class="t">${title}</div><div class="m">${kind}</div></div>`;
const musicRow = (w = 160, onWorld = false) => `${square({ ...ALBUM, kind: onWorld ? 'Album · 9 tracks' : 'Album · The Undersong', w })}${square({ ...SINGLE, kind: onWorld ? 'Single · 3:42' : 'Single · The Undersong', w })}${square({ ...SCORE, kind: onWorld ? 'Soundtrack · 14 tracks' : 'Soundtrack · The Bell Watch', w })}`;
/** A track: its number, or bars while it plays; its title and one line, the theme or where it is heard; its length. */
const trk = ([title, length, sub], index, now = -1) => `<div class="trk${index === now ? ' now' : ''}"><span class="no">${index === now ? ic('bars', 16, 2) : index + 1}</span><div class="grow"><div class="t">${title}</div>${sub ? `<div class="m">${sub}</div>` : ''}</div><span class="d num">${length}</span><span class="x">${ic('more', 18)}</span></div>`;
const songTeaser = (w = 112) => `<div class="po" style="width:${w}px"><div class="im fb"><img class="bl" src="${A}${ALBUM.img}" alt=""><img class="wd sq1" src="${A}${ALBUM.img}" alt="" style="object-position:${ALBUM.pos}"><span class="mid"><span class="ib glass">${ic('music', 16)}</span></span></div><div class="t">The Drowned Verse</div><div class="m">Song · 0:24</div></div>`;
// A song's dock skips to the next track where a chapter's goes back 15 seconds.
const floatDock = (where = 'Songs of the Drowned Quarter', at = 43) => dock({ img: ALBUM.img, title: 'The Drowned Verse', where, at }).replace('class="dock"', 'class="dock float"').replace(seek(15), ic('next', 20));
const albumHead = `<img class="bg" src="${A}${ALBUM.img}" alt=""><div class="top">${back}${more}</div><img class="cv" src="${A}${ALBUM.img}" alt="" style="object-position:${ALBUM.pos}">`;
const albumActs = `<div class="acts"><span class="btn pri" style="flex:1">${ic('play', 16)}Play all</span><span class="btn" style="flex:1">${ic('shuffle', 18)}Shuffle</span></div>`;
// The audio player with the cover where the moment's picture would be, over its own blur.
const nowPlaying = (inner) => `<img class="np" src="${A}${ALBUM.img}" alt=""><div class="dim" style="background:color-mix(in srgb,var(--media-overlay-bg) 30%,transparent)"></div>${sb(true)}
<div class="ptop">${close}<div class="ttl"><div class="eb">${ALBUM.title}</div><div class="sc num">1 of 9</div></div><span class="ib">${ic('more', 20)}</span></div>${inner}`;
const musicBar = (lyricsOn = false) => `<div style="position:absolute;z-index:4;left:20px;right:20px;bottom:40px"><div class="scrub"><i style="width:43%"></i><b style="left:43%"></b></div><div class="times"><span>1:48</span><span>4:12</span></div>
<div class="trow" style="margin-top:14px"><span class="ib">${ic('shuffle', 20)}</span><span class="ib">${ic('prev', 22)}</span><span class="play">${ic('pause', 24)}</span><span class="ib">${ic('next', 22)}</span><span class="ib">${ic('repeat', 20)}</span></div>
<div class="trow" style="margin-top:14px;justify-content:center;gap:10px"><span class="ib lab${lyricsOn ? ' on' : ''}">${ic('text', 16)}Lyrics</span><span class="ib lab">${ic('list', 16)}Tracks</span><span class="ib lab">${ic('book', 16)}Chapter 9</span></div></div>`;
// As written in the Studio, a verse and a chorus; the structure tags the singing model reads are not shown.
const LYRICS = [
  'Under the harbour the old bells turn,<br>salt in the ledger, the lamps that burn.<br>Count me the tides that the city forgot,<br>sing me the name that the water has not.',
  'Hold the verse, hold it low,<br>down where the drowned ones go.',
];

const P17 = [
  frame('P17a', 'A world with music', 'phone', `${sb()}${scrolledHead('The Undersong')}<div class="body" style="margin-top:-12px">
${sh('Listen', '<span class="ct num">2</span>')}<div class="hrow">${poster({ tall: TALL.ledger, pos: '50% 30%', title: STORY.ledger.title, kind: 'Audiobook · Book · 23 chapters' })}${poster({ img: PR.undertow.img, title: PR.undertow.title, kind: 'Audio drama · 8 episodes' })}</div>
${sh('Music', '<span class="ct num">3</span>')}<div class="hrow">${musicRow(160, true)}</div>
${sh('Watch', '<span class="ct num">2</span>')}<div class="hrow">${tile({ ...PR.bell, kind: 'Micro drama · 45 episodes', w: TW })}${tile({ ...PR.saltlight, kind: 'Film · 1 h 32 m', w: TW })}</div>
</div><div class="ffoot"></div>${pill('Discover')}${hi()}`),

  frame('P17b', 'Discover: a row of music, and a song as a teaser', 'phone', `${sb()}${discoverHead()}${discoverChips()}<div class="body"><div style="margin-top:-176px">
${sh('Stories')}<div class="hrow">${storyPosters()}</div>
${sh('Music')}<div class="hrow">${musicRow()}</div>
${sh('Teasers')}<div class="hrow">${songTeaser()}${teaserPosters()}</div>
</div></div><div class="ffoot"></div>${pill('Discover')}${hi()}`),

  frame('P17c', 'An album, a track playing', 'phone', `${sb(true)}<div class="body"><div class="alb">${albumHead}<h1>${ALBUM.title}</h1><div class="meta num">Album · The Undersong · 9 tracks · 34 min</div>${albumActs}</div>
${TRACKS.map((track, index) => trk(track, index, 0)).join('')}</div><div class="ffoot"></div>${floatDock()}${pill('Discover')}${hi()}`),

  frame('P17d', 'A song playing', media(), nowPlaying(`<div class="npc"><img src="${A}${ALBUM.img}" alt="" style="object-position:${ALBUM.pos}"></div><div class="npt"><div class="t">The Drowned Verse</div><div class="m">Theme · The Chorister</div></div>${musicBar()}${hi()}`)),

  frame('P17e', 'Its lyrics, as written', media(), nowPlaying(`<div class="lyr">${LYRICS.map((line) => `<p>${line}</p>`).join('')}</div><div class="npt" style="top:auto;bottom:208px"><div class="t" style="font-size:var(--text-lg)">The Drowned Verse</div><div class="m">Theme · The Chorister</div></div>${musicBar(true)}${hi()}`)),

  frame('P17f', 'A character’s theme', 'phone', `${sb(true)}<div class="body"><div class="hero" style="padding-top:238px"><img src="${A}${CAST.chorister.img}" alt="" style="height:318px;object-position:50% 20%"><div class="fade" style="top:108px;height:211px"></div><div class="top">${back}</div><div class="in"><h1>The Chorister</h1><div class="meta">Keeper of the drowned verse · The Undersong</div><div class="acts"><span class="btn" style="flex:1">${ic('volume', 18)}Voice <em class="num">· 0:08</em></span></div></div></div>
${sh('Theme')}<div class="trk"><img src="${A}${ALBUM.img}" alt="" style="object-position:${ALBUM.pos}"><div class="grow"><div class="t">The Drowned Verse</div><div class="m num">${ALBUM.title} · 4:12</div></div><span class="pb">${ic('play', 16)}</span></div>
<div class="prose"><div class="lk">Essence</div><p>The voice the harbour keeps. Nobody has seen the Chorister’s face: the verse comes up through the water at slack tide, and every tide-caller learns it by ear.</p></div>
</div><div class="ffoot"></div>${pill('Discover')}${hi()}`),

  frame('P17g', 'A story’s music', 'phone', `${sb()}${scrolledHead(STORY.ledger.title)}<div class="body" style="margin-top:-12px">
${sh('Chapters', '<span class="ct num">23</span>')}${chr('Chapter 7', '32 min', heard)}${chr('Chapter 8', `38 min <span class="note">${ic('music', 13)}</span>`, heard)}${chr('Chapter 9', `44 min <span class="note">${ic('music', 13)}</span>`, '<span class="ring"></span>')}${chr('Chapter 10', '36 min', '')}
${sh('Music', '<span class="ct num">2</span>')}<div class="trk"><img src="${A}${ALBUM.img}" alt="" style="object-position:${ALBUM.pos}"><div class="grow"><div class="t">The Drowned Verse</div><div class="m">Chapter 9 · ${ALBUM.title}</div></div><span class="pb">${ic('play', 16)}</span></div><div class="trk"><img src="${A}${SINGLE.img}" alt="" style="object-position:${SINGLE.pos}"><div class="grow"><div class="t">Saltmouth Bells</div><div class="m">Chapter 8 · Single</div></div><span class="pb">${ic('play', 16)}</span></div>
</div><div class="ffoot"></div>${pill('Discover')}${hi()}`),

  frame('P17h', 'An album on a Fold', 'fold', `<div class="grow" style="display:flex;flex-direction:column;min-width:0;position:relative">${sb(true)}<div class="body"><div class="alb fold">${albumHead}<div><h1 style="margin-top:0">${ALBUM.title}</h1><div class="meta num">Album · The Undersong · 9 tracks · 34 min</div><div style="max-width:360px">${albumActs}</div></div></div>
<div class="trks" style="padding:12px 8px 0">${TRACKS.map((track, index) => trk(track, index)).join('')}</div>
${sh('More from The Undersong')}<div class="hrow">${square({ ...SINGLE, kind: 'Single · 3:42', w: 200 })}${square({ ...SCORE, kind: 'Soundtrack · 14 tracks', w: 200 })}</div></div><div class="ffoot"></div>${pill('Discover', true)}${hi()}</div>`),
];

// ---- P18 · Interactive stories, brought up to date --------------------------------------------
// The owner, 28 October 2026: have we designed what interactive stories look like on the Player?
// P4 had, on 20 October, before the pill, the rows, picture shapes and remembered choices, and it
// cropped a 16:9 movie to fill an upright phone where P3a letterboxes a film. P18 plays a story at
// the shape it was made in and shows a choice the story has closed (SPEC-063, Studio 240). The Red
// Quiet: First Contact is the production it is for; the samples stay The Undersong's, as P4's were,
// with Ring Once a 9:16 movie of its own. Choice labels and reasons are samples of the author's words.
const RING = { img: 'char-odile.jpg', pos: '50% 30%', title: 'Ring Once' };
/** A choice: its number and label. A closed one has a dash for its number and the author's reason under its label. */
const choice = (label, n, { focus = false, why = '' } = {}) => why
  ? `<div class="choice off"><span class="kn">–</span><span class="l">${label}<span class="why">${why}</span></span></div>`
  : `<div class="choice${focus ? ' focus' : ''}"><span class="kn">${n}</span><span class="l">${label}</span></div>`;
const replay = (bottom = 36) => `<div style="position:absolute;z-index:4;left:0;right:0;bottom:${bottom}px;display:flex;justify-content:center"><span class="btn ghost" style="height:40px;color:color-mix(in srgb,var(--media-overlay-fg) 82%,transparent)">${ic('replay', 16)}Replay scene</span></div>`;
const storyTop = (eb, sc, style = '') => `<div class="ptop"${style ? ` style="${style}"` : ''}>${close}<div class="ttl"><div class="eb">${eb}</div><div class="sc">${sc}</div></div><span class="ib">${ic('captions', 20)}</span><span class="ib">${ic('route', 20)}</span></div>`;
// Low Water held upright: whole, a little above the middle, where P3a holds a film; never cropped to fill.
const lowUpright = `<img class="lbx" src="${A}drowned-quarter.jpg" alt="" style="top:300px">${sb(true)}${storyTop('Low Water', 'The drowned quarter')}`;
const ringFull = `<img class="pic" src="${A}${RING.img}" alt="" style="object-position:${RING.pos}"><div class="st"></div>${sb(true)}${storyTop(RING.title, 'The bell tower')}`;
const lanternTop = `${sb(true)}<div class="ptop">${close}<div class="ttl"><div class="eb">The Lantern Road</div><div class="sc">The lamp market</div></div><span class="ib">${ic('more', 20)}</span></div><div style="position:absolute;z-index:5;left:14px;top:104px;display:flex;gap:6px"><span class="ib lab on" style="height:40px">${ic('auto', 16)}Auto</span><span class="ib lab" style="height:40px">${ic('list', 16)}Log</span></div>`;
/** A step of the route: a scene's still at the story's shape, or the choice taken after it. */
const scene = (img, pos, title, data, { now = false, w = 96, h = 54 } = {}) => `<div class="rt">${still(img, pos, now, w, h)}<div class="grow"><div class="t">${title}</div><div class="d${now ? '' : ' num'}">${now ? 'now' : data}</div></div></div>`;
const taken = (label, pad = 60) => `<div class="rc" style="padding-left:${pad}px">${ic('right', 14, 2)}<span class="grow">${label}</span><span class="btn">Choose again</span></div>`;
const lowRoute = `${scene('launch-harbour.jpg', '50% 60%', 'The harbour at dusk', '1:12')}${taken('Take the skiff')}${scene('scene4-shot15.jpg', 'center', 'Under the pier', '0:54')}${taken('Follow the lantern')}${scene('drowned-quarter.jpg', '30% 50%', 'The drowned quarter', '', { now: true })}`;
const tallStep = { w: 40, h: 72 };

const P18 = [
  frame('P18a', 'An interactive movie’s page', 'phone', `${sb(true)}<div class="body"><div class="hero" style="padding-top:218px"><img src="${A}drowned-quarter.jpg" alt="" style="height:290px;object-position:30% 50%"><div class="fade" style="top:90px;height:201px"></div><div class="top">${back}${more}</div><div class="in"><h1>Low Water</h1><div class="meta">Interactive movie · The Undersong · 14 scenes</div>
<div style="margin-top:16px"><span class="btn pri wide">${ic('play', 16)}Continue <em>· The drowned quarter</em></span></div><div class="acts"><span class="btn" style="flex:1">${ic('downloaded', 18)}1.2 GB</span><span class="btn" style="width:44px;padding:0">${ic('more')}</span></div></div></div>
${sh('Your route')}${lowRoute}
</div><div class="ffoot"></div>${pill('Library')}${hi()}`),

  frame('P18b', 'A 16:9 movie held upright: whole, the choice under it', media(), `${lowUpright}
<div class="chs" style="bottom:96px">${choice('Follow the lantern', 1, { focus: true })}${choice('Stay with the boat', 2)}</div>${replay()}${hi()}`),

  frame('P18c', 'The same choice, turned', 'turned media', `<img src="${A}drowned-quarter.jpg" alt="" style="position:absolute;left:75px;top:0;width:694px;height:390px;object-fit:cover"><div class="st" style="height:140px"></div><div class="sbot" style="height:210px"></div>
${storyTop('Low Water', 'The drowned quarter', 'top:14px;left:40px;right:40px')}
<div class="chs two" style="left:120px;right:120px;bottom:62px">${choice('Follow the lantern', 1, { focus: true })}${choice('Stay with the boat', 2)}</div>${replay(12)}`),

  frame('P18d', 'A 9:16 movie: three choices, and one an earlier choice closed', media(), `${ringFull}<div class="sbot" style="height:560px"></div>
<div class="chs" style="bottom:96px">${choice('Ring the bell', 1, { focus: true })}${choice('Wake Maren', 2)}${choice('Use the tenth key', 0, { why: 'Left at the weigh house' })}${choice('Go down alone', 3)}</div>${replay()}${hi()}`),

  frame('P18e', 'The route: Choose again takes back what came after', media(), `${ringFull}<div class="veil" style="background:color-mix(in srgb,var(--media-overlay-bg) 30%,transparent)"></div>${sheet('Route', `${scene('char-maren.jpg', '50% 18%', 'The harbour steps', '0:48', tallStep)}${taken('Take the lamp', 36)}
<div class="rmore" style="padding-left:36px">${ic('down', 14, 2)}<span>5 more scenes</span></div>
${scene('char-bray.jpg', '50% 20%', 'The weigh house', '1:05', tallStep)}${taken('Leave the key', 36)}${scene(RING.img, RING.pos, 'The bell tower', '', { ...tallStep, now: true })}
<div style="padding:16px 16px 0"><span class="btn wide">${ic('replay', 16)}Start over</span></div>`, { glass: true, count: '8 scenes' })}${hi()}`),

  frame('P18f', 'A visual novel upright, on its Tall picture', media(), `<img class="pic" src="${A}maren-ledger-tall.jpg" alt="" style="object-position:50% 40%"><div class="st" style="height:220px"></div><div class="sbot" style="height:400px"></div>${lanternTop}
<div class="vnbox"><span class="who">Maren</span><div class="vnline">The lamp in the quarter is lit again. I wrote it down, so it happened.</div><span style="position:absolute;right:16px;bottom:10px;color:color-mix(in srgb,var(--media-overlay-fg) 70%,transparent)">${ic('right', 16, 2)}</span></div><div class="beats"><i class="done"></i><i class="done"></i><i class="done"></i><i class="done"></i><i></i><i></i></div>${hi()}`),

  frame('P18g', 'A visual novel’s choice, on a wide picture', media(), `<img class="lbx" src="${A}art-direction-illustrated.jpg" alt="" style="top:160px;object-position:34% 40%">${lanternTop}
<div class="vnbox at" style="top:410px"><span class="who">Maren</span><div class="vnline">Two roads out of the market. Only one has a lamp on it.</div></div>
<div class="chs" style="bottom:96px">${choice('Take the lamp road', 1, { focus: true })}${choice('Go back for Ilo', 2)}${choice('Wait for the bell', 3)}</div>${replay()}${hi()}`),

  frame('P18h', 'A 16:9 movie on a Fold', 'fold media', `<img class="lbx" src="${A}drowned-quarter.jpg" alt="" style="top:170px">${sb(true)}${storyTop('Low Water', 'The drowned quarter', 'left:20px;right:20px')}
<div class="chs two" style="left:150px;right:150px;bottom:250px">${choice('Follow the lantern', 1, { focus: true })}${choice('Stay with the boat', 2)}</div>${replay(190)}${hi()}`),
];

// ---- P19 · A story plays itself ----------------------------------------------------------------
// The owner, 28 October 2026: a story plays like a video, with optional narration, and pauses only
// when an option is shown; no tap is needed to move on; and an option is never shown alone. The
// design said the opposite and the build followed it: P4d's tap moves on, P18's Auto was a toggle off
// by default, and First Contact showed `1 Several weeks later` as its only button. The Lantern Road is voiced; The Red
// Quiet's First Contact is not (its package holds pictures and no voices), and its lines and choice
// are the author's own, from scenes 2 and 5. Low Water and The Lantern Road are P4's samples.
/** A story's line: the speaker's tab and the line. The box is the story, not a control: it never moves when the controls show. */
const vnLine = (who, line, style = '') => `<div class="vnbox flow"${style ? ` style="${style}"` : ''}>${who ? `<span class="who">${who}</span>` : ''}<div class="vnline">${line}</div></div>`;
/** The scene's beats, the ones already played filled. */
const vnBeats = (done, of) => `<div class="beats flow">${Array.from({ length: of }, (_, i) => `<i${i < done ? ' class="done"' : ''}></i>`).join('')}</div>`;
/** The top of the controls: ⌄, the story and its scene, ⋯ (Route, Start over). */
const vnTop = (eb, sc, style = '') => `<div class="ptop"${style ? ` style="${style}"` : ''}>${close}<div class="ttl"><div class="eb">${eb}</div><div class="sc">${sc}</div></div><span class="ib">${ic('more', 20)}</span></div>`;
/** Narration, a labelled switch under the top: only where the story carries voices. */
const narration = (on = true, style = 'left:14px;top:104px') => `<div style="position:absolute;z-index:5;${style}"><span class="ib lab glass" style="height:44px;gap:10px;padding:0 10px 0 14px">Narration<span class="sw sm${on ? ' on' : ''}"></span></span></div>`;
/** The transport, P19 rule 2: Back (the previous beat), Play or Pause, Log, Play on the centre line;
 *  the scene's beats over it, where a film's scrubber sits. */
const vnControls = (playing, done, of) => `<div class="vnctl">${vnBeats(done, of)}<div class="vnt"><span class="ib lab">${ic('prev', 16)}Back</span><span class="play">${ic(playing ? 'pause' : 'play', 24)}</span><span class="ib lab">${ic('list', 16)}Log</span></div></div>`;
/** Where the story stops: the choices, Replay scene and Log under them. */
const atChoice = `<div style="position:absolute;z-index:4;left:0;right:0;bottom:30px;display:flex;justify-content:center;gap:4px"><span class="btn ghost" style="height:40px;color:color-mix(in srgb,var(--media-overlay-fg) 82%,transparent)">${ic('replay', 16)}Replay scene</span><span class="btn ghost" style="height:40px;color:color-mix(in srgb,var(--media-overlay-fg) 82%,transparent)">${ic('list', 16)}Log</span></div>`;
const LANTERN_LINE = ['Maren', 'The lamp in the quarter is lit again. I wrote it down, so it happened.'];
// Maren's beat on its Tall picture. The scrims deepen only while the controls show.
const lanternTall = (controls) => `<img class="pic" src="${A}maren-ledger-tall.jpg" alt="" style="object-position:50% 40%"><div class="st" style="height:${controls ? 220 : 110}px"></div><div class="sbot" style="height:${controls ? 560 : 380}px"></div>${sb(true)}`;
// First Contact's beats on its 16:9 picture, whole at the top, the box under it (P18g).
const firstContact = (sc, controls = true) => `<img class="lbx" src="${A}red-quiet-cover.jpg" alt="" style="top:160px;object-position:50% 50%">${sb(true)}${controls ? vnTop('First Contact', sc) : ''}`;
const fcStill = (pos, origin) => `<span class="still" style="width:96px;height:54px"><img src="${A}red-quiet-cover.jpg" alt="" style="object-position:${pos};transform:scale(2.4);transform-origin:${origin}"></span>`;
const fcScene = (still, title, now = false) => `<div class="rt">${now ? still.replace('class="still"', 'class="still ring"') : still}<div class="grow"><div class="t">${title}</div>${now ? '<div class="d">now</div>' : ''}</div></div>`;

const P19 = [
  frame('P19a', 'A visual novel playing: no controls, nothing to tap', media(), `${lanternTall(false)}
<div class="vnstack" style="bottom:42px">${vnLine(...LANTERN_LINE)}</div>${hi()}`),

  frame('P19b', 'A tap: the controls, playing, with Narration', media(), `${lanternTall(true)}${vnTop('The Lantern Road', 'The lamp market')}${narration(true)}
<div class="vnstack" style="bottom:42px">${vnControls(true, 4, 6)}${vnLine(...LANTERN_LINE)}</div>${hi()}`),

  frame('P19c', 'Paused, on a wide picture', media(), `<img class="lbx" src="${A}art-direction-illustrated.jpg" alt="" style="top:160px;object-position:34% 40%">${sb(true)}${vnTop('The Lantern Road', 'The lamp market')}${narration(true)}
<div class="vnstack" style="top:410px">${vnLine('Maren', 'Somebody lit a window down there. Nobody lives in the quarter now.')}</div><div class="vnstack" style="bottom:44px">${vnControls(false, 2, 6)}</div>${hi()}`),

  frame('P19d', 'A story without voices: no Narration', media(), `${firstContact('Open hands')}
<div class="vnstack" style="top:410px">${vnLine('Imani Okoro', 'Stop. They are not shooting.')}</div><div class="vnstack" style="bottom:44px">${vnControls(true, 6, 9)}</div>${hi()}`),

  frame('P19e', 'It stops for a choice of two', media(), `${firstContact('The first name on the board')}
<div class="vnstack" style="top:410px">${vnLine('', 'Dev puts his hand on the emergency barrier. Ana waits beside me with the trauma case. The telemetry gives Elsie’s name in full.')}</div>
<div class="chs" style="bottom:90px">${choice('Return with Ana for Elsie', 1, { focus: true })}${choice('Seal the shaft and leave Elsie', 2)}</div>${atChoice}${hi()}`),

  frame('P19f', 'An interactive movie playing: a film’s controls', media(), `${lowUpright}<div class="st"></div><div class="sbot" style="height:300px"></div>
<div style="position:absolute;z-index:4;left:20px;right:20px;bottom:44px"><div class="scrub"><i style="width:53%"></i><b style="left:53%"></b></div><div class="times"><span>0:38</span><span>1:12</span></div>
<div class="trow" style="margin-top:14px;justify-content:center;gap:40px"><span class="ib">${seek(10, true, 24)}</span><span class="play">${ic('pause', 24)}</span><span class="ib">${seek(10, false, 24)}</span></div></div>${hi()}`),

  frame('P19g', 'Turned: the controls over the picture, the box over its foot', 'turned media', `<img src="${A}art-direction-illustrated.jpg" alt="" style="position:absolute;left:75px;top:0;width:694px;height:390px;object-fit:cover;object-position:34% 40%"><div class="st" style="height:150px"></div><div class="sbot" style="height:300px"></div>
${vnTop('The Lantern Road', 'The lamp market', 'top:14px;left:40px;right:40px')}${narration(true, 'left:40px;top:66px')}
<div class="vnstack" style="left:170px;right:170px;bottom:30px">${vnControls(true, 3, 6)}${vnLine('Ilo', 'Then somebody lives there.')}</div>`),

  frame('P19h', 'The route: a lone way leaves no row', media(), `${firstContact('The service ladder', false)}<div class="veil" style="background:color-mix(in srgb,var(--media-overlay-bg) 30%,transparent)"></div>${sheet('Route', `${fcScene(fcStill('50% 50%', '20% 30%'), 'Six places at the table')}
<div class="rmore">${ic('down', 14, 2)}<span>3 more scenes</span></div>
${fcScene(fcStill('50% 50%', '55% 62%'), 'The first name on the board')}${taken('Return with Ana for Elsie')}${fcScene(fcStill('50% 50%', '82% 30%'), 'The second lift')}${fcScene(fcStill('50% 50%', '86% 70%'), 'The service ladder', true)}
<div style="padding:16px 16px 0"><span class="btn wide">${ic('replay', 16)}Start over</span></div>`, { glass: true, count: '7 scenes' })}${hi()}`),
];

// Widths per frame class; a frame's card is drawn at its frame's own size.
const size = (f) => f.markup.includes('class="ap desktop') ? [1440, 900] : f.markup.includes('class="ap fold') ? [984, 1092] : f.markup.includes('class="ap turned') ? [844, 390] : [390, 844];
const withSize = (list) => list.map((f) => ({ ...f, w: size(f)[0], h: size(f)[1] }));


// ---- P20 · A graphic novel (SPEC-064, Studio 247) -------------------------------------------------
// The sample is The Undersong's Low Water, drawn: 24 pages in two chapters, read left to right, and
// The Lantern Road as a webtoon for Scroll. Its page is composed in the Studio's design from the
// master's pictures with its lettering laid over them; it stands for a generated page.
const PAGE = `${A}comic-low-water-3.jpg`;
const cmTop = (sub) => `<div class="ptop cm-top">${close}<div class="ttl"><div class="eb">Low Water, drawn</div><div class="sc">${sub}</div></div><span class="ib">${ic('list', 20)}</span><span class="ib">${ic('more', 20)}</span></div>`;
const cmFoot = (at, of, rtl = false) => `<div class="cm-foot"><span class="cm-n">${at} of ${of}</span><div class="cm-bar${rtl ? ' rtl' : ''}"><i style="width:${Math.round((at / of) * 100)}%"></i></div></div>`;
const cmChapters = sheet('Chapters', `<div class="cm-ch on"><img src="${PAGE}" alt=""><div class="grow"><b>1 · The tide</b><span>Pages 1 – 12</span></div>${ic('check', 18, 2.2)}</div><div class="cm-ch"><img src="${A}scene4-shot13.jpg" alt=""><div class="grow"><b>2 · Salt</b><span>Pages 13 – 24</span></div></div>`, { count: '24 pages' });

const P20 = [
  frame('P20a', 'A graphic novel on its world’s page', 'phone', `${sb(true)}<div class="body"><div class="hero" style="padding-top:218px"><img src="${A}saltlight-shot15.jpg" alt="" style="height:290px;object-position:40% 50%"><div class="fade" style="top:90px;height:201px"></div><div class="top">${back}${more}</div><div class="in"><h1>Low Water, drawn</h1><div class="meta">Graphic novel · The Undersong · 24 pages</div>
<div style="margin-top:16px"><span class="btn pri wide">${ic('play', 16)}Continue <em>· Page 3</em></span></div><div class="acts"><span class="btn" style="flex:1">${ic('downloaded', 18)}96 MB</span><span class="btn" style="width:44px;padding:0">${ic('more')}</span></div></div></div>
${sh('Chapters')}<div class="cm-rowp"><div class="cm-pg"><img src="${PAGE}" alt=""><span>1 · The tide</span></div><div class="cm-pg"><img src="${A}scene4-shot13.jpg" alt=""><span>2 · Salt</span></div></div>
</div><div class="ffoot"></div>${pill('Library')}${hi()}`),

  frame('P20b', 'Reading: the page whole, nothing over it', media('cm'), `<div class="cm-stage"><img src="${PAGE}" alt=""></div>${hi()}`),

  frame('P20c', 'A tap: the controls', media('cm'), `${sb(true)}<div class="st"></div><div class="cm-stage"><img src="${PAGE}" alt=""></div>${cmTop('Chapter 1 · The tide')}<div class="sbot" style="height:160px"></div>${cmFoot(3, 24)}${hi()}`),

  frame('P20d', 'Right to left: the book turns the other way', media('cm'), `${sb(true)}<div class="st"></div><div class="cm-stage"><img src="${PAGE}" alt=""></div>${cmTop('Chapter 1 · The tide')}<div class="cm-swipe">${ic('right', 20, 2)}<span>next</span></div><div class="sbot" style="height:160px"></div>${cmFoot(3, 24, true)}${hi()}`),

  frame('P20e', 'Scroll: a webtoon, one column', media('cm'), `<div class="cm-scroll"><img src="${A}drowned-quarter.jpg" alt="" style="object-position:30% 50%"><img src="${A}char-maren.jpg" alt="" style="object-position:50% 25%"><img src="${A}art-direction-illustrated.jpg" alt="" style="object-position:40% 40%"></div>${sb(true)}<div class="st"></div><div class="ptop cm-top">${close}<div class="ttl"><div class="eb">The Lantern Road</div><div class="sc">Episode 2</div></div><span class="ib">${ic('list', 20)}</span><span class="ib">${ic('more', 20)}</span></div>${hi()}`),

  frame('P20f', 'Turned: the page fills the height', 'turned media cm', `<div class="cm-stage turned"><img src="${PAGE}" alt=""></div>`),

  frame('P20g', 'Chapters', media('cm'), `${sb(true)}<div class="cm-stage"><img src="${PAGE}" alt=""></div><div class="veil"></div>${cmChapters}${hi()}`),

  frame('P20h', 'A graphic novel this Player cannot read', 'phone', `${sb(true)}<div class="body"><div class="hero" style="padding-top:218px"><img src="${A}saltlight-shot15.jpg" alt="" style="height:290px;object-position:40% 50%"><div class="fade" style="top:90px;height:201px"></div><div class="top">${back}${more}</div><div class="in"><h1>Low Water, drawn</h1><div class="meta">Graphic novel · The Undersong · 24 pages</div>
<div style="margin-top:16px"><span class="btn pri wide">${ic('download', 16)}Update app</span></div></div></div>
</div><div class="ffoot"></div>${pill('Discover')}${hi()}`),
];

// ---- P21 · A graphic novel, read with its own controls -------------------------------------------
// The owner, 30 October 2026, with the Fold7's screenshots of the published Ledger of Nights, drawn:
// "Graphic novel UI is broken", "We need a designed cover", and the reader "only shows the top half
// with no way to control the navigation". The pages are that package's own, eleven in two chapters.
// The cover stands for the one to be made in the Studio: page 8's harbour with the title set over it.
const GN = { title: 'The Ledger of Nights, drawn', cover: `${A}ledger-drawn-cover.jpg`, size: '4.3 MB', pages: 11 };
const gp = (n) => `${A}ledger-drawn-p${String(n).padStart(4, '0')}.jpg`;
const GN_CH = [['Neap', 1, 4], ['Slack water', 5, 11]];
/** The book's head: its cover whole, 2:3, over its own blur, the press under it. */
const gnHead = (press, meta = `Graphic novel · The Undersong · ${GN.pages} pages`) => `<div class="gn-hd on-media"><img class="bg" src="${GN.cover}" alt=""><div class="dk"></div><div class="top">${back}${more}</div><img class="cv" src="${GN.cover}" alt=""><h1>${GN.title}</h1><div class="meta">${meta}</div>${press}</div>`;
const gnGet = `<span class="btn pri wide">${ic('download', 18)}Get <em>· ${GN.size}</em></span>`;
const gnGetting = `<div class="gn-prog"><div class="bar"><i style="width:37%"></i></div><div style="display:flex;align-items:center;gap:10px;margin-top:10px"><span class="grow mute num" style="font:var(--type-ui)">Downloading · 1.6 of ${GN.size}</span><span class="btn" style="height:40px">Cancel</span></div></div>`;
const gnRead = (page) => `<span class="btn pri wide">${ic('book', 18)}${page ? `Continue <em>· Page ${page}</em>` : 'Read'}</span><div class="acts"><span class="btn" style="flex:1">${ic('downloaded', 18)}${GN.size}</span><span class="btn" style="width:44px;padding:0">${ic('more')}</span></div>`;
/** A chapter as a row: its first page, its title and pages, and where you are. */
const gnChapter = ([title, from, to], i, at) => `<div class="gn-ch${at >= from && at <= to ? ' on' : ''}"><img src="${gp(from)}" alt=""><div class="grow"><b>${i + 1} · ${title}</b><span class="num">Pages ${from} – ${to}</span></div>${at >= from && at <= to ? `<span class="num gn-at">Page ${at}</span>` : at > to ? ic('downloaded', 20, 1.7) : ''}</div>`;
const gnChapters = (at = 0) => `${sh('Chapters', `<span class="ct num">${GN_CH.length}</span>`)}${GN_CH.map((c, i) => gnChapter(c, i, at)).join('')}`;
/** The reader's top and foot. The foot turns: back, the page you are on over a bar you can drag, next. */
const gnTop = (sub = 'Chapter 1 · Neap') => `<div class="ptop cm-top">${close}<div class="ttl"><div class="eb">${GN.title}</div><div class="sc">${sub}</div></div><span class="ib">${ic('grid', 20)}</span><span class="ib">${ic('more', 20)}</span></div>`;
const gnFoot = (at, label = `${at} of ${GN.pages}`, style = '') => `<div class="gn-foot"${style ? ` style="${style}"` : ''}><span class="gn-b">${ic('left', 22, 2)}</span><div class="grow"><div class="gn-n num">${label}</div><div class="gn-bar"><i style="width:${Math.round((at / GN.pages) * 100)}%"></i><b style="left:${Math.round((at / GN.pages) * 100)}%"></b></div></div><span class="gn-b">${ic('right', 22, 2)}</span></div>`;
const gnPage = (n) => `<div class="cm-stage"><img src="${gp(n)}" alt=""></div>`;
/** Where a tap lands, drawn over the page for the turn only: back, the controls, next. */
const gnZones = (rtl = false) => `<div class="gn-zones"><span>${ic('left', 22, 2)}${rtl ? 'Next' : 'Back'}</span><span>${ic('grid', 20)}Controls</span><span>${rtl ? 'Back' : 'Next'}${ic('right', 22, 2)}</span></div>`;
const gnSpread = (a, b) => `<div class="gn-spread"><img src="${gp(a)}" alt=""><img src="${gp(b)}" alt=""></div>`;
/** Pages: every page of the book by chapter, the one you are on ringed. */
const gnPages = (at, cols = 3, w = 104) => GN_CH.map(([title, from, to], i) => `<div class="gn-pgh">${i + 1} · ${title}</div><div class="gn-grid" style="grid-template-columns:repeat(${cols},${w}px)">${Array.from({ length: to - from + 1 }, (_, k) => from + k).map((n) => `<div class="gn-pg${n === at ? ' on' : ''}"><img src="${gp(n)}" alt=""><span class="num">${n}</span></div>`).join('')}</div>`).join('');

const P21 = [
  frame('P21a', 'Discover: the book on its cover', 'phone', `${sb()}${discoverHead()}${discoverChips().replace('<span class="chip on">All</span>', '<span class="chip">All</span>').replace('<span class="chip">Read</span>', '<span class="chip on">Read</span>')}<div class="body">
<div class="ft on-media"><img src="${GN.cover}" alt="" style="object-position:50% 30%"><div class="shade"></div><div class="in"><div class="fk">${NEWTAG}<span>Graphic novel</span></div><h1>${GN.title}</h1><div class="meta num">The Undersong · 2 chapters · ${GN.pages} pages</div>${gnGet.replace('<span class="btn pri wide">', '<span class="btn pri wide" style="margin-top:16px">')}</div></div>
${sh('Read')}<div class="hrow">${poster({ tall: 'ledger-drawn-cover.jpg', pos: '50% 30%', title: GN.title, kind: 'Graphic novel · 11 pages', w: 132 })}${poster({ tall: TALL.ledger, pos: '50% 30%', title: STORY.ledger.title, kind: 'Book · 23 chapters', w: 132 })}${poster({ tall: TALL.juju, title: 'Na love or Juju', kind: 'Book · 24 chapters', w: 132 })}</div>
</div>${pill('Discover')}${hi()}`),

  frame('P21b', 'Its page, not on the phone yet', 'phone', `${sb(true)}<div class="body">${gnHead(gnGet)}${gnChapters()}</div>${pill('Discover')}${hi()}`),

  frame('P21c', 'Getting it: progress in place of the press', 'phone', `${sb(true)}<div class="body">${gnHead(gnGetting)}${gnChapters()}</div>${pill('Discover')}${hi()}`),

  frame('P21d', 'On the phone: Continue, and the chapters as rows', 'phone', `${sb(true)}<div class="body">${gnHead(gnRead(3))}${gnChapters(3)}</div>${pill('Library')}${hi()}`),

  frame('P21e', 'Opening: the controls show, then rest', media('cm'), `${sb(true)}<div class="st"></div>${gnPage(3)}${gnTop()}<div class="sbot" style="height:200px"></div>${gnFoot(3)}${hi()}`),

  frame('P21f', 'Resting: the page whole, a tap at an edge turns it', media('cm'), `${gnPage(3)}${gnZones()}${hi()}`),

  frame('P21g', 'Pages: any page, by chapter', media('cm'), `${sb(true)}${gnPage(3)}<div class="veil"></div>${sheet('Pages', gnPages(3), { count: `${GN.pages} pages`, style: 'top:112px' })}${hi()}`),

  frame('P21h', 'A Fold open: two pages, as a book opens', 'fold media cm', `${sb(true)}${gnSpread(2, 3)}${hi()}`),

  frame('P21i', 'A Fold open, with its controls', 'fold media cm', `${sb(true)}<div class="st"></div>${gnSpread(2, 3)}${gnTop('Chapter 1 · Neap · Pages 2 – 3').replace('class="ptop cm-top"', 'class="ptop cm-top" style="left:24px;right:24px"')}<div class="sbot" style="height:200px"></div>${gnFoot(3, '2 – 3 of 11', 'left:160px;right:160px')}${hi()}`),
];

export const FRAMES = { p1: withSize(P1), p2: withSize(P2), p3: withSize(P3), p4: withSize(P4), p5: withSize(P5), p6: withSize(P6), p7: withSize(P7), p8: withSize(P8), p9: withSize(P9), p10: withSize(P10), p11: withSize(P11), p12: withSize(P12), p13: withSize(P13), p14: withSize(P14), p15: withSize(P15), p16: withSize(P16), p17: withSize(P17), p18: withSize(P18), p19: withSize(P19), p20: withSize(P20), p21: withSize(P21) };
