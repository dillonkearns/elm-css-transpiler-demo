# TODOs

- [x] Copy project files and elm.json over to a secret folder
- [x] Run elm-review in auto-fix mode on the secret folder -> `StubCssGenerator.styles : String` is populated in secret folder
- [x] Create a `Platform.worker` sends `StubCssGenerator.styles` through a port, and write that to an Elm file that includes a Platform.worker setup (`GenerateCss.elm`)
- [ ] Run `GenerateCss.elm` to output `styles.css`
- [ ] Copy `styles.css` and `elm.js` to `dist/`

- [ ] How do we turn `Css.Style -> String`?
- [ ] Remove hardcoding of the list of styles
  - [ ] Gather `ModuleContext` that includes all static styles, and the imports they use
