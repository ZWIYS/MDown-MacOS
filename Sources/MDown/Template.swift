import Foundation

enum Template {
    static func html(markdown: String, highlights: String = "[]", tint: Tint = .none) -> String {
        let colorsJSON = "[" + Pastel.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: ",") + "]"
        let strings: [String: String] = [
            "heading": tr("Heading"), "plain": tr("Plain Text"), "bold": tr("Bold"), "italic": tr("Italic"),
            "strike": tr("Strikethrough"), "code": tr("Code"), "quote": tr("Quote"), "list": tr("List"),
            "highlight": tr("Highlight Color"), "removeHL": tr("Remove Highlight"), "writeHere": tr("Write here…"),
            "notFound": tr("Couldn't find this spot in the source. Select text inside a single paragraph without formatting, or turn editing on."),
        ]
        let tJSON = String(decoding: (try? JSONSerialization.data(withJSONObject: strings)) ?? Data("{}".utf8), as: UTF8.self)
            .replacingOccurrences(of: "</", with: "<\\/")
        let data = (try? JSONSerialization.data(withJSONObject: markdown, options: [.fragmentsAllowed])) ?? Data("\"\"".utf8)
        let json = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "</", with: "<\\/")
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css)\(paletteCSS)</style><style>:root{--bg-l:\(tint.lightHex);--bg-d:\(tint.darkHex)}</style></head><body><main id="c"></main>
        <script>let MD=\(json);const T=\(tJSON);const COLORS=\(colorsJSON);const HLDATA=\(highlights.replacingOccurrences(of: "</", with: "<\\/"));const SOURCE=false;\(js)</script></body></html>
        """
    }

    /// Цвета маркера из единой палитры (Pastel).
    static var paletteCSS: String {
        let light = Pastel.allCases.map { "--hl-\($0.rawValue):\($0.hlLight)" }.joined(separator: ";")
        let dark = Pastel.allCases.map { "--hl-\($0.rawValue):\($0.hlDark)" }.joined(separator: ";")
        let marks = Pastel.allCases.map { "mark.c-\($0.rawValue){background:var(--hl-\($0.rawValue))}" }.joined()
        let hint = "body.editing #tail:empty::before{content:\"\(tr("Click to write…"))\";color:var(--sub);opacity:.6}"
        return ":root{\(light)}@media (prefers-color-scheme:dark){:root{\(dark)}}\(marks)\(hint)"
    }

    static let css = #"""
    :root{color-scheme:light dark;--bg-l:#fff;--bg-d:#1e1e1e;--bg:var(--bg-l);--fg:#1d1d1f;--sub:#6e6e73;--line:#d2d2d7;--code:#f5f5f7;--accent:#0066cc}
    @media (prefers-color-scheme:dark){:root{--bg:var(--bg-d);--fg:#f5f5f7;--sub:#98989d;--line:#3a3a3c;--code:#2c2c2e;--accent:#2997ff}}
    mark.hl{color:inherit;border-radius:.2em;padding:.06em 0;cursor:pointer;-webkit-box-decoration-break:clone;box-decoration-break:clone}
    #pal{position:absolute;z-index:10;display:none;align-items:center;gap:7px;padding:7px 10px;border-radius:999px;background:var(--bg);border:1px solid var(--line);box-shadow:0 6px 24px rgba(0,0,0,.2);-webkit-user-select:none}
    #pal.show{display:flex}
    #pal button{width:22px;height:22px;border-radius:50%;border:1px solid rgba(0,0,0,.14);padding:0;cursor:pointer}
    #pal button:hover{transform:scale(1.15)}
    #pal .x{display:none;background:none;border:0;color:var(--sub);font-size:14px;line-height:22px}
    #pal.edit .x{display:block}
    *{box-sizing:border-box}
    html{-webkit-text-size-adjust:none}
    body{margin:0;background:var(--bg);color:var(--fg);font:17px/1.65 -apple-system,BlinkMacSystemFont,"SF Pro Text",system-ui,sans-serif;-webkit-font-smoothing:antialiased}
    main{max-width:46em;margin:0 auto;padding:40px 32px 96px}
    h1,h2,h3,h4,h5,h6{font-family:-apple-system,"SF Pro Display",system-ui,sans-serif;line-height:1.25;margin:1.6em 0 .5em;font-weight:650;letter-spacing:-.01em}
    h1{font-size:2.1em;margin-top:.2em;letter-spacing:-.02em}
    h2{font-size:1.6em;padding-bottom:.25em;border-bottom:1px solid var(--line)}
    h3{font-size:1.28em}h4{font-size:1.08em}h5,h6{font-size:1em;color:var(--sub)}
    p{margin:.9em 0}
    a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}
    img{max-width:100%;height:auto;border-radius:8px}
    ul,ol{padding-left:1.6em;margin:.7em 0}li{margin:.25em 0}
    li.task{list-style:none;margin-left:-1.4em}li.task input{margin-right:.5em}
    blockquote{margin:1.1em 0;padding:.1em 1.1em;border-left:3px solid var(--line);color:var(--sub)}
    hr{border:0;border-top:1px solid var(--line);margin:2em 0}
    code{font:.88em ui-monospace,"SF Mono",Menlo,monospace;background:var(--code);padding:.15em .4em;border-radius:6px}
    pre{background:var(--code);padding:14px 16px;border-radius:10px;overflow-x:auto;line-height:1.5;margin:1.1em 0}
    pre code{background:none;padding:0;font-size:.86em}
    pre.src{white-space:pre-wrap;word-wrap:break-word;font:.86em/1.6 ui-monospace,"SF Mono",Menlo,monospace}
    table{border-collapse:collapse;margin:1.1em 0;display:block;overflow-x:auto}
    th,td{border:1px solid var(--line);padding:.45em .8em}
    th{background:var(--code);font-weight:600}
    kbd{font:.85em ui-monospace,Menlo,monospace;border:1px solid var(--line);border-bottom-width:2px;border-radius:5px;padding:.05em .4em}
    details{margin:1em 0}summary{cursor:pointer;font-weight:600}
    mark[class^="c-"]{color:inherit;border-radius:.2em;padding:.06em 0}
    #fmenu{position:absolute;z-index:20;display:none;flex-direction:column;gap:4px;padding:8px;border-radius:14px;background:var(--bg);border:1px solid var(--line);box-shadow:0 10px 34px rgba(0,0,0,.28);-webkit-user-select:none;font:13px -apple-system,system-ui,sans-serif}
    #fmenu.show{display:flex}
    #fmenu .row{display:flex;gap:3px;align-items:center}
    #fmenu .lbl{color:var(--sub);font-size:11px;padding:3px 4px 0}
    #fmenu button{min-width:32px;height:28px;padding:0 8px;border:0;border-radius:7px;background:transparent;color:var(--fg);cursor:pointer;font:600 13px -apple-system,system-ui,sans-serif}
    #fmenu button:hover{background:rgba(128,128,128,.2)}
    #fmenu button.dot{min-width:22px;width:22px;height:22px;border-radius:50%;border:1px solid rgba(0,0,0,.14);padding:0;margin:0 2px}
    #fmenu .xb{color:var(--sub)}
    #toast{position:fixed;left:50%;bottom:28px;transform:translateX(-50%);z-index:30;padding:9px 16px;border-radius:12px;background:var(--fg);color:var(--bg);font:13px -apple-system,system-ui,sans-serif;opacity:0;transition:opacity .2s;pointer-events:none;max-width:80%}
    #toast.show{opacity:.92}
    body.editing .blk{cursor:text;border-radius:8px}
    body.editing .blk:hover{background:rgba(128,128,128,.09)}
    textarea.ed{display:block;width:100%;margin:.6em 0;padding:12px 14px;font:.9em/1.55 ui-monospace,"SF Mono",Menlo,monospace;color:var(--fg);background:var(--code);border:1.5px solid var(--accent);border-radius:10px;resize:none;outline:none;overflow:hidden}
    #tail{min-height:34vh}
    body.editing #tail{cursor:text}
    """#

    static let js = #"""
    const esc=s=>s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    const refs={};
    function inline(s){
      const codes=[];
      s=s.replace(/(`+)([\s\S]*?[^`])\1(?!`)/g,(m,a,c)=>{codes.push('<code>'+esc(c.trim())+'</code>');return '\u0000'+(codes.length-1)+'\u0000'});
      s=esc(s);
      s=s.replace(/&lt;(\/?(?:kbd|sup|sub|b|i|em|strong|u|del|ins|small)|br\s*\/?)&gt;/gi,'<$1>');
      s=s.replace(/&lt;mark(?: data-c="([roygbvpx])")?&gt;/gi,(m,c)=>`<mark class="c-${c||'y'}">`).replace(/&lt;\/mark&gt;/gi,'</mark>');
      s=s.replace(/!\[([^\]]*)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)/g,(m,a,u,t)=>`<img alt="${a}" src="${u}"${t?` title="${t}"`:''}>`);
      s=s.replace(/\[([^\]]+)\]\[([^\]]*)\]/g,(m,t,r)=>refs[(r||t).toLowerCase()]?`<a href="${refs[(r||t).toLowerCase()]}">${t}</a>`:m);
      s=s.replace(/\[([^\]]+)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)/g,(m,a,u)=>`<a href="${u}">${a}</a>`);
      s=s.replace(/&lt;(https?:\/\/[^\s&]+)&gt;/g,'<a href="$1">$1</a>');
      s=s.replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g,'$1<a href="$2">$2</a>');
      s=s.replace(/\*\*\*(.+?)\*\*\*/g,'<strong><em>$1</em></strong>');
      s=s.replace(/\*\*(.+?)\*\*/g,'<strong>$1</strong>').replace(/(^|\W)__(.+?)__(?=\W|$)/g,'$1<strong>$2</strong>');
      s=s.replace(/\*(.+?)\*/g,'<em>$1</em>').replace(/(^|\W)_(.+?)_(?=\W|$)/g,'$1<em>$2</em>');
      s=s.replace(/~~(.+?)~~/g,'<del>$1</del>');
      s=s.replace(/ {2,}\n|\\\n/g,'<br>');
      return s.replace(/\u0000(\d+)\u0000/g,(m,i)=>codes[i]);
    }
    const indentOf=l=>l.match(/^\s*/)[0].length;
    const slug=t=>t.toLowerCase().replace(/<[^>]+>/g,'').replace(/[^\p{L}\p{N}\s-]/gu,'').trim().replace(/\s+/g,'-');
    const fenceRe=/^\s{0,3}(`{3,}|~{3,})\s*([\w+-]*)/;
    const hRe=/^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$/;
    const hrRe=/^\s{0,3}([-*_])(\s*\1){2,}\s*$/;
    const liRe=/^(\s*)([-*+]|\d{1,9}[.)])\s+(.*)$/;
    const tblSep=/^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/;
    const htmlRe=/^\s{0,3}<\/?(details|summary|div|p|img|br|table|thead|tbody|tr|td|th|h[1-6]|center|a|span|kbd|sup|sub|hr|picture|source|video|figure|figcaption|section|ul|ol|li)\b/i;
    const quoteRe=/^\s{0,3}>/;
    const starts=l=>fenceRe.test(l)||hRe.test(l)||hrRe.test(l)||quoteRe.test(l)||liRe.test(l)||htmlRe.test(l);
    const splitRow=r=>r.trim().replace(/\\\|/g,'\u0001').replace(/^\|/,'').replace(/\|$/,'').split('|').map(c=>c.replace(/\u0001/g,'|').trim());

    function parseList(lines,i,tight0){
      const m0=lines[i].match(liRe), base=m0[1].length, ordered=/\d/.test(m0[2]);
      const start=ordered?parseInt(m0[2]):1, items=[]; let loose=false;
      outer: while(i<lines.length){
        const m=lines[i].match(liRe);
        if(!m||m[1].length!==base||/\d/.test(m[2])!==ordered) break;
        const cIndent=m[0].length-m[3].length, item=[m[3]]; items.push(item); i++;
        while(i<lines.length){
          const l=lines[i];
          if(l.trim()===''){
            let j=i; while(j<lines.length&&lines[j].trim()==='') j++;
            if(j>=lines.length) { i=j; break outer; }
            const ms=lines[j].match(liRe);
            if(ms&&ms[1].length===base&&/\d/.test(ms[2])===ordered){ loose=true; i=j; continue outer; }
            if(indentOf(lines[j])>base){ item.push(''); i++; continue; }
            i=j; break outer;
          }
          const ml=l.match(liRe);
          if(ml&&ml[1].length<=base) continue outer;
          if(indentOf(l)>base){ item.push(l.slice(Math.min(indentOf(l),cIndent))); i++; continue; }
          if(!starts(l)){ item.push(l); i++; continue; }
          break outer;
        }
      }
      const html=items.map(it=>{
        let task='';
        const t=it[0].match(/^\[([ xX])\]\s+(.*)$/);
        if(t){ task=`<input type="checkbox" disabled ${t[1]!==' '?'checked':''}> `; it[0]=t[2]; }
        const inner=blocks(it,!loose);
        return `<li${t?' class="task"':''}>${task}${inner}</li>`;
      }).join('');
      const tag=ordered?'ol':'ul';
      return [`<${tag}${ordered&&start!==1?` start="${start}"`:''}>${html}</${tag}>`,i];
    }

    function blocks(lines,tight,top){
      const out=[]; let i=0,lastLen=0,lastI0=0;
      const mark=()=>{if(top&&out.length>lastLen){const e=Math.min(i,lines.length);for(let k=lastLen;k<out.length;k++)out[k]=`<div class="blk" data-s="${lastI0}" data-e="${e}">${out[k]}</div>`;lastLen=out.length;}};
      while(i<lines.length){
        mark();
        const l=lines[i]; let m;
        if(l.trim()===''){i++;continue;}
        lastI0=i;
        if(m=l.match(fenceRe)){
          const ch=m[1][0]==='`'?'`':'~', len=m[1].length, buf=[]; i++;
          const close=new RegExp('^\\s{0,3}'+ch+'{'+len+',}\\s*$');
          while(i<lines.length&&!close.test(lines[i])){buf.push(lines[i]);i++;}
          i++;
          out.push(`<pre><code class="language-${m[2]}">${esc(buf.join('\n'))}</code></pre>`); continue;
        }
        if(m=l.match(hRe)){ const t=inline(m[2]); out.push(`<h${m[1].length} id="${slug(m[2])}">${t}</h${m[1].length}>`); i++; continue; }
        if(hrRe.test(l)){ out.push('<hr>'); i++; continue; }
        if(quoteRe.test(l)){
          const buf=[]; while(i<lines.length&&quoteRe.test(lines[i])){buf.push(lines[i].replace(/^\s{0,3}>\s?/,''));i++;}
          out.push(`<blockquote>${blocks(buf)}</blockquote>`); continue;
        }
        if(l.includes('|')&&i+1<lines.length&&tblSep.test(lines[i+1])&&!/^\s*[-*+]\s/.test(l)){
          const head=splitRow(l), al=splitRow(lines[i+1]).map(c=>/^:-+:$/.test(c)?'center':/-:$/.test(c)?'right':/^:-/.test(c)?'left':'');
          i+=2; const rows=[];
          while(i<lines.length&&lines[i].trim()!==''&&lines[i].includes('|')){rows.push(splitRow(lines[i]));i++;}
          const cell=(t,c,k)=>`<${t}${al[k]?` style="text-align:${al[k]}"`:''}>${inline(c||'')}</${t}>`;
          out.push(`<table><thead><tr>${head.map((c,k)=>cell('th',c,k)).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${head.map((_,k)=>cell('td',r[k],k)).join('')}</tr>`).join('')}</tbody></table>`);
          continue;
        }
        if(liRe.test(l)){ const [h,ni]=parseList(lines,i); out.push(h); i=ni; continue; }
        if(htmlRe.test(l)){
          const buf=[]; while(i<lines.length&&lines[i].trim()!==''){buf.push(lines[i]);i++;}
          out.push(buf.join('\n')); continue;
        }
        const buf=[l.replace(/^\s+/,'')]; i++;
        while(i<lines.length&&lines[i].trim()!==''&&!starts(lines[i])&&!(lines[i].includes('|')&&i+1<lines.length&&tblSep.test(lines[i+1]))){buf.push(lines[i].replace(/^\s+/,''));i++;}
        const t=inline(buf.join('\n'));
        out.push(tight?t:`<p>${t}</p>`);
        if(tight&&i<lines.length&&lines[i].trim()!=='') out.push('');
      }
      mark();
      return out.join(tight?'':'\n');
    }

    function render(md){
      let lines=md.split('\n');
      if(lines[0]==='---'){const e=lines.indexOf('---',1);if(e>0)for(let k=0;k<=e;k++)lines[k]='';}
      let inFence=false;
      lines=lines.map(l=>{
        if(/^\s{0,3}(```|~~~)/.test(l)) inFence=!inFence;
        if(inFence) return l;
        const m=l.match(/^\s{0,3}\[([^\]]+)\]:\s*(\S+)/);
        if(m){refs[m[1].toLowerCase()]=m[2];return '';}
        return l;
      });
      return blocks(lines,false,true);
    }

    const root=document.getElementById('c');
    let HL=HLDATA||[];
    let EDITING=false,editEl=null,editOrig=null;
    MD=MD.replace(/\r\n?/g,'\n');
    const post=()=>{try{window.webkit.messageHandlers.hl.postMessage(JSON.stringify(HL))}catch(e){}};

    /* ---------- выделения цветом ---------- */
    function textNodes(){const w=document.createTreeWalker(root,NodeFilter.SHOW_TEXT),a=[];let n;while(n=w.nextNode())a.push(n);return a;}
    function clearMarks(){root.querySelectorAll('mark.hl').forEach(m=>{const p=m.parentNode;while(m.firstChild)p.insertBefore(m.firstChild,m);p.removeChild(m);});root.normalize();}
    function paint(h){
      let pos=0;
      for(const n of textNodes()){
        const s=pos,e=pos+n.data.length;pos=e;
        if(e<=h.start||s>=h.end) continue;
        const a=Math.max(h.start,s)-s,b=Math.min(h.end,e)-s;
        let mid=n; if(a>0) mid=n.splitText(a);
        if(b-a<mid.data.length) mid.splitText(b-a);
        const mk=document.createElement('mark');mk.className='hl c-'+h.color;mk.dataset.id=h.id;
        mid.parentNode.insertBefore(mk,mid);mk.appendChild(mid);
      }
    }
    function applyAll(){
      clearMarks();
      const full=root.textContent;
      HL.forEach(h=>{
        if(full.substr(h.start,h.end-h.start)!==h.text){
          let best=-1,bd=1e12,i=-1;
          while((i=full.indexOf(h.text,i+1))>=0){const d=Math.abs(i-h.start);if(d<bd){bd=d;best=i;}}
          if(best<0){h.orphan=true;return;}
          h.start=best;h.end=best+h.text.length;
        }
        h.orphan=false;paint(h);
      });
    }
    function selOffsets(){
      const s=getSelection(); if(!s.rangeCount||s.isCollapsed) return null;
      const r=s.getRangeAt(0); if(!root.contains(r.commonAncestorContainer)) return null;
      const pre=document.createRange();pre.selectNodeContents(root);pre.setEnd(r.startContainer,r.startOffset);
      let start=pre.toString().length,text=r.toString();
      start+=text.length-text.trimStart().length; text=text.trim();
      return text?{start,end:start+text.length,text}:null;
    }

    function draw(){
      root.innerHTML=render(MD)+'<div id="tail"></div>';
      applyAll();
    }
    window.updateMD=function(md){MD=md.replace(/\r\n?/g,'\n');undoS.length=0;redoS.length=0;const y=scrollY;for(const k in refs)delete refs[k];hidePal();editEl=null;draw();scrollTo(0,y);};

    const pal=document.createElement('div');pal.id='pal';
    pal.innerHTML=COLORS.map(c=>`<button data-c="${c}" style="background:var(--hl-${c})"></button>`).join('')+'<button class="x" title="'+T.removeHL+'">✕</button>';
    document.body.appendChild(pal);
    let target=null,pend=null;
    function hidePal(){pal.classList.remove('show');}
    function showPal(rect,isTarget){
      pal.classList.toggle('edit',isTarget);pal.classList.add('show');
      const w=pal.offsetWidth;
      let left=rect.left+scrollX+rect.width/2-w/2;
      left=Math.max(8,Math.min(left,document.documentElement.clientWidth+scrollX-w-8));
      let top=rect.top+scrollY-pal.offsetHeight-10;
      if(top<scrollY+4) top=rect.bottom+scrollY+10;
      pal.style.left=left+'px';pal.style.top=top+'px';
    }
    pal.addEventListener('mousedown',e=>e.preventDefault());
    pal.addEventListener('click',e=>{
      const b=e.target.closest('button'); if(!b) return;
      if(b.classList.contains('x')){HL=HL.filter(h=>h.id!==target);}
      else if(target){const h=HL.find(h=>h.id===target);if(h)h.color=b.dataset.c;}
      else if(pend){
        HL=HL.filter(h=>h.end<=pend.start||h.start>=pend.end);
        HL.push({id:Date.now().toString(36)+Math.random().toString(36).slice(2,6),start:pend.start,end:pend.end,text:pend.text,color:b.dataset.c});
        getSelection().removeAllRanges();
      }
      target=null;pend=null;hidePal();applyAll();post();
    });
    document.addEventListener('mousedown',e=>{if(!pal.contains(e.target))hidePal();});
    document.addEventListener('mouseup',e=>{
      if(EDITING||pal.contains(e.target)) return;
      setTimeout(()=>{
        const s=getSelection();
        if(s.rangeCount&&!s.isCollapsed){const o=selOffsets();if(o){pend=o;target=null;showPal(s.getRangeAt(0).getBoundingClientRect(),false);return;}}
        const mk=e.target.closest&&e.target.closest('mark.hl');
        if(mk){target=mk.dataset.id;pend=null;showPal(mk.getBoundingClientRect(),true);return;}
        pend=null;target=null;hidePal();
      },0);
    });

    /* ---------- правка на месте: клик по блоку превращает его в поле с исходником ---------- */
    const curLines=()=>MD.split('\n');
    function autosize(ta){ta.style.height='auto';ta.style.height=(ta.scrollHeight+2)+'px';}
    function beginEdit(ta,orig){
      editEl=ta;editOrig=orig;ta.spellcheck=false;
      ta.addEventListener('input',()=>autosize(ta));
      ta.addEventListener('keydown',ev=>{
        if(ev.key==='Escape'||(ev.key==='Enter'&&(ev.metaKey||ev.ctrlKey))){ev.preventDefault();ta.blur();}
        else if(ev.key==='Tab'){ev.preventDefault();document.execCommand('insertText',false,'  ');}
      });
      ta.addEventListener('blur',()=>commitEdit(ta));
      autosize(ta);ta.focus();ta.setSelectionRange(ta.value.length,ta.value.length);
    }
    function startEdit(blk){
      const s=+blk.dataset.s,e=+blk.dataset.e;
      const ta=document.createElement('textarea');ta.className='ed';ta.dataset.s=s;ta.dataset.e=e;
      ta.value=curLines().slice(s,e).join('\n');
      blk.replaceWith(ta);beginEdit(ta,blk);
    }
    function startAppend(){
      const ta=document.createElement('textarea');ta.className='ed';ta.dataset.append='1';ta.placeholder=T.writeHere;
      const tail=document.getElementById('tail');tail.parentNode.insertBefore(ta,tail);beginEdit(ta,null);
    }
    function commitEdit(ta){
      if(editEl!==ta) return;
      editEl=null;const orig=editOrig;editOrig=null;
      const neu=ta.value.replace(/\s+$/,'');
      const lines=curLines();
      if(ta.dataset.append){
        if(!neu.trim()){ta.remove();return;}
        while(lines.length&&lines[lines.length-1].trim()==='')lines.pop();
        lines.push('',...neu.split('\n'),'');
      }else{
        const s=+ta.dataset.s,e=+ta.dataset.e;
        const was=lines.slice(s,e);
        if(neu===was.join('\n').replace(/\s+$/,'')){ta.replaceWith(orig);return;}
        let tb=0;while(tb<was.length&&was[was.length-1-tb].trim()==='')tb++;   // пустые строки после блока сохраняем
        if(!neu.trim()) lines.splice(s,e-s);
        else lines.splice(s,e-s,...neu.split('\n'),...Array(tb).fill(''));
      }
      setMD(lines.join('\n'));
    }
    window.setEditing=function(on){
      EDITING=on;document.body.classList.toggle('editing',on);
      if(!on&&editEl)editEl.blur();
      hidePal();
    };

    document.addEventListener('click',e=>{
      const a=e.target.closest&&e.target.closest('a[href]');
      if(a){
        const h=a.getAttribute('href');
        if(h&&h.startsWith('#')){e.preventDefault();const el=document.getElementById(decodeURIComponent(h.slice(1)));if(el)el.scrollIntoView({behavior:'smooth'});}
        return;
      }
      if(!EDITING) return;
      if(e.target.closest('textarea,input,#pal')) return;
      const sel=getSelection(); if(sel&&!sel.isCollapsed) return;
      const t=e.target.closest('#tail');
      if(t&&t.isConnected){startAppend();return;}
      const b=e.target.closest('.blk');
      if(b&&b.isConnected) startEdit(b);
    });


    /* ---------- форматирование: меню по правому клику (два пальца) на выделенном тексте ---------- */

    /* ---------- история правок: ⌘Z / ⇧⌘Z в красивом виде ---------- */
    const undoS=[],redoS=[];
    let SPLIT=false;
    function applyMD(t){
      MD=t;const y=scrollY;draw();scrollTo(0,y);
      try{window.webkit.messageHandlers.edit.postMessage(MD)}catch(e){}
    }
    function setMD(t){
      if(t===MD) return;
      undoS.push(MD);if(undoS.length>200)undoS.shift();redoS.length=0;
      applyMD(t);
    }
    function undoMD(){if(!undoS.length)return false;redoS.push(MD);applyMD(undoS.pop());return true;}
    function redoMD(){if(!redoS.length)return false;undoS.push(MD);applyMD(redoS.pop());return true;}
    window.mdUndo=function(){const a=document.activeElement;if(a&&a.tagName==='TEXTAREA'){document.execCommand('undo');return;}undoMD();};
    window.mdRedo=function(){const a=document.activeElement;if(a&&a.tagName==='TEXTAREA'){document.execCommand('redo');return;}redoMD();};
    window.setSplit=function(b){SPLIT=b;};
    document.addEventListener('keydown',e=>{
      if(!(e.metaKey||e.ctrlKey)||e.key.toLowerCase()!=='z') return;
      if(e.target.closest&&e.target.closest('textarea')) return;   // у поля ввода свой undo
      e.preventDefault();
      if(e.shiftKey) redoMD(); else undoMD();
    });

    /* двойной клик по тексту включает правку и открывает этот блок */
    document.addEventListener('dblclick',e=>{
      if(EDITING||SPLIT||e.target.closest('a,textarea,#pal,#fmenu')) return;
      const b=e.target.closest('.blk'),t=e.target.closest('#tail');
      if(!b&&!t) return;
      try{window.webkit.messageHandlers.editOn.postMessage(1)}catch(_){}
      window.setEditing(true);
      getSelection().removeAllRanges();
      if(t) startAppend(); else if(b.isConnected) startEdit(b);
    });
    window.setTint=function(l,d){const st=document.documentElement.style;st.setProperty('--bg-l',l);st.setProperty('--bg-d',d);};
    const toastEl=document.createElement('div');toastEl.id='toast';document.body.appendChild(toastEl);
    let toastT=null;
    function toast(msg){toastEl.textContent=msg;toastEl.classList.add('show');clearTimeout(toastT);toastT=setTimeout(()=>toastEl.classList.remove('show'),3200);}

    /* Чистая функция: применяет формат к строке src с выделением [a,b). Возвращает {t,a,b} или null. */
    function fmtText(src,a,b,k){
      const inl={b:'**',i:'*',s:'~~',code:'`'};
      if(inl[k]){
        const m=inl[k],L=m.length;
        if(a===b) return {t:src.slice(0,a)+m+m+src.slice(a),a:a+L,b:a+L};
        let wrapped=src.slice(a-L,a)===m&&src.slice(b,b+L)===m&&a-L>=0;
        if(wrapped&&m==='*'&&(src[a-2]==='*'||src[b+1]==='*')) wrapped=false;
        if(wrapped) return {t:src.slice(0,a-L)+src.slice(a,b)+src.slice(b+L),a:a-L,b:b-L};
        return {t:src.slice(0,a)+m+src.slice(a,b)+m+src.slice(b),a:a+L,b:b+L};
      }
      if(k.startsWith('mark:')){
        const o='<mark data-c="'+k.slice(5)+'">';
        return {t:src.slice(0,a)+o+src.slice(a,b)+'</mark>'+src.slice(b),a:a+o.length,b:b+o.length};
      }
      const ls=src.lastIndexOf('\n',a-1)+1;
      let le=src.indexOf('\n',b>a?b-1:b); if(le<0) le=src.length;
      const lines=src.slice(ls,le).split('\n');
      const strip=l=>l.replace(/^\s{0,3}(#{1,6}\s+|>\s?|[-*+]\s+|\d+[.)]\s+)/,'');
      let out;
      if(k[0]==='h'){const n=+k[1];out=lines.map(l=>(n?'#'.repeat(n)+' ':'')+strip(l));}
      else if(k==='quote'){const has=lines.every(l=>/^\s{0,3}>/.test(l));out=lines.map(l=>has?l.replace(/^\s{0,3}>\s?/,''):'> '+l);}
      else if(k==='ul'){const has=lines.every(l=>/^\s*[-*+]\s/.test(l));out=lines.map(l=>has?l.replace(/^(\s*)[-*+]\s/,'$1'):'- '+l);}
      else if(k==='unmark'){out=lines.map(l=>l.replace(/<\/?mark[^>]*>/g,''));}
      else return null;
      const nb=out.join('\n');
      return {t:src.slice(0,ls)+nb+src.slice(le),a:ls,b:ls+nb.length};
    }

    const fm=document.createElement('div');fm.id='fmenu';
    fm.innerHTML='<div class="row lbl">'+T.heading+'</div>'
     +'<div class="row"><button data-k="h0" title="'+T.plain+'">T</button><button data-k="h1">H1</button><button data-k="h2">H2</button><button data-k="h3">H3</button></div>'
     +'<div class="row"><button data-k="b" title="'+T.bold+'"><b>B</b></button><button data-k="i" title="'+T.italic+'"><i>I</i></button><button data-k="s" title="'+T.strike+'"><s>S</s></button><button data-k="code" title="'+T.code+'">&lt;/&gt;</button><button data-k="quote" title="'+T.quote+'">❝</button><button data-k="ul" title="'+T.list+'">•</button></div>'
     +'<div class="row lbl">'+T.highlight+'</div>'
     +'<div class="row">'+COLORS.map(c=>`<button class="dot" data-c="${c}" style="background:var(--hl-${c})"></button>`).join('')+'<button class="xb" data-k="x" title="'+T.removeHL+'">✕</button></div>';
    document.body.appendChild(fm);
    let fctx=null;
    function hideF(){fm.classList.remove('show');fctx=null;}
    function showF(e){
      hidePal();fm.classList.add('show');
      const w=fm.offsetWidth,h=fm.offsetHeight;
      let left=Math.max(8,Math.min(e.pageX-w/2,document.documentElement.clientWidth+scrollX-w-8));
      let top=e.pageY-h-14; if(top<scrollY+6) top=e.pageY+14;
      fm.style.left=left+'px';fm.style.top=top+'px';
    }
    fm.addEventListener('mousedown',e=>e.preventDefault());
    document.addEventListener('mousedown',e=>{if(!fm.contains(e.target))hideF();});
    document.addEventListener('keydown',e=>{if(e.key==='Escape')hideF();});
    window.addEventListener('scroll',()=>{if(fm.classList.contains('show'))hideF();},{passive:true});

    document.addEventListener('contextmenu',e=>{
      const ta=e.target.closest&&e.target.closest('textarea.ed');
      if(ta){
        if(ta.selectionStart===ta.selectionEnd) return;
        e.preventDefault();fctx={type:'ta',ta,a:ta.selectionStart,b:ta.selectionEnd};showF(e);return;
      }
      const s=getSelection(); if(!s.rangeCount||s.isCollapsed) return;
      const r=s.getRangeAt(0);
      const el=r.startContainer.nodeType===1?r.startContainer:r.startContainer.parentElement;
      const blk=el&&el.closest('.blk'); if(!blk||!blk.contains(r.endContainer)) return;
      e.preventDefault();
      const pre=document.createRange();pre.selectNodeContents(blk);pre.setEnd(r.startContainer,r.startOffset);
      fctx={type:'blk',s:+blk.dataset.s,e:+blk.dataset.e,text:r.toString().trim(),pre:pre.toString(),off:selOffsets()};
      showF(e);
    });

    fm.addEventListener('click',e=>{
      const btn=e.target.closest('button'); if(!btn||!fctx) return;
      const c=fctx;hideF();
      const k=btn.dataset.k,col=btn.dataset.c;
      if(c.type==='ta'){
        const key=col?'mark:'+col:(k==='x'?'unmark':k);
        const r=fmtText(c.ta.value,c.a,c.b,key);
        if(r){c.ta.value=r.t;c.ta.setSelectionRange(r.a,r.b);autosize(c.ta);}
        c.ta.focus();return;
      }
      if(col||k==='x'){   // цвет в красивом виде: хранится отдельно от файла
        const o=c.off; if(!o) return;
        HL=HL.filter(h=>h.end<=o.start||h.start>=o.end);
        if(col) HL.push({id:Date.now().toString(36)+Math.random().toString(36).slice(2,6),start:o.start,end:o.end,text:o.text,color:col});
        getSelection().removeAllRanges();applyAll();post();return;
      }
      const lines=curLines(),was=lines.slice(c.s,c.e);
      let tb=0;while(tb<was.length&&was[was.length-1-tb].trim()==='')tb++;
      const body=was.slice(0,was.length-tb).join('\n');
      let n=0,i=-1;while((i=c.pre.indexOf(c.text,i+1))>=0)n++;   // какое по счёту вхождение выделено
      let pos=-1;for(let j=0;j<=n;j++){pos=body.indexOf(c.text,pos+1);if(pos<0)break;}
      let a,b;
      if(pos<0){
        if(['b','i','s','code'].includes(k)){toast(T.notFound);return;}
        a=b=0;
      }else{a=pos;b=pos+c.text.length;}
      const r=fmtText(body,a,b,k); if(!r) return;
      lines.splice(c.s,c.e-c.s,...r.t.split('\n'),...Array(tb).fill(''));
      setMD(lines.join('\n'));
    });

    draw();
    """#
}
