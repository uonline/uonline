function getNodes() {
   var l, p, v, r, deeper, tmp;
   for (var i=0; arguments.length>i; i++) {
      if (typeof(arguments[i]) == 'object') { if (!l) l = arguments[i]; else r = arguments[i]; }
      else { if (!p) p = arguments[i]; else v = arguments[i]; }
   }
   l = l || new Array(document); r = r || new Array();

   deeper = false;
   tmp = new Array();

   for (var i0 in l) {
      if (l[i0][p] === v) r[r.length] = l[i0];
      if (l[i0].firstChild) {
         deeper = true;
         for (var i1 in l[i0].childNodes) { tmp[tmp.length] = l[i0].childNodes[i1]; }
      }
   }
   if (!deeper) { return r; }
   return getNodes(tmp, p, v, r);
}

document.addEventListener('DOMContentLoaded', 
    function (e) {
       var d = document.createElement('div');
       var s = document.createElement('span');
       var t = document.createTextNode(getNodes('nodeType', 8)[0].textContent.match(/\d+\.\d+/)[0]);
       d.setAttribute('style', 'position: fixed; left: 2px; top: 60px; transform: rotate(90deg); max-width: 20px;');
       s.appendChild(t);
       d.appendChild(s);
       document.body.appendChild(d);
    },
false);