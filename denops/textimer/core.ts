const doneText = "#DONE";

//
// function! textimer#parse(line, ...) abort
//
//   let index = match(line, '\s\+[0-9]\+$')
//
//   let title = trim(line[0:index])
//   let minutes = str2nr(trim(line[index:]))
//
//
//   let d = copy(get(a:, 1, {}))
//   call extend(d, {'title': title, 'minutes': minutes, 'id': id})
//   return d
// endfunction

function parse(line: string): string {
  const s = line.trim();
  if (s.indexOf(doneText) === 0) {
    // return textimer#parse(strpart(line, len(s:done_text)), {'done': v:true})
    return "";
  }

  if (s.indexOf("#") === 0) {
    return "";
    //return {'comment': v:true}
  }

  const [x, title, minutesStr] = s.match("(.+?) +([0-9]+)$") ?? [];
  if (title === undefined) {
    //   if index == -1 | return {} | endif
    return "";
  }
  const minutes = parseInt(minutesStr);

  const [y, body, id] = title.match("(.+?)(#tt[0-9]+)") ?? ["", title];

  return "";
}

const line = " fo  bar  10";
const [x, a, b] = line.match("(.+?) +([0-9]+)$") ?? [];
console.log(`a = ${a}, b = ${b}`);

const [y, c, d] = a.match("(.+?)(#tt[0-9]+)") ?? ["", a];
console.log(`c: [${c}], d: [${d}]`);

//   let index = match(title, '\s\+#tt[0-9]\+$')
//   let id = ''
//   if index != -1
//     let id = trim(title[index:])
//     let title = trim(title[0:index])
//   endif
